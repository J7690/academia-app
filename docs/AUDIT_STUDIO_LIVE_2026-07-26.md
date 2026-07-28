# Audit du Studio Live Academia — état réel vs documentation

**Date** : 26 juillet 2026
**Périmètre** : dispositif de diffusion en direct (type Zoom / TikTok Live / Facebook Live) — documentation `docs/` + `.devin/`, code Flutter `academia_app/lib`, backend Supabase `thevdfcwlcqzdoybfvgs` (schéma `app`, RPC `public`, Edge Functions).
**Méthode** : lecture des sources documentaires, inspection du code, et interrogation directe de la base de production via MCP administrateur (tables, fonctions, migrations appliquées, code réellement déployé des Edge Functions). Aucun constat ci-dessous n'est déduit de la documentation seule.

---

## 1. Verdict en une page

Le studio de live existe **sur trois plans qui ne sont pas alignés** :

| Plan | État |
|---|---|
| **Documentation** | Très riche, cohérente, mais décrit une cible partiellement non réalisée et référence un document fantôme. |
| **Code Flutter** | Le plus avancé des trois. Un studio complet (chat, quiz, tableau blanc, partage d'écran, réactions, présence, replay, live TikTok) est écrit et branché dans l'UI. |
| **Backend Supabase** | En retard. Le socle unifié existe mais **9 RPC appelées par le code n'existent pas en base**, et l'Edge Function `livekit-token` déployée en production est une **version antérieure de 3 mois** qui ignore le moteur unifié. |
| **Infrastructure** | LiveKit n'est installé **nulle part** sur le serveur actuel (LWS). La migration Kamatera → LWS s'est arrêtée à la Phase 1. La bascule LiveKit Cloud est documentée mais jamais exécutée. |

**Conséquence directe** : en l'état, une session live créée via le moteur unifié `academia_sessions` **échoue en 404 avant même d'atteindre LiveKit**. La table compte 0 ligne — le dispositif n'a jamais servi en production. Les sessions legacy (prépa-concours, cours en ligne) obtiendraient un token, mais leurs panneaux chat / quiz / replay tomberaient en erreur, et rien ne garantit qu'un serveur LiveKit réponde à l'autre bout.

Le travail accompli est réel et substantiel. Ce qui manque n'est pas de la conception : c'est **du déploiement et du raccordement**. Trois chantiers courts et bien cernés séparent le studio d'un premier live réel.

---

## 2. Ce que la documentation prévoit

### 2.1 Corpus identifié

| Document | Contenu |
|---|---|
| `docs/ACADEMIA_ARCHITECTURE_DECISIONS.md` → **ADR-011** | Décision de référence : unification Live/Cours/TD/Concours, LiveKit comme SFU, migration vers LiveKit Cloud (Option A), construction du « Learning Engine » `app.academia_sessions`. Option B (Zoom SDK / Daily.co) écartée. |
| `docs/LIVEKIT_CLOUD_MIGRATION_RUNBOOK.md` | Runbook de bascule self-hosted → LiveKit Cloud. Argumente à juste titre que c'est une opération **sans changement de code** (3 secrets Supabase + redéploiement de 3 fonctions). |
| `.devin/INSTRUCTIONS_DEVIN_LIVE_CLASSROOM_SUPABASE.md` | Document le plus honnête du corpus : liste ce qui est fait, ce qui reste, et assume explicitement les dettes de sécurité différées. |
| `academia_app/docs/audit_live_streaming_plan.md` (20 mars 2026) | Benchmark Zoom / Meet / Teams / Twitch + plan L1→L10 (chat, partage d'écran, mode présentateur, réactions, enregistrement, live TikTok, live duo, quiz, qualité adaptative). |
| `docs/MIGRATION_COMPLETE_KAMATERA_VERS_LWS.md` | Plan en 4 phases ; LiveKit + Redis + Nginx + Egress = Phase 3. |
| `docs/LWS_INSTALLATION_AUDIT_REPORT_2026-07-25.md` | Audit terrain du serveur LWS, la veille de cet audit. |

### 2.2 Anomalie documentaire

`docs/ACADEMIA_LIVE_CLASSROOM_PROPOSAL.md` est cité comme document fondateur par le runbook LiveKit, les instructions Devin et `ACADEMIA_CURRENT_CHECKPOINT.md`. **Ce fichier n'existe pas dans le dépôt.** La proposition d'architecture d'origine du dispositif live est donc perdue ou n'a jamais été écrite, alors que trois documents s'y adossent.

---

## 3. Ce qui existe réellement

### 3.1 Code Flutter — le point fort

Le studio unifié `AcademiaClassroomScreen` (804 lignes) est nettement plus avancé que ce que le plan de mars décrivait comme « à faire ». Modules présents dans `lib/features/live/` :

| Fonctionnalité | Fichier | Transport |
|---|---|---|
| Room LiveKit + grille vidéo | `academia_classroom_screen.dart` | WebRTC |
| Partage d'écran | `widgets/academia_screen_share_view.dart` | `setScreenShareEnabled` |
| Chat temps réel | `widgets/academia_chat_panel.dart` | Data Channel LiveKit |
| Chat persistant | `widgets/academia_persistent_chat_panel.dart` | RPC Supabase + Realtime |
| Quiz en direct (hôte + étudiant) | `widgets/academia_quiz_overlay.dart`, `academia_quiz_student_overlay.dart` | Data Channel + RPC |
| Réactions animées | `widgets/academia_reactions_overlay.dart` | Data Channel |
| Main levée | intégré à l'écran | Data Channel |
| Panneau participants + mute distant + export CSV présence | `widgets/academia_participants_panel.dart` | Edge Function `livekit-admin` |
| Tableau blanc collaboratif | `whiteboard/` (4 fichiers) | Data Channel |
| Exercice TD poussé en direct | `widgets/academia_td_exercise_overlay.dart` | Data Channel |
| Assistant IA en séance | `widgets/academia_ai_panel.dart` | Edge Function `academia-ai-assistant` |
| Live TikTok 1→N | `student/challenge_live_screen.dart` (559 l.) | LiveKit + Data Channel |
| Live Duo 2→N | `student/challenge_live_duo_screen.dart` (434 l.) | LiveKit + Data Channel |
| Replay | `academia_replay_screen.dart` | RPC Supabase |

Le studio est correctement branché : `AcademiaClassroomScreen` est appelé depuis **9 points d'entrée** (admin, dashboard instructeur, sessions prépa enseignant ×2, détail cours ×2, onglet lives étudiant, onglet lives prépa, accès TD). Ce n'est pas du code orphelin.

Les feature flags par session (`is_chat_enabled`, `is_quiz_enabled`, `is_whiteboard_enabled`, `is_screen_share_enabled`, `is_recording_enabled`, `is_hand_raise_enabled`) sont lus depuis la base et respectés par l'UI — la granularité prévue par l'ADR-011 est bien implémentée.

### 3.2 Backend Supabase — ce qui est en place

- **Tables** : `app.academia_sessions` (32 colonnes, complète), `app.academia_session_participants`, plus les 3 tables legacy `prep_live_sessions`, `online_course_live_sessions`, `challenge_game_live_sessions`.
- **RPC** : les 16 `app_learning_*` du moteur unifié + `livekit_lookup_academia_session` + `livekit_get_user_display_name`, toutes en `SECURITY DEFINER`. 4 migrations appliquées le 14 juillet 2026, correctifs de sécurité `IS DISTINCT FROM` inclus.
- **Edge Functions** : `livekit-token`, `livekit-recording`, `livekit-admin` — les trois **ACTIVE**.
- **RLS** : activé sur `academia_sessions` et `academia_session_participants` sans policy directe. C'est **volontaire et correct** (tout passe par les RPC `SECURITY DEFINER`), conforme au patron du reste du projet.

---

## 4. Écarts critiques constatés

### 4.1 🔴 L'Edge Function `livekit-token` déployée est obsolète de 3 mois

C'est le blocage le plus grave et le plus simple à corriger.

| | Dépôt (`supabase/functions/livekit-token/index.ts`) | **Production (v45, mise à jour le 21 avril 2026)** |
|---|---|---|
| Paramètre `session_source` | lu | **ignoré** |
| Appel `livekit_lookup_academia_session` | oui | **absent** |
| Statut `draft` accepté | oui | non |
| Champ `session_type` en réponse | oui | **absent** |
| Enregistrement participant unifié | géré | absent |

La migration `create_academia_sessions_learning_engine` date du **14 juillet**, soit près de trois mois **après** le dernier déploiement de `livekit-token`. La fonction en production n'interroge que `livekit_lookup_session`, qui ne couvre que les 3 tables legacy.

**Effet en production** : toute session portée par `app.academia_sessions` reçoit `404 — Session introuvable`. Le studio unifié est inatteignable, quel que soit l'état de LiveKit. Cela explique mécaniquement les **0 lignes** dans `academia_sessions`.

**Correction** : `supabase functions deploy livekit-token`. Une commande.

### 4.2 🔴 Neuf RPC appelées par le code Flutter n'existent pas en base

Vérifié fonction par fonction contre `pg_proc` :

| RPC appelée par | RPC | En base |
|---|---|---|
| `academia_chat_service.dart` | `app_learning_send_message` | ❌ |
| | `app_learning_list_messages` | ❌ |
| | `app_learning_delete_message` | ❌ |
| `academia_quiz_service.dart` | `app_learning_quiz_create_question` | ❌ |
| | `app_learning_quiz_submit_answer` | ❌ |
| | `app_learning_quiz_results` | ❌ |
| | `app_learning_quiz_list_questions` | ❌ |
| `academia_replay_service.dart` | `app_learning_get_replay` | ❌ |
| | `app_learning_replay_timeline` | ❌ |

Aucune table de support non plus : ni `academia_session_messages`, ni table de questions/réponses de quiz de séance.

Le SQL du chat existe pourtant dans le dépôt — `.devin/sql_changes/change_20260608_academia_chat_rpcs.sql` définit les 3 fonctions de messagerie — mais **n'a jamais été appliqué** : aucune migration correspondante dans `supabase_migrations.schema_migrations`. Il a été écrit le 8 juin, cinq semaines avant la migration du Learning Engine, et oublié en route.

**Effet** : chat persistant, quiz en direct et replay lèvent une erreur PostgREST à la première utilisation, y compris sur les sessions legacy qui, elles, obtiennent bien un token. Le chat via Data Channel LiveKit continue de fonctionner (il ne passe pas par la base) — mais sans persistance ni historique.

### 4.3 🔴 Aucun serveur LiveKit sur l'infrastructure actuelle

L'audit terrain LWS du 25 juillet est sans ambiguïté : « Seule la Phase 1 de la migration Kamatera vers LWS est opérationnelle. Les phases 2, 3 et 4 ne sont pas encore installées. » LiveKit server, Redis et LiveKit Egress sont listés **absents**, le répertoire `/opt/livekit` vide.

Trois adresses de serveur LiveKit circulent dans la documentation sans qu'aucune ne soit confirmée active : `185.220.204.214` (audit de mars), `185.167.97.144` (runbook de juillet), et l'IP LWS `31.207.38.60` (où LiveKit n'est pas installé). La bascule LiveKit Cloud, documentée depuis le 13 juillet, attend toujours la création du compte tiers — action qui revient au porteur de projet.

**Effet** : même token valide en main, le client Flutter n'a pas de SFU auquel se connecter. L'enregistrement (Egress) est doublement bloqué : service absent **et** non supporté pour les sessions unifiées (la fonction `livekit-recording` n'écrit que dans `replay_url` / `replay_video_url` des tables legacy).

### 4.4 🟡 Code mort accumulé (~2 100 lignes)

| Fichier | Lignes | Statut |
|---|---|---|
| `features/live/livekit_room_screen.dart` | 1 329 | Remplacé par `AcademiaClassroomScreen`, plus aucun appelant |
| `widgets/live_quiz_overlay.dart` | 478 | Utilisé uniquement par l'écran mort ci-dessus |
| `features/live/academia_replay_screen.dart` | 293 | Jamais instancié depuis nulle part |
| `features/live/widgets/academia_ai_panel.dart` | — | Jamais monté dans l'arbre de widgets |

L'écran de replay est particulièrement dommageable : la fonctionnalité est écrite, mais aucun bouton ne permet d'y accéder — et les 2 RPC dont elle dépend n'existent pas.

### 4.5 🟡 Aucun usage réel du dispositif

| Table | Lignes | Détail |
|---|---|---|
| `app.academia_sessions` | **0** | Moteur unifié jamais utilisé |
| `app.academia_session_participants` | **0** | — |
| `app.prep_live_sessions` | 1 | « prise en main », statut `running` depuis le 6 juin — session zombie jamais clôturée |
| `app.online_course_live_sessions` | 1 | « exo », programmée le 29 nov. 2025, statut `approved` |
| `app.challenge_game_live_sessions` | 12 | 11 `cancelled`, 1 `live` bloquée depuis le 16 juillet |

Le live TikTok (`challenge_game_live_sessions`) est le seul à montrer une activité réelle — 12 tentatives — mais 11 annulations sur 12 et une session restée « live » depuis dix jours signalent que ces sessions n'aboutissent pas, ce qui est cohérent avec l'absence de serveur LiveKit.

### 4.6 🟡 Dettes de sécurité assumées mais non résorbées

Constats de juillet toujours ouverts, différés par décision explicite du porteur de projet (ADR-011) :

- **32 tables sans RLS**, dont `admin_users`, `payment_audit_log`, `commission_rules`, `notification_events` (1 783 lignes en production).
- Toutes les RPC `SECURITY DEFINER` exécutables par `anon` (comportement PostgREST par défaut ; chaque fonction contrôle `auth.uid()` en interne, mais la surface reste large).
- `app.user_roles` n'existe pas : le contrôle « admin » dans `livekit-admin`, `livekit-recording` et `app_learning_presence_list` **dégrade silencieusement vers non-admin**. Un administrateur ne peut donc pas modérer une session dont il n'est pas l'hôte — alors que l'écran admin `admin_live_sessions_screen.dart` propose ces actions.
- Rotation des clés LiveKit / Supabase service role : non faite.

---

## 5. Comparaison à la cible fonctionnelle

Statut réel par rapport au plan L1→L10 de mars 2026 :

| Fonctionnalité | Zoom | TikTok Live | Code Academia | Backend | **Utilisable** |
|---|---|---|---|---|---|
| Vidéo/audio WebRTC | ✅ | ✅ | ✅ | ✅ | ⛔ pas de SFU |
| Chat éphémère (Data Channel) | ✅ | ✅ | ✅ | n/a | ⛔ pas de SFU |
| Chat persistant + historique | ✅ | ✅ | ✅ | ❌ RPC absentes | ⛔ |
| Partage d'écran | ✅ | ❌ | ✅ | n/a | ⛔ pas de SFU |
| Main levée | ✅ | ❌ | ✅ | n/a | ⛔ pas de SFU |
| Réactions emoji | ✅ | ✅ | ✅ | n/a | ⛔ pas de SFU |
| Registre de présence | ✅ | ❌ | ✅ | ✅ | 🟡 token 404 |
| Mute / exclusion à distance | ✅ | ✅ | ✅ | ✅ (sauf rôle admin) | 🟡 |
| Quiz en direct | ✅ | ❌ | ✅ | ❌ RPC absentes | ⛔ |
| Tableau blanc partagé | ✅ | ❌ | ✅ | n/a | ⛔ pas de SFU |
| Enregistrement | ✅ | ✅ | ✅ | 🟡 legacy seulement | ⛔ Egress absent |
| Replay | ✅ | ✅ | ✅ non branché | ❌ RPC absentes | ⛔ |
| Live 1→N façon TikTok | ❌ | ✅ | ✅ | ✅ | ⛔ pas de SFU |
| Live Duo 2→N | ❌ | ✅ | ✅ | ✅ | ⛔ pas de SFU |
| Assistant IA en séance | ❌ | ❌ | ✅ non branché | ✅ | ⛔ |
| Breakout rooms | ✅ | ❌ | ❌ | ❌ | ⛔ |
| Sous-titres automatiques | ✅ | ✅ | ❌ | ❌ | ⛔ |
| Qualité adaptative (simulcast) | ✅ | ✅ | ❌ | n/a | ⛔ |

La colonne « Code Academia » est remarquablement remplie — y compris sur deux fonctionnalités (tableau blanc collaboratif en séance, assistant IA pédagogique) qu'aucune des plateformes de référence n'offre. Rien n'est utilisable faute des trois blocages d'infrastructure et de déploiement.

---

## 6. Recommandations, par ordre de déblocage

### Palier 1 — Rendre le dispositif atteignable (≈ 1 journée)

1. **Redéployer `livekit-token`** depuis le dépôt : `supabase functions deploy livekit-token`. Débloque tout le moteur unifié. *Coût : une commande. Gain : sans cela, rien d'autre ne peut être testé.*
2. **Trancher l'hébergement LiveKit**. Deux voies, et il faut choisir :
   - *LiveKit Cloud* (recommandé par l'ADR-011) : création de compte, 3 secrets, redéploiement de 3 fonctions. Élimine la contention CPU/RAM sur le VPS partagé avec le worker Smart Whiteboard et Bobodo vocal. Coût récurrent à l'usage.
   - *Self-hosted sur LWS* (Phase 3 de la migration) : installation LiveKit + Redis + Nginx sur `31.207.38.60`. Pas de coût récurrent, mais 4 vCPU / 8 Go déjà occupés par le pipeline Remotion — le risque de contention que l'ADR-011 voulait précisément éviter réapparaît.
3. **Faire un premier live réel de bout en bout** et le documenter. Aucun live n'a jamais abouti : tant que ce test n'est pas passé, tout le reste est théorique.

### Palier 2 — Réparer le contrat code ↔ base (≈ 2 à 3 jours)

4. **Appliquer les 3 RPC de chat** : `.devin/sql_changes/change_20260608_academia_chat_rpcs.sql` est prêt, il suffit de le passer en migration versionnée (avec la table de messages associée, à vérifier dans le fichier).
5. **Écrire les 4 RPC de quiz** + la table de questions/réponses de séance. Le contrat JSON attendu est lisible dans `academia_quiz_service.dart`.
6. **Écrire les 2 RPC de replay** et brancher `AcademiaReplayScreen` derrière un bouton « Voir le replay » sur les sessions terminées.
7. **Étendre `livekit-recording`** aux sessions `academia` (écriture dans `academia_sessions.replay_url` / `replay_video_asset_id`), aujourd'hui limitée aux tables legacy.
8. **Mettre en place un test de non-régression** listant les RPC appelées par le code Dart et vérifiant leur existence en base. Le décalage constaté ici — 9 RPC fantômes, un SQL oublié pendant 7 semaines — se reproduira sans garde-fou automatique.

### Palier 3 — Hygiène et sécurité (≈ 2 jours)

9. **Supprimer le code mort** : `livekit_room_screen.dart`, `live_quiz_overlay.dart` (~1 800 lignes). Il entretient l'illusion de deux implémentations concurrentes.
10. **Créer `app.user_roles`** ou retirer les actions admin de l'UI qui dégradent silencieusement. Un bouton qui échoue en silence est pire qu'un bouton absent.
11. **Nettoyer les sessions zombies** : la session prépa `running` depuis le 6 juin et la session challenge `live` depuis le 16 juillet.
12. **Écrire `docs/ACADEMIA_LIVE_CLASSROOM_PROPOSAL.md`** ou corriger les 3 documents qui le référencent. Une référence morte dans la documentation fondatrice fragilise tout le corpus.
13. **Ouvrir la phase de sécurisation** différée : RLS sur les 32 tables (priorité `admin_users`, `payment_audit_log`, `commission_rules`), `REVOKE EXECUTE FROM anon` sur les RPC non publiques, rotation des clés.

### Palier 4 — Compléter la cible

14. Qualité adaptative (simulcast 3 couches) — indispensable sur les réseaux mobiles ouest-africains, aujourd'hui absente du code.
15. Basculement automatique en audio seul sur connexion faible.
16. Breakout rooms et sous-titres automatiques, si le besoin pédagogique est confirmé.

---

## 7. Lecture d'ensemble

Le diagnostic n'est pas celui d'un chantier bâclé, mais d'un **chantier désynchronisé**. Le code Flutter a couru en tête et implémente une vision ambitieuse et cohérente. Le backend a suivi partiellement, en une passe le 14 juillet. Le déploiement des Edge Functions s'est arrêté en avril. L'infrastructure, elle, n'a jamais démarré la phase qui la concerne.

Chaque maillon isolé est correct. C'est leur chaînage qui n'a jamais été vérifié de bout en bout — précisément parce qu'aucun live réel n'a jamais eu lieu. Le premier live de test est donc moins une étape de validation qu'un **révélateur** : il fera tomber en cascade les erreurs que cet audit a dû reconstituer pièce par pièce.

Le point 1 du palier 1 — une seule commande de redéploiement — est le meilleur rapport effort/déblocage de tout ce rapport.

---

*Audit réalisé le 26 juillet 2026 par inspection directe du dépôt et de la base de production `thevdfcwlcqzdoybfvgs`.*

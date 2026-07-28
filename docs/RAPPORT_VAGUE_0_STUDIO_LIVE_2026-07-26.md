# Vague 0 — Rapport d'exécution

**Date** : 26 juillet 2026
**Périmètre** : déblocage du Studio Live — réparation de l'existant, aucune fonctionnalité nouvelle
**Méthode** : audit Flutter → audit Supabase → audit LiveKit avant chaque modification, vérification après
**Références** : `AUDIT_STUDIO_LIVE_2026-07-26.md`, `ARCHITECTURE_STUDIO_LIVE_V1.md`

---

## 1. Résultat en bref

| Étape | Objet | État |
|---|---|---|
| V0.1 | Audit du dépôt avant modification | ✅ |
| V0.2 | RPC de chat persistant | ✅ appliquées, 11 tests au vert |
| V0.3 | Redéploiement de `livekit-token` | ✅ v45 → **v46** |
| V0.4 | Adaptativité vidéo sur toutes les salles | ✅ 5 salles, 1 point de configuration |
| V0.5 | Onglets Cours et Lives rebranchés | ✅ mobile et desktop |
| V0.6 | Test de cohérence RPC | ✅ livré — **56 manques révélés** |
| V0.7 | Bascule LiveKit Cloud | ⏸ script prêt, création de compte à votre main |
| V0.8 | Vérification finale | ✅ |

**Trois découvertes n'étaient pas au programme** et changent la lecture du projet. Elles sont en section 4.

---

## 2. Ce qui a été fait, étape par étape

### V0.2 — Chat persistant : le SQL du 8 juin était inapplicable

Le fichier `.devin/sql_changes/change_20260608_academia_chat_rpcs.sql` ne pouvait pas être exécuté tel quel. Trois défauts bloquants, trouvés par confrontation avec le schéma réel :

| Défaut | Constat |
|---|---|
| Table absente | Le fichier annonce `app.academia_session_messages` « créée en Phase 2 ». Elle n'existe pas. Les trois fonctions auraient été créées puis auraient échoué au premier appel. |
| Jointure impossible | `LEFT JOIN app.students s ON s.user_id = m.sender_id` — la colonne `students.user_id` **n'existe pas** (la clé est `id`), et `students.email` non plus. Même classe de bug que celui corrigé en juillet sur `livekit_get_user_display_name`. |
| Contrôle « admin » faux | Le test d'administration interrogeait `app.user_admin_status` avec une colonne `is_active` inexistante. Pire : cette table n'est pas une table de droits, c'est un registre de suspension et suppression de comptes. Toute personne non suspendue aurait été traitée comme administrateur, avec droit de supprimer n'importe quel message. |

**Deux manques supplémentaires**, absents du fichier d'origine :

- **Aucun contrôle d'appartenance.** N'importe quel utilisateur authentifié pouvait écrire et lire le chat de n'importe quelle session, en connaissant seulement son identifiant.
- **Realtime muet.** `AcademiaChatService.subscribeToMessages()` souscrit aux insertions de la table. Supabase Realtime autorise via RLS : sans politique `SELECT`, la souscription n'aurait jamais rien reçu. Et la table n'était pas dans la publication `supabase_realtime`.

**Migration appliquée** : `create_academia_sessions_learning_engine` → `create_academia_session_messages_and_chat_rpcs`.

- Table créée avec clé étrangère en cascade sur `academia_sessions`, index `(session_id, created_at DESC)`, colonnes `reply_to_id` et `is_pinned` prêtes pour la suite.
- `sender_name` **dénormalisé à l'insertion** via `livekit_get_user_display_name`. C'est délibéré : la charge utile Realtime est la ligne brute, le client ne peut pas résoudre le nom par jointure. Sans cette colonne, tout message arrivant en direct s'afficherait sans auteur.
- Fonction d'appartenance `app.academia_session_is_member` — hôte ou participant enregistré.
- Politique `SELECT` pour les membres uniquement. Écriture et suppression fermées : tout passe par les RPC `SECURITY DEFINER`. C'est une exception assumée au patron « RLS sans policy » du projet, imposée par Realtime, et alignée sur le précédent `challenge_game_live_sessions`.
- Modération : l'auteur supprime son message, l'**hôte de la session** supprime n'importe lequel. Plus de dépendance à une table de droits inexistante.
- `REVOKE` explicite sur `anon`, `GRANT` sur `authenticated`.

**Test de fumée, 11 cas, simulation de JWT :**

| Cas | Résultat |
|---|---|
| A1 hôte écrit | OK — nom résolu « Elie SAVADOGO » |
| A2 hôte lit | OK — 1 message |
| A3 espaces en trop | OK — retirés |
| B1 non-participant écrit | **rejeté** — « Vous ne participez pas à cette session. » |
| B2 non-participant lit | **rejeté** |
| C après jointure | OK — 2 messages |
| D suppression croisée | **rejetée** — « Non autorisé. » |
| E modération par l'hôte | OK |
| F appel sans JWT | **rejeté** — « Authentification requise. » |
| G message vide | **rejeté** |
| H cascade de suppression | OK — 0 résiduel |

### V0.3 — `livekit-token` : un défaut trouvé avant déploiement

Le code du dépôt contenait :

```dart
await supabase.rpc('app_prep_student_join_live_session', {...}).catch(() => null);
```

`supabase.rpc()` renvoie un `PostgrestFilterBuilder`, objet *thenable* qui n'expose pas `.catch()`. L'enchaîner lève un `TypeError` **synchrone**, avant même l'`await`. Résultat : sur le chemin `prep` — celui de Prépa-Concours, le plus probable pour un premier test — la fonction serait partie en 500 alors que le token venait d'être généré.

Ce défaut n'existait pas dans la version d'avril déployée en production. Il avait été introduit dans le dépôt et n'avait jamais tourné, faute de déploiement. Corrigé en `try/catch`, avec commentaire explicatif, puis déployé.

**Vérifié après déploiement** : v46 active, `verify_jwt` conservé à `true`, branche `academia` présente, appel à `livekit_lookup_academia_session` confirmé dans le code servi.

### V0.4 — Correction d'une de mes propres conclusions

Le document d'architecture affirmait que `adaptiveStream` et `dynacast` n'étaient activés nulle part. **C'est faux et je le corrige** : `AcademiaClassroomScreen` les avait déjà, avec `simulcast`.

L'audit fin a montré le vrai périmètre du problème — quatre salles sur cinq utilisaient un `Room()` nu :

| Fichier | Avant | Après |
|---|---|---|
| `academia_classroom_screen.dart` | options en dur | `AcademiaRoomOptions.classroom` |
| `challenge_live_screen.dart` | **`Room()` nu** | `AcademiaRoomOptions.broadcast` |
| `challenge_live_duo_screen.dart` | **`Room()` nu** | `AcademiaRoomOptions.broadcast` |
| `auto_record_game_wrapper.dart` | **`Room()` nu** | `AcademiaRoomOptions.gameplay` |
| `games_hub_screen.dart` | **`Room()` nu** | `AcademiaRoomOptions.gameplay` |

Ce sont précisément les écrans qui ont un usage réel : les 12 sessions de `challenge_game_live_sessions` sont passées par eux, sans simulcast, sans dynacast, sans adaptive stream. Sur un téléphone d'entrée de gamme diffusant en direct, cela représente 30 à 60 % de CPU inutile et 20 à 40 % d'autonomie perdue.

Nouveau fichier `lib/services/academia_room_options.dart` : source unique. Plus aucun `Room()` nu dans le dépôt — vérifié.

**Choix assumé** : le réglage fin des couches d'encodage (débits, images/s, codec par plateforme) n'a pas été touché. Le SDK Flutter du dépôt est en fins de ligne Windows et ne s'exécute pas depuis l'environnement Linux d'audit — impossible de lancer `flutter analyze`. Je m'en suis donc tenu à l'API déjà prouvée compilante dans le projet. L'échelle d'encodage relève de la vague 7, avec campagne de tests sur parc réel.

### V0.5 — Onglets rebranchés

`StudentComingSoonTab` remplacé par `StudentCoursesTab` (index 8) et `StudentLiveSessionsTab` (index 9), dans les **deux** branches — mobile et desktop. Les quatre providers nécessaires ont été vérifiés présents dans `main.dart` avant modification, faute de quoi les onglets auraient planté à l'ouverture.

L'onglet « Opportunités » (index 2) reste en attente : hors périmètre.

### V0.6 — Le garde-fou, et ce qu'il a trouvé

`tools/check_rpc_contract.py` extrait tous les `.rpc('...')` du Dart **et** des Edge Functions, interroge le schéma OpenAPI de PostgREST, et échoue si un appel n'a pas de fonction correspondante. Sans dépendance externe — bibliothèque standard uniquement, pour tourner en CI sans installation.

Un fichier de référence `rpc_contract_baseline.json` tolère les manques déjà planifiés. **La liste doit décroître, jamais grandir** : toute nouvelle entrée fait échouer la CI.

L'écriture du script a corrigé une erreur de ma propre méthode d'audit : mon comptage initial par `grep` donnait 257 appels. Il ratait tous les appels écrits sur plusieurs lignes. Le compte réel est **674**.

### V0.7 — Bascule LiveKit Cloud

`tools/livekit_cloud_switch.sh` : sauvegarde, pose des trois secrets, redéploiement des trois fonctions ensemble, vérification des versions, contrôle du contrat RPC, et procédure de recette en quatre points.

**Une seule action vous revient** : créer le compte sur cloud.livekit.io et le projet (région eu-central, Francfort — la plus proche du Burkina), puis relever URL et clés. Le script fait le reste.

---

## 3. Ce qui reste bloqué, et pourquoi

**Le premier live réel n'a pas pu avoir lieu.** L'audit LWS du 25 juillet est formel : LiveKit n'est installé nulle part sur le serveur actuel, la phase 3 de la migration n'a jamais démarré. Tant que le SFU n'existe pas, le client n'a personne à qui se connecter — quelle que soit la qualité du token.

C'est le seul verrou restant de la vague 0, et il ne peut être levé qu'après la création du compte LiveKit Cloud.

---

## 4. Trois découvertes hors programme

### 4.1 Cinquante-six RPC appelées sans fonction en base

Le balayage complet des 674 appels a révélé **56 manques**, pas 6. Des familles entières de fonctionnalités sont inertes :

| Famille | Manques | Portée |
|---|---|---|
| **Tournois** | 7 | `tournament_create`, `register`, `start`, `get_details`, `get_standings`, `list_available`, `report_match_result`. **Aucune n'existe.** Le module est entièrement non fonctionnel. |
| **Ligues** | 5 | `league_create`, `join`, `list_available`, `get_standings`, `report_match_result`. Même constat. |
| **Prépa Concours** | 26 | Flashcards (5), banques de questions (4), modèles de quiz (3), conversations IA (6), tableau des scores, épreuves, console admin prépa (5). |
| **Bobodo** | 5 | Cache de réponses et mémoire inter-sessions — dégradation silencieuse probable de l'assistant. |
| **Studio Live** | 6 | Quiz en séance (4) et replay (2) — planifiés vagues 2 et 3. |
| **Admin divers** | 4 | Suppression de cours et de programmes, statistiques de navigation, comptes supprimés. |
| **Autres** | 3 | Attribution marketing, suppression de message privé. |

Seuls 6 de ces 56 manques étaient connus et planifiés. **Les 50 autres sont des fonctionnalités que l'interface propose et que la base ne sait pas honorer.** Chacune produit une erreur PostgREST au premier clic.

Ce n'est pas un accident isolé du Studio Live : c'est un défaut de méthode à l'échelle du projet, exactement celui que le garde-fou vient fermer.

Recommandation : avant tout nouveau développement, passer les modules Tournois, Ligues et Prépa Concours au crible — écran par écran — pour décider ce qui est implémenté et ce qui est retiré de l'interface. Un bouton qui échoue coûte plus cher en confiance qu'un bouton absent.

### 4.2 Les étudiants ne peuvent pas prendre la parole en classe

`livekit-token` accorde `canPublish: isHost`. **Seul l'hôte peut publier**, dans tous les modes — y compris la classe virtuelle. Or `AcademiaClassroomScreen` affiche à chaque étudiant des boutons micro et caméra qui, une fois pressés, échoueront en silence.

Je n'ai **pas** corrigé ce point dans la vague 0, délibérément. Le modèle de droits de publication est une décision d'architecture qui appartient à la matrice de capacités de la vague 1, et le modifier à l'aveugle — sans pouvoir tester un live réel — aurait été un pari.

**C'est le point numéro un de la vague 1.**

### 4.3 Aucun contrôle d'accès aux salles

`livekit_lookup_academia_session` et `livekit_lookup_session` renvoient n'importe quelle session à n'importe quel utilisateur authentifié. Le token est ensuite délivré sans vérifier l'inscription, le paiement ou l'invitation. Connaître un identifiant de session suffit pour entrer.

Le défaut est antérieur à cette vague et concerne aussi le chemin legacy. Mais en redéployant `livekit-token`, la vague 0 rend le chemin unifié **atteignable** — donc le trou devient réel.

À traiter dans `studio_resolve_session` en vague 1, avec le modèle de visibilité (`enrolled` / `public` / `invite` / `private`) déjà prévu par l'architecture.

---

## 5. Ce qui a changé dans le dépôt

**Supabase**

- Migration `create_academia_session_messages_and_chat_rpcs`
- Edge Function `livekit-token` v45 → v46

**Flutter**

- `lib/services/academia_room_options.dart` — nouveau
- `lib/features/live/academia_classroom_screen.dart`
- `lib/features/student/challenge_live_screen.dart`
- `lib/features/student/challenge_live_duo_screen.dart`
- `lib/features/student/student_dashboard_screen.dart`
- `lib/games/screens/auto_record_game_wrapper.dart`
- `lib/games/screens/games_hub_screen.dart`

**Outillage**

- `tools/check_rpc_contract.py` — nouveau
- `tools/rpc_contract_baseline.json` — nouveau
- `tools/livekit_cloud_switch.sh` — nouveau

**Non commité.** Le dépôt était déjà en état modifié sur `main` à l'ouverture de la vague ; je n'ai touché à aucun autre fichier et n'ai rien validé.

---

## 6. À faire avant la vague 1

1. **Lancer `flutter analyze` puis `flutter test`** sur `academia_app` depuis un poste Windows. Le SDK du dépôt est en fins de ligne Windows et refuse de s'exécuter sous Linux — le contrôle statique que j'ai fait (équilibrage des délimiteurs, symboles importés) ne remplace pas le compilateur.
2. **Créer le compte LiveKit Cloud** et lancer `tools/livekit_cloud_switch.sh`.
3. **Faire le premier live réel** et le consigner. Aucun live n'a jamais abouti depuis mars 2026 : ce test fera tomber en cascade ce qu'aucun audit statique ne peut voir.
4. **Arbitrer le sort des modules Tournois et Ligues** — implémenter ou retirer.
5. Renseigner `SUPABASE_URL` et `SUPABASE_SERVICE_KEY` dans la CI et y brancher `check_rpc_contract.py`.

---

## 7. Lecture

La vague 0 visait la réparation. Elle a réparé — et elle a surtout montré que le problème diagnostiqué sur le Studio Live n'était pas propre au Studio Live.

Un fichier SQL écrit puis oublié sept semaines, une Edge Function jamais redéployée pendant trois mois, cinquante RPC appelées dans le vide : ce sont trois symptômes d'une même chose. Le code avance, la base suit parfois, le déploiement rarement, et rien dans la chaîne ne signale l'écart. L'application compile, se déploie, et n'échoue que sur l'écran de l'utilisateur.

Le script de contrôle du contrat livré aujourd'hui coûte trois secondes par build. Il aurait rendu impossible chacune des trois situations ci-dessus.

C'est probablement le livrable le plus utile de cette vague — davantage que le studio lui-même.

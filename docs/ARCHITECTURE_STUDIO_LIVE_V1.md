# Architecture du Studio Live Academia — proposition complète

**Date** : 26 juillet 2026
**Statut** : proposition d'architecture, à valider avant tout développement
**Décisions déjà prises** : hébergement **LiveKit Cloud** · consultations **sur rendez-vous** + **depuis un cours/TD en contexte**
**Remplace / complète** : ADR-011, `docs/AUDIT_STUDIO_LIVE_2026-07-26.md`, `academia_app/docs/audit_live_streaming_plan.md`

---

## Sommaire

1. [Le problème à résoudre](#1)
2. [Le principe fondateur : une salle, plusieurs modes](#2)
3. [Architecture en cinq couches](#3)
4. [Le point d'entrée universel : `StudioLauncher`](#4)
5. [Modèle de données](#5)
6. [Contrats RPC](#6)
7. [L'interface : shell + modules enfichables](#7)
8. [Les six modes en détail](#8)
9. [Consultations : RDV et aide en contexte](#9)
10. [Qualité vidéo et adaptativité — la partie « imbattable »](#10)
11. [Intelligence : transcription, notes, résumé](#11)
12. [Replay intelligent](#12)
13. [Sécurité, modération, anti-piratage](#13)
14. [Ce qu'on emprunte à qui — benchmark](#14)
15. [Plan de réalisation par vagues](#15)
16. [Coûts](#16)
17. [Risques](#17)

---

<a name="1"></a>
## 1. Le problème à résoudre

### 1.1 Ce que l'audit a montré

Les onglets **Cours** (index 8) et **Lives** (index 9) du dashboard étudiant affichent un `StudentComingSoonTab` — en mobile comme en desktop. Pourtant `StudentCoursesTab` et `StudentLiveSessionsTab` existent et sont fonctionnels. Ce ne sont pas des modules à écrire : ce sont des modules **débranchés**.

Le vrai blocage est ailleurs, et il est structurel : le live a été construit **trois fois**, en parallèle, sans socle commun.

| Construction | Table | Écran | Statut |
|---|---|---|---|
| Prépa-Concours | `prep_live_sessions` | `PrepLivesTab` | 1 session zombie |
| Cours en ligne | `online_course_live_sessions` | `StudentLiveSessionsTab` | 1 session de test |
| Challenge TikTok | `challenge_game_live_sessions` | `ChallengeLiveScreen` | 11 annulées / 12 |
| TD | *aucune table* | `TdEnrollmentAccessScreen` | prévu, non fonctionnel |
| Unifié (juillet) | `academia_sessions` | `AcademiaClassroomScreen` | **0 ligne** |

Chaque module qui a besoin d'un live a recréé son propre chemin. Le moteur unifié de juillet était la bonne réponse — mais il a été construit comme une **quatrième** implémentation au lieu de remplacer les trois autres, et son Edge Function n'a jamais été déployée.

### 1.2 Ce qu'il faut construire

Non pas « un écran de live », mais **un service de live**. Un composant qu'un module invoque comme on appelle une fonction :

> « Je suis le module TD, chapitre 4, exercice 12. J'ai besoin d'un live de type atelier avec ce professeur et ces 8 étudiants. Ouvre-le. »

Le module ne sait rien de LiveKit, de tokens, de simulcast. Il déclare un **besoin**, le Studio répond par une **expérience**.

C'est le seul moyen d'éviter une cinquième implémentation dans six mois.

---

<a name="2"></a>
## 2. Le principe fondateur : une salle, plusieurs modes

Un live de classe virtuelle et un live TikTok ne sont pas deux produits. Ce sont **la même salle** avec :

- une **disposition** différente (grille vs plein écran portrait)
- une **matrice de droits** différente (tous publient vs un seul publie)
- des **modules activés** différents (tableau blanc vs cadeaux)

Tout le reste — transport, authentification, présence, enregistrement, transcription, modération — est identique.

D'où la règle d'architecture :

> **Un seul moteur. Un seul écran-hôte. Six modes. Aucune duplication.**

Ajouter un septième mode (soutenance, jury de concours, conférence partenaire) doit être une entrée dans une table de configuration, pas un nouvel écran Flutter.

### 2.1 Les six modes

| Mode | Métaphore | Publient | Disposition | Cas d'usage Academia |
|---|---|---|---|---|
| `classroom` | Zoom / Meet | tous | grille adaptative | Cours en ligne, séance TD |
| `amphi` | Discord Stage | hôte + invités montés sur scène | scène + galerie | Masterclass, cours magistral, révision collective |
| `broadcast` | TikTok Live | hôte seul | plein écran portrait | Challenge live, annonce, live communautaire |
| `duo` | TikTok Duo | 2 hôtes | split-screen | Débat, battle de challenge, co-animation |
| `consultation` | Doctolib visio | 1↔1 ou 1↔petit groupe | face-à-face + panneau contexte | Orientation, aide TD, coaching concours |
| `workshop` | Atelier | tous, ≤12 | grille + tableau blanc dominant | Atelier TD, correction d'exercices, groupe de travail |

### 2.2 La matrice de capacités

Chaque mode est un **préréglage** dans une table. Rien n'est codé en dur dans Flutter.

| Capacité | classroom | amphi | broadcast | duo | consultation | workshop |
|---|:-:|:-:|:-:|:-:|:-:|:-:|
| Vidéo participants | ✅ | scène | ❌ | 2 | ✅ | ✅ |
| Micro participants | ✅ | sur demande | ❌ | 2 | ✅ | ✅ |
| Chat texte | ✅ | ✅ | ✅ défilant | ✅ défilant | ✅ | ✅ |
| Réactions emoji | ✅ | ✅ | ✅ pluie | ✅ pluie | — | ✅ |
| Main levée | ✅ | ✅ montée scène | ✅ demande duo | — | — | ✅ |
| Partage d'écran | hôte | hôte | hôte | ✅ | ✅ | ✅ |
| Tableau blanc | ✅ | hôte | ❌ | ❌ | ✅ | ✅ **dominant** |
| Quiz / sondage | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ |
| Exercice poussé | ✅ | ✅ | ❌ | ❌ | ✅ | ✅ |
| Notes personnelles | ✅ | ✅ | ❌ | ❌ | ✅ | ✅ |
| Sous-titres live | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Enregistrement | option | ✅ | option | option | consentement | option |
| Résumé IA | ✅ | ✅ | ❌ | ❌ | ✅ | ✅ |
| Breakout rooms | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ |
| Cadeaux / coins | ❌ | ❌ | ✅ | ✅ | ❌ | ❌ |
| Compteur spectateurs | ❌ | ✅ | ✅ | ✅ | ❌ | ❌ |

---

<a name="3"></a>
## 3. Architecture en cinq couches

```
┌──────────────────────────────────────────────────────────────────┐
│  COUCHE 5 — INTELLIGENCE                                         │
│  Agent « Academia Scribe » (LiveKit Agents)                      │
│  STT temps réel · sous-titres · transcript · résumé · quiz auto  │
└──────────────────────────────────────────────────────────────────┘
                              ▲
┌──────────────────────────────────────────────────────────────────┐
│  COUCHE 4 — STUDIO (Flutter)                                     │
│  StudioShell + modules enfichables + 6 dispositions responsive   │
│  Point d'entrée unique : StudioLauncher.open(request)            │
└──────────────────────────────────────────────────────────────────┘
                              ▲
┌──────────────────────────────────────────────────────────────────┐
│  COUCHE 3 — CAPACITÉS                                            │
│  studio_modes (préréglages) → capabilities jsonb par session     │
│  Résolution : mode + rôle + réseau → ce que l'UI affiche         │
└──────────────────────────────────────────────────────────────────┘
                              ▲
┌──────────────────────────────────────────────────────────────────┐
│  COUCHE 2 — SESSION (Supabase)                                   │
│  academia_sessions étendue · participants · messages · quiz      │
│  notes · transcript · résumés · événements · réservations        │
│  Accès exclusivement par RPC SECURITY DEFINER                    │
└──────────────────────────────────────────────────────────────────┘
                              ▲
┌──────────────────────────────────────────────────────────────────┐
│  COUCHE 1 — TRANSPORT (LiveKit Cloud)                            │
│  SFU mesh mondial · simulcast · dynacast · adaptive stream       │
│  Egress room-composite · Agents · E2EE optionnel                 │
└──────────────────────────────────────────────────────────────────┘
```

**Règle de dépendance** : une couche ne connaît que celle du dessous. Le Studio (4) ne parle jamais directement à LiveKit (1) — il passe par la couche Session (2) qui lui remet un token et une matrice de capacités. C'est ce découplage qui a permis à l'ADR-011 de dire, à juste titre, que changer de fournisseur SFU = changer trois secrets.

---

<a name="4"></a>
## 4. Le point d'entrée universel : `StudioLauncher`

C'est le cœur de la demande : **un studio réutilisable, appelable depuis n'importe quel module**.

### 4.1 Le contrat

```dart
class StudioLaunchRequest {
  final StudioMode mode;              // classroom | amphi | broadcast | duo | consultation | workshop
  final StudioOrigin origin;          // d'où vient l'appel
  final String? sessionId;            // session existante, ou null pour créer
  final StudioRole role;              // host | cohost | speaker | participant | viewer | moderator
  final Map<String, dynamic> context; // contexte pédagogique transmis au studio
}

class StudioOrigin {
  final String module;      // 'course' | 'td' | 'prep' | 'orientation' | 'challenge' | 'community'
  final String entityId;    // course_id, td_program_id, prep_program_id…
  final String? chapterId;
  final String? lessonId;
  final String? exerciseId;
}
```

### 4.2 Les appels, depuis chaque module

```dart
// Depuis une leçon de cours en ligne
StudioLauncher.open(StudioLaunchRequest(
  mode: StudioMode.classroom,
  origin: StudioOrigin(module: 'course', entityId: courseId, lessonId: lessonId),
  role: StudioRole.participant,
));

// Depuis un exercice TD sur lequel l'étudiant bloque
StudioLauncher.open(StudioLaunchRequest(
  mode: StudioMode.consultation,
  origin: StudioOrigin(module: 'td', entityId: programId, exerciseId: exId),
  role: StudioRole.participant,
  context: {'question': 'Je ne comprends pas la question 3b', 'attempts': 4},
));

// Depuis le feed Challenge, bouton « Go Live »
StudioLauncher.open(StudioLaunchRequest(
  mode: StudioMode.broadcast,
  origin: StudioOrigin(module: 'challenge', entityId: challengeId),
  role: StudioRole.host,
));
```

### 4.3 Ce que fait le launcher

```
StudioLauncher.open(request)
   │
   ├─ 1. Résout ou crée la session
   │      RPC studio_resolve_session(request) → session_id + capabilities + role
   │
   ├─ 2. Vérifie le droit d'accès
   │      inscription, paiement, créneau réservé, session ouverte ?
   │      → si non : écran d'explication, jamais un écran noir
   │
   ├─ 3. Obtient le token LiveKit
   │      Edge Function livekit-token → token + url + room + grants
   │
   ├─ 4. Charge le contexte pédagogique
   │      chapitre, exercice, ressources, historique de l'étudiant
   │
   ├─ 5. Sélectionne le profil réseau
   │      mesure de débit + préférence utilisateur → profil qualité initial
   │
   └─ 6. Ouvre StudioShell(mode, capabilities, context)
```

**Le module appelant n'écrit aucune de ces six étapes.** C'est précisément ce qui manquait : chaque module avait réécrit les étapes 1 à 3 à sa façon.

---

<a name="5"></a>
## 5. Modèle de données

### 5.1 Extension de `academia_sessions`

La table existe et sa structure est bonne. On l'étend plutôt que de la refaire.

```sql
ALTER TABLE app.academia_sessions
  ADD COLUMN mode              text NOT NULL DEFAULT 'classroom',
  ADD COLUMN capabilities      jsonb NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN origin_module     text,
  ADD COLUMN origin_entity_id  uuid,
  ADD COLUMN origin_context    jsonb DEFAULT '{}'::jsonb,
  ADD COLUMN visibility        text NOT NULL DEFAULT 'enrolled',
  ADD COLUMN recording_policy  text NOT NULL DEFAULT 'optional',
  ADD COLUMN quality_profile   text NOT NULL DEFAULT 'auto',
  ADD COLUMN transcript_status text DEFAULT 'none',
  ADD COLUMN summary_status    text DEFAULT 'none',
  ADD COLUMN cohost_ids        uuid[] DEFAULT '{}',
  ADD COLUMN peak_participants integer DEFAULT 0,
  ADD COLUMN total_minutes     integer DEFAULT 0;
```

Les six booléens existants (`is_chat_enabled`, etc.) restent — ils deviennent des **surcharges** ponctuelles au-dessus du préréglage de mode.

### 5.2 Table des préréglages

```sql
CREATE TABLE app.studio_modes (
  mode              text PRIMARY KEY,
  label_fr          text NOT NULL,
  default_layout    text NOT NULL,
  capabilities      jsonb NOT NULL,
  max_publishers    integer,
  max_participants  integer,
  requires_booking  boolean DEFAULT false,
  is_active         boolean DEFAULT true
);
```

Ajouter un mode « soutenance » = un `INSERT`. Zéro ligne de Dart.

### 5.3 Nouvelles tables

| Table | Rôle | Clés |
|---|---|---|
| `academia_session_messages` | Chat persistant, survit à la déconnexion | `session_id, author_id, body, reply_to_id, is_pinned, created_at` |
| `academia_session_quiz_questions` | Questions posées en séance | `session_id, question, options jsonb, correct_index, duration_seconds, launched_at` |
| `academia_session_quiz_answers` | Réponses des étudiants | `question_id, user_id, answer_index, answered_at, response_ms` |
| `academia_session_notes` | Notes personnelles horodatées | `session_id, user_id, body, video_offset_ms, tags[]` |
| `academia_session_transcript` | Transcription par segment | `session_id, speaker_id, text, start_ms, end_ms, confidence, lang` |
| `academia_session_summaries` | Résumés IA | `session_id, kind, content jsonb, model, generated_at` |
| `academia_session_events` | Timeline pour chapitrage | `session_id, kind, actor_id, payload jsonb, offset_ms` |
| `academia_session_recordings` | Enregistrements et rendus | `session_id, egress_id, status, raw_url, renditions jsonb, duration_ms` |
| `academia_whiteboard_snapshots` | États du tableau blanc | `session_id, strokes jsonb, offset_ms, page_index` |
| `academia_session_reactions` | Agrégats de réactions | `session_id, emoji, count, bucket_minute` |
| `advisor_profiles` | Intervenants consultables | `user_id, kind, specialities[], bio, languages[], rate, rating, is_active` |
| `advisor_availability` | Créneaux offerts | `advisor_id, weekday, start_time, end_time, valid_from, valid_to, slot_minutes` |
| `consultation_bookings` | Réservations | `advisor_id, student_id, session_id, scheduled_at, status, origin_context jsonb` |
| `help_requests` | Demandes d'aide en contexte | `student_id, module, entity_id, exercise_id, question, status, booking_id` |

`advisor_profiles.kind` ∈ `orientation_counselor | td_teacher | prep_teacher | tutor | career_advisor | psychologist`. C'est la table qui répond à « il peut faire appel à un conseiller d'orientation, à un professeur de TD ou de prépa concours ou tout autre ».

### 5.4 Migration des trois systèmes existants

Le moteur unifié ne doit pas devenir la quatrième roue. Plan de convergence :

| Étape | Action |
|---|---|
| 1 | Vues de compatibilité : `prep_live_sessions` et `online_course_live_sessions` deviennent des vues lisibles au-dessus de `academia_sessions` filtré par `origin_module` |
| 2 | Écriture double pendant une période de recouvrement (nouvelles sessions dans `academia_sessions` uniquement) |
| 3 | Reprise des 2 sessions legacy existantes (volume trivial) |
| 4 | Suppression des tables legacy et des ~19 RPC associées |
| 5 | `challenge_game_live_sessions` converge en dernier (`mode = 'broadcast'`) |

---

<a name="6"></a>
## 6. Contrats RPC

### 6.1 Ce qui existe et qu'on garde

Les 16 RPC `app_learning_*` du Learning Engine sont bien conçues. On les conserve, on en renomme le préfixe en `studio_` pour la lisibilité (avec alias de compatibilité), et on ajoute ce qui manque.

### 6.2 RPC à créer

**Socle**

| RPC | Rôle |
|---|---|
| `studio_resolve_session(p_request jsonb)` | Cœur du launcher : résout ou crée, vérifie les droits, renvoie session + capacités + rôle |
| `studio_get_capabilities(p_session_id)` | Matrice effective (mode ∩ surcharges ∩ rôle) |
| `studio_set_role(p_session_id, p_user_id, p_role)` | Montée sur scène, passage co-hôte, rétrogradation |

**Chat** — le SQL existe déjà dans `.devin/sql_changes/change_20260608_academia_chat_rpcs.sql`, jamais appliqué. À reprendre tel quel.

| `studio_send_message` · `studio_list_messages` · `studio_delete_message` · `studio_pin_message` |

**Quiz**

| `studio_quiz_create_question` · `studio_quiz_launch` · `studio_quiz_submit_answer` · `studio_quiz_results` · `studio_quiz_list_questions` |

**Notes et transcript**

| `studio_note_upsert` · `studio_notes_list` · `studio_transcript_append` · `studio_transcript_search` |

**Résumés**

| `studio_summary_request` · `studio_summary_get` |

**Replay**

| `studio_replay_get` · `studio_replay_timeline` · `studio_replay_chapters` |

**Consultations**

| `studio_advisor_search(p_kind, p_speciality, p_lang)` · `studio_advisor_slots(p_advisor_id, p_from, p_to)` · `studio_booking_create` · `studio_booking_cancel` · `studio_booking_list_mine` · `studio_help_request_create` · `studio_help_request_claim` |

### 6.3 Garde-fou contre la dérive constatée

L'audit a trouvé 9 RPC appelées par Flutter mais absentes de la base, dont un fichier SQL oublié pendant sept semaines. Ce n'est pas un accident isolé, c'est une conséquence d'un processus sans vérification.

**À mettre en place dès la vague 0** : un test d'intégration qui extrait par regex tous les `rpc('...')` du code Dart, interroge `pg_proc`, et échoue si un appel n'a pas de fonction correspondante. Dix minutes à écrire, il aurait évité l'intégralité de la section 4.2 de l'audit.

---

<a name="7"></a>
## 7. L'interface : shell + modules enfichables

### 7.1 Arborescence proposée

```
lib/features/studio/
├── studio_launcher.dart          ← point d'entrée universel
├── studio_shell.dart             ← écran-hôte, layout responsive
├── studio_controller.dart        ← machine à états (connexion, qualité, rôles)
├── studio_capabilities.dart      ← matrice résolue
├── layouts/
│   ├── grid_layout.dart          ← classroom, workshop
│   ├── stage_layout.dart         ← amphi (scène + bande de galerie)
│   ├── portrait_layout.dart      ← broadcast (plein écran vertical)
│   ├── split_layout.dart         ← duo
│   ├── focus_layout.dart         ← partage d'écran / tableau blanc dominant
│   └── face_layout.dart          ← consultation
├── modules/
│   ├── chat_module.dart
│   ├── quiz_module.dart
│   ├── notes_module.dart
│   ├── whiteboard_module.dart
│   ├── participants_module.dart
│   ├── reactions_module.dart
│   ├── transcript_module.dart
│   ├── exercise_module.dart
│   ├── ai_assistant_module.dart
│   ├── breakout_module.dart
│   └── gifts_module.dart
├── docks/
│   ├── side_rail.dart            ← desktop ≥1024px
│   ├── bottom_sheet_dock.dart    ← tablette et mobile paysage
│   └── overlay_dock.dart         ← mobile portrait (broadcast)
└── quality/
    ├── network_profiler.dart
    ├── quality_controller.dart
    └── degradation_ladder.dart
```

### 7.2 Réutilisation de l'existant

**Rien de tout cela n'est à écrire de zéro.** Les 18 fichiers de `lib/features/live/` sont réorganisés :

| Existant | Devient |
|---|---|
| `academia_classroom_screen.dart` (804 l.) | `studio_shell.dart` + `studio_controller.dart` |
| `widgets/academia_persistent_chat_panel.dart` | `modules/chat_module.dart` |
| `widgets/academia_quiz_overlay.dart` + `..._student_overlay.dart` | `modules/quiz_module.dart` |
| `whiteboard/` (4 fichiers) | `modules/whiteboard_module.dart` |
| `widgets/academia_participants_panel.dart` | `modules/participants_module.dart` |
| `widgets/academia_reactions_overlay.dart` | `modules/reactions_module.dart` |
| `widgets/academia_td_exercise_overlay.dart` | `modules/exercise_module.dart` |
| `widgets/academia_ai_panel.dart` | `modules/ai_assistant_module.dart` |
| `challenge_live_screen.dart` | `layouts/portrait_layout.dart` + `modules/gifts_module.dart` |
| `challenge_live_duo_screen.dart` | `layouts/split_layout.dart` |
| `academia_replay_screen.dart` | écran replay, enfin branché |
| `livekit_room_screen.dart` (1 329 l.) | **supprimé** |
| `widgets/live_quiz_overlay.dart` (478 l.) | **supprimé** |

Le travail est un **refactor de réorganisation**, pas une réécriture. C'est ce qui rend le calendrier de la section 15 réaliste.

### 7.3 Responsive — six contextes, un seul code

| Contexte | Largeur | Disposition | Dock |
|---|---|---|---|
| Mobile portrait | < 600 | portrait / face | overlay glissant |
| Mobile paysage | < 900 | grid 2 col. / stage | bottom sheet |
| Tablette portrait | 600–1024 | grid 2 col. | bottom sheet |
| Tablette paysage | 900–1280 | grid 3 col. + rail | rail étroit |
| Desktop | ≥ 1280 | grid 4 col. + rail | rail large |
| TV / projecteur | ≥ 1920 | stage plein écran | masqué |

Contraintes Android à respecter : **API 21 minimum** (le parc burkinabè comporte encore beaucoup d'Android 5–8), donc pas de dépendance à une API récente pour le rendu vidéo ; foreground service déclaré pour le partage d'écran ; `PictureInPicture` sur API 26+ avec repli sur notification persistante en dessous.

---

<a name="8"></a>
## 8. Les six modes en détail

### 8.1 `classroom` — la classe virtuelle

**Référence** : Zoom, Google Meet, Engageli.

Disposition en grille adaptative (1/2/3/4 colonnes selon la largeur), locuteur actif mis en évidence par un liseré, bascule vers `focus_layout` dès qu'un partage d'écran ou le tableau blanc démarre.

Barre de contrôle : micro, caméra, partage d'écran, main levée, réactions, tableau blanc, quiz, notes, participants, quitter. Sur mobile, les six moins utilisés passent dans un menu « … ».

**Spécificité pédagogique** : un bandeau « Suivi de séance » visible de l'enseignant seul, montrant en temps réel le taux de présence, le nombre de mains levées, les réponses au dernier quiz, et un indicateur d'attention (onglet au premier plan ou non). C'est ce que fait Engageli et que Zoom ne fait pas.

### 8.2 `amphi` — le cours magistral

**Référence** : Discord Stage, Zoom Webinar, YouTube Live.

L'hôte et les intervenants sont « sur scène ». Les étudiants écoutent, chattent, lèvent la main. L'hôte peut **monter un étudiant sur scène** d'un geste : il devient publisher le temps de sa question, puis redescend.

Ce mode change tout économiquement : 300 étudiants qui écoutent coûtent la bande passante de 300 abonnés, pas de 300 publishers. C'est le mode par défaut recommandé au-delà de 25 participants.

### 8.3 `broadcast` — le live vertical

**Référence** : TikTok Live, Instagram Live, Facebook Live.

Plein écran portrait, chat qui défile par-dessus la vidéo, réactions qui montent en pluie, compteur de spectateurs, épinglage de commentaire, Q&R à l'écran. TikTok gère jusqu'à 20 co-hôtes en multi-guest ; nous n'en visons que 2 (mode `duo`), le reste étant du bruit pour un usage éducatif.

**Adaptation pédagogique** : les « cadeaux » deviennent des **crédits Academia** — déjà présents dans le projet (`credit_packs`). Un étudiant peut soutenir un créateur de contenu pédagogique ; le créateur convertit en revenus via le système de payout Ligdicash existant. Le circuit économique existe déjà, il suffit de le brancher.

### 8.4 `duo` — le face-à-face public

**Référence** : TikTok Duo/Battle.

Deux hôtes, écran partagé vertical ou horizontal. Usage : battle de challenge, débat entre deux étudiants, co-animation professeur + intervenant invité. Invitation par Data Channel depuis un `broadcast` en cours.

### 8.5 `consultation` — le rendez-vous

Voir section 9 en entier.

### 8.6 `workshop` — l'atelier

**Référence** : Miro + Zoom, salles de travail Engageli.

Le tableau blanc occupe 60 % de l'écran, les vignettes vidéo sont réduites en bande. Douze participants maximum. L'exercice TD en cours est affiché en surimpression et annotable collectivement.

**Breakout rooms** : l'enseignant scinde en sous-groupes ; chaque sous-groupe est une room LiveKit enfant. L'enseignant « saute » d'une salle à l'autre depuis un tableau de bord qui montre l'activité de chacune (le *room hopping* d'Engageli). Retour groupé d'un clic.

---

<a name="9"></a>
## 9. Consultations : RDV et aide en contexte

C'est la brique la plus différenciante, et celle qui n'existe nulle part dans le code actuel.

### 9.1 Les deux chemins retenus

**Chemin A — sur rendez-vous**

```
Étudiant → « Prendre rendez-vous »
   ├─ filtre : type d'intervenant, spécialité, langue, note
   ├─ liste d'intervenants avec créneaux disponibles
   ├─ choix du créneau → consultation_bookings (status: confirmed)
   ├─ notification + rappel J-1 et H-1 (send-push-notifications existe déjà)
   └─ H-0 : la session s'ouvre, les deux parties reçoivent un lien direct
```

**Chemin B — depuis un cours ou un TD, en contexte**

C'est le chemin le plus précieux pédagogiquement, et le plus simple pour l'étudiant.

```
Étudiant bloqué sur l'exercice 3b du chapitre 4
   │
   ├─ Bouton « Demander de l'aide » présent dans le lecteur d'exercice
   │
   ├─ help_requests créé AVEC LE CONTEXTE :
   │     module=td, entity=programme, exercise=3b,
   │     tentatives=4, dernière réponse, temps passé, question libre
   │
   ├─ Routage : intervenants du programme concerné notifiés
   │
   ├─ Un intervenant réclame la demande (studio_help_request_claim)
   │     → propose 2 ou 3 créneaux
   │
   ├─ Étudiant choisit → consultation_bookings
   │
   └─ À l'ouverture du studio : le panneau contexte affiche DÉJÀ
         l'exercice, les 4 tentatives de l'étudiant, et sa question.
         Le professeur n'a rien à demander. La consultation commence
         à la minute 0 sur le fond, pas sur « alors, c'était quoi ta question ? »
```

### 9.2 Ce que voit l'intervenant à l'ouverture

Le panneau contexte (à droite en desktop, en onglet sur mobile) présente :

- l'exercice ou le chapitre concerné, rendu à l'identique
- l'historique des tentatives de l'étudiant sur cet exercice
- son niveau global dans la matière (données déjà présentes dans les tables TD et prépa)
- la question libre qu'il a écrite
- ses notes de séances précédentes, s'il en a autorisé le partage

### 9.3 Le tableau de bord de l'intervenant

- Mes créneaux (grille hebdomadaire, édition directe)
- Demandes d'aide en attente, triées par ancienneté et par urgence pédagogique
- Mes consultations à venir avec contexte pré-chargé
- Historique, résumés IA des séances passées, revenus

### 9.4 Consentement et vie privée

Une consultation est une conversation asymétrique et parfois sensible — surtout avec un conseiller d'orientation ou un psychologue scolaire. Règles :

- enregistrement **désactivé par défaut**, activable seulement avec consentement explicite des deux parties, matérialisé à l'écran par un bandeau permanent
- transcript et résumé visibles par l'étudiant et l'intervenant seuls, jamais par l'administration
- `kind = 'psychologist'` : E2EE activé, aucun enregistrement possible, pas de transcript serveur

---

<a name="10"></a>
## 10. Qualité vidéo et adaptativité — la partie « imbattable »

C'est la demande explicite : une qualité irréprochable sur n'importe quel appareil et n'importe quel réseau. Le contexte ouest-africain rend ce point plus décisif qu'ailleurs.

### 10.1 Les trois mécanismes LiveKit à activer d'emblée

| Mécanisme | Ce qu'il fait | Gain mesuré |
|---|---|---|
| **Simulcast** | Le publisher encode 3 couches (par ex. 720p / 360p / 180p), le SFU sert à chacun la sienne | Base de tout le reste |
| **Dynacast** | Met en pause l'encodage des couches que personne ne consomme | 30–60 % de CPU en moins, jusqu'à 60 % d'upload en moins, **20–40 % d'autonomie batterie en plus** |
| **Adaptive Stream** | Choisit la résolution reçue selon la taille réelle du widget vidéo à l'écran, et coupe le flux d'une vignette invisible | Bande passante descendante divisée par 2 à 4 en grille |

Ces trois réglages sont disponibles dans `livekit_client` pour Flutter via `RoomOptions(adaptiveStream: true, dynacast: true)`. **Ils ne sont pas activés dans le code actuel.** C'est la correction au meilleur rapport effort/gain de tout ce document : deux paramètres.

### 10.2 Stratégie de codec

| Plateforme | Codec | Justification |
|---|---|---|
| Android < API 29, entrée de gamme | **H.264 baseline** | Encodage matériel universel, batterie préservée, pas de surchauffe |
| Android récent, iOS | **H.264 high** puis VP9 si négocié | Compromis qualité / consommation |
| Web desktop Chrome/Edge | **VP9 SVC** | 40–60 % d'upload en moins qu'un simulcast VP8, SVC natif |
| Expérimental, opt-in | **AV1 SVC** | ~50 % de mieux que H.264, mais encodage matériel encore rare — à réserver aux machines puissantes |

**Décision** : H.264 reste le défaut mobile en 2026. Le gain théorique de l'AV1 s'évapore dès qu'un téléphone d'entrée de gamme doit l'encoder en logiciel — il chauffe, vide la batterie, et le débit s'effondre. VP9 SVC est activé automatiquement quand le navigateur le négocie.

### 10.3 L'échelle de dégradation

Quatre profils, sélection automatique par défaut, forçage manuel toujours possible.

| Profil | Vidéo montante | Vidéo descendante | Débit approximatif |
|---|---|---|---|
| **Confort** | 720p 30 i/s | jusqu'à 720p | ~1,5 Mb/s |
| **Standard** | 360p 24 i/s | jusqu'à 360p | ~600 kb/s |
| **Économie** | 180p 15 i/s | 180p, 4 vignettes max | ~200 kb/s |
| **Audio seul** | audio | audio | ~40 kb/s |

La bascule est automatique sur la base de `ConnectionQuality` renvoyée par LiveKit, avec hystérésis (on descend vite, on remonte lentement) pour éviter l'oscillation.

### 10.4 Le mode faible débit pédagogique — l'argument différenciant

C'est la proposition qui distingue vraiment Academia de Zoom sur ce marché.

> Quand le réseau s'effondre, Zoom coupe la vidéo et laisse l'audio. **Le cours s'arrête visuellement.**
>
> Academia coupe la vidéo mais garde **l'audio, le tableau blanc et les sous-titres en direct**. Le tableau blanc est vectoriel : quelques kilo-octets par minute. La transcription : quelques centaines d'octets par phrase.
>
> **Le cours continue à 40 kb/s.** L'étudiant voit le professeur écrire, l'entend, et lit ce qu'il dit.

Sur un réseau où une visio classique devient inutilisable, le cours reste suivable. Pour un étudiant à Bobo-Dioulasso en 3G saturée, ce n'est pas un détail de confort — c'est la différence entre suivre le cours et le manquer.

Un indicateur permanent explique ce qui se passe : « Réseau faible — vidéo suspendue, cours en cours » plutôt qu'un gel silencieux qui laisse croire à un bug.

### 10.5 Matrice de compatibilité visée

| Appareil | Cible |
|---|---|
| Android 5–7, 1 Go RAM | Audio + tableau blanc + chat + sous-titres, vidéo 180p si réseau |
| Android 8–11, 2–3 Go | Classe complète 360p, tableau blanc, quiz |
| Android 12+, 4 Go+ | 720p, partage d'écran, tout activé |
| iOS 14+ | Parité complète, PiP natif |
| Web desktop | 720p+, VP9, double écran, deux caméras |
| Tablette | Mode tableau blanc au stylet privilégié |

---

<a name="11"></a>
## 11. Intelligence : transcription, notes, résumé

### 11.1 L'agent « Academia Scribe »

Un agent LiveKit rejoint la room comme participant invisible. Il fait quatre choses :

1. **Sous-titres en direct** — STT temps réel publié dans la room, affiché en surimpression. Bascule français / anglais, et à terme mooré, dioula, fulfuldé pour les cours en langue locale.
2. **Transcript horodaté** — chaque segment avec locuteur identifié, écrit dans `academia_session_transcript`.
3. **Traduction live** — le pipeline `live-translated-captioning` de LiveKit permet à un étudiant anglophone de suivre un cours en français.
4. **Détection d'événements** — « le professeur vient d'énoncer une définition », « une question a été posée » — alimente le chapitrage automatique du replay.

### 11.2 Prise de notes

Le module notes est un panneau latéral où l'étudiant écrit pendant le cours. Chaque note est **ancrée au timecode** de la séance. Au replay, cliquer sur une note saute à l'instant exact où elle a été prise.

Trois gestes rapides : « marquer ce moment » (signet), « capturer le tableau » (instantané du tableau blanc inséré dans les notes), « je n'ai pas compris » (marque un point de confusion — l'enseignant en voit le total agrégé, jamais les identités, et sait qu'il doit reprendre).

Ce dernier point est celui que les enseignants réclament le plus et qu'aucune plateforme grand public n'offre.

### 11.3 Le résumé de fin de séance

Généré automatiquement dans les minutes qui suivent la fin, à partir du transcript, des événements et du tableau blanc :

- résumé en 10 lignes
- plan structuré de la séance avec minutages
- concepts clés et définitions énoncées
- questions posées par les étudiants et réponses données
- décisions et devoirs annoncés
- **quiz de révision auto-généré** (5 questions) — le projet a déjà `prep-generate-questions`, il suffit de l'alimenter avec le transcript
- exercices recommandés depuis la banque TD/prépa existante

Livré à l'étudiant en notification, et déposé dans son espace de cours.

C'est ce que font Gemini dans Meet et AI Companion dans Zoom. La différence : chez nous le résumé n'est pas une note de réunion, c'est **un support de révision** relié à la banque d'exercices et au moteur de quiz déjà en place.

### 11.4 Coût maîtrisé

L'agent coûte ~0,01 $/min contre ~0,0005 $/min pour un participant humain — vingt fois plus cher. Règles :

- l'agent n'est **pas** activé par défaut sur les modes `broadcast` et `duo`
- sur `classroom` et `amphi`, il est activé si la session est enregistrée ou si l'enseignant le demande
- le résumé peut aussi être produit **après coup** à partir du transcript de l'enregistrement, sans agent temps réel — trois fois moins cher, sous-titres en direct en moins

---

<a name="12"></a>
## 12. Replay intelligent

Le replay ne doit pas être « la vidéo de la séance ». C'est un objet composite :

| Composant | Source |
|---|---|
| Vidéo composite | LiveKit Egress room-composite → Supabase Storage |
| Rendus multi-résolution | `transcode-multi-resolution` **existe déjà** dans le projet |
| Transcript cliquable | `academia_session_transcript` |
| Chapitres automatiques | `academia_session_events` + détection de l'agent |
| Tableau blanc rejouable | `academia_whiteboard_snapshots` — rejoué en vectoriel, pas en pixels |
| Quiz de la séance | rejouables en différé, avec correction |
| Notes personnelles | ancrées au timecode |
| Résumé IA | `academia_session_summaries` |

**Recherche plein texte dans le replay** : l'étudiant tape « théorème de Thalès », le lecteur saute aux trois moments où le professeur l'a prononcé. C'est la fonctionnalité qui transforme un enregistrement en ressource pédagogique.

Le rejeu du tableau blanc en vectoriel permet de consulter un replay en 240p tout en gardant un tableau parfaitement net — ce qu'aucune capture vidéo ne permet.

---

<a name="13"></a>
## 13. Sécurité, modération, anti-piratage

### 13.1 Rôles

| Rôle | Peut |
|---|---|
| `host` | tout, y compris terminer, enregistrer, exclure |
| `cohost` | animer, modérer, partager, lancer un quiz |
| `speaker` | publier audio/vidéo temporairement (monté sur scène) |
| `participant` | écouter, chatter, réagir, lever la main |
| `viewer` | écouter, chatter (broadcast) |
| `moderator` | modérer le chat, exclure — sans être visible |

### 13.2 Corrections de sécurité requises

- **`app.user_roles` n'existe pas.** Aujourd'hui le contrôle « admin » dans `livekit-admin`, `livekit-recording` et `app_learning_presence_list` dégrade silencieusement vers « non-admin » : un administrateur ne peut pas modérer une session dont il n'est pas l'hôte, alors que l'écran admin lui propose le bouton. À créer, ou à retirer de l'UI.
- **RLS** sur toutes les nouvelles tables, accès exclusif par RPC `SECURITY DEFINER` — patron déjà établi et correct dans le projet.
- **`REVOKE EXECUTE FROM anon`** sur les RPC qui n'ont pas vocation à être publiques.
- **Rotation des clés** LiveKit et Supabase service role au moment de la bascule Cloud — l'occasion est parfaite, les clés changent de toute façon.

### 13.3 Anti-piratage

- **Watermark dynamique** avec le nom et l'identifiant de l'étudiant en surimpression discrète, déplacé aléatoirement. La fonction `content-watermark` existe déjà dans le projet.
- Détection de capture d'écran sur Android (`FLAG_SECURE` optionnel par session, activable pour les contenus premium).
- Token à durée courte pour les sessions payantes (30 min renouvelées), plutôt que les 4 h actuelles.
- Un seul appareil connecté par compte et par session.

### 13.4 Modération du chat

Filtre de langage, signalement, mise en sourdine temporaire, mode « abonnés seulement » et mode lent en `broadcast` — les mécanismes que TikTok et Twitch ont rendus standards.

---

<a name="14"></a>
## 14. Ce qu'on emprunte à qui — benchmark

| Fonctionnalité | Empruntée à | Adaptation Academia |
|---|---|---|
| Grille + locuteur actif | Zoom, Meet | Identique |
| Montée sur scène | Discord Stage | Étudiant qui pose sa question |
| Breakout + room hopping | Engageli, Zoom | Sous-groupes TD, l'enseignant circule |
| Sous-titres et résumé IA | Gemini (Meet), AI Companion (Zoom) | Résumé = support de révision + quiz auto |
| Chat vertical, réactions en pluie | TikTok Live | Identique en mode broadcast |
| Multi-guest / co-host | TikTok Live (jusqu'à 20) | Limité à 2 — au-delà, c'est du bruit en pédagogie |
| Cadeaux virtuels | TikTok Coins | Crédits Academia, payout Ligdicash déjà en place |
| Q&R épinglée | TikTok, YouTube Live | Identique |
| Tableau blanc collaboratif | Miro, Jamboard | Vectoriel, rejouable, résistant au faible débit |
| Notes ancrées au timecode | Riverside, Otter | Sauter au moment exact depuis une note |
| Recherche dans le transcript | Otter, Read AI | Recherche dans le replay |
| Suivi d'engagement | Engageli | Agrégé et anonyme, jamais nominatif |

**Ce que personne ne fait et que nous ferons :**

1. Le **mode faible débit pédagogique** — tableau blanc + audio + sous-titres à 40 kb/s.
2. Le bouton **« je n'ai pas compris »** anonyme, agrégé en direct pour l'enseignant.
3. La **consultation en contexte** — le professeur arrive en sachant déjà sur quoi l'étudiant bloque.
4. Le **replay composite** où le tableau blanc reste net quelle que soit la résolution vidéo.

---

<a name="15"></a>
## 15. Plan de réalisation par vagues

### Vague 0 — Déblocage (2 à 3 jours)

Rien de neuf, uniquement la réparation de ce que l'audit a trouvé.

1. Redéployer `livekit-token` (une commande — débloque tout le moteur unifié)
2. Créer le projet LiveKit Cloud, poser les 3 secrets, redéployer les 3 fonctions
3. Activer `adaptiveStream` et `dynacast` dans `RoomOptions`
4. Appliquer le SQL de chat oublié depuis le 8 juin
5. Rebrancher les onglets 8 et 9 sur `StudentCoursesTab` et `StudentLiveSessionsTab`
6. **Premier live réel de bout en bout**, documenté
7. Mettre en place le test de cohérence RPC Dart ↔ base

**Sortie de vague** : un live fonctionne. Aucun live n'a jamais fonctionné jusqu'ici — c'est le jalon qui compte.

### Vague 1 — Socle Studio (1 à 2 semaines)

8. `studio_modes` + extension de `academia_sessions`
9. `StudioLauncher` + `studio_resolve_session`
10. Refactor de `AcademiaClassroomScreen` en `StudioShell` + modules
11. Layouts `grid` et `focus`, docks responsive
12. Suppression du code mort (~1 800 lignes)
13. Modes `classroom` et `workshop` opérationnels

### Vague 2 — Modules pédagogiques (1 à 2 semaines)

14. RPC quiz + module quiz complet
15. Module notes ancrées au timecode
16. Bouton « je n'ai pas compris » + bandeau de suivi enseignant
17. Tableau blanc : pages multiples, instantanés, rejeu
18. Breakout rooms + room hopping

### Vague 3 — Enregistrement et replay (1 semaine)

19. Egress room-composite → Storage → `transcode-multi-resolution` existant
20. RPC replay + chapitrage
21. Écran replay composite, enfin branché

### Vague 4 — Intelligence (1 à 2 semaines)

22. Agent Academia Scribe : STT, sous-titres, transcript
23. Résumé de fin de séance + quiz auto-généré
24. Recherche plein texte dans le replay

### Vague 5 — Consultations (1 à 2 semaines)

25. `advisor_profiles`, disponibilités, réservations
26. Parcours RDV côté étudiant et côté intervenant
27. `help_requests` depuis un exercice TD ou une leçon
28. Mode `consultation` + panneau contexte
29. Consentement, E2EE pour les cas sensibles

### Vague 6 — Diffusion (1 semaine)

30. Modes `broadcast` et `duo` migrés dans le Studio
31. Crédits/cadeaux branchés sur le payout existant
32. Modération de chat en direct

### Vague 7 — Qualité extrême (1 semaine)

33. Profils réseau + échelle de dégradation
34. Mode faible débit pédagogique
35. Sélection de codec par plateforme
36. Watermark dynamique, tokens courts
37. Campagne de tests sur parc réel : Android 5 à 15, 2G à fibre

**Total : 8 à 11 semaines** pour l'intégralité. La vague 0 seule, en 2 à 3 jours, rend le live utilisable.

---

<a name="16"></a>
## 16. Coûts

Tarifs LiveKit Cloud 2026 : WebRTC ~0,0005 $/min/participant, bande passante sortante 0,10–0,12 $/Go, agents IA ~0,01 $/min. Palier gratuit permanent : 5 000 minutes WebRTC, 50 Go, 1 000 minutes d'agent par mois.

| Scénario mensuel | Minutes participants | Estimation |
|---|---|---|
| Pilote — 20 sessions × 15 étudiants × 90 min | 27 000 | ~14 $ + bande passante |
| Croissance — 100 sessions × 30 × 90 min | 270 000 | ~135 $ + bande passante |
| Consultations — 500 × 30 min × 2 | 30 000 | ~15 $ |
| Agent Scribe sur 30 % des séances | ~30 000 min agent | ~300 $ |

La bande passante domine dès qu'on diffuse en 720p. Le mode `amphi` et l'échelle de dégradation ne sont donc pas seulement des choix de confort : à 0,11 $/Go, passer une séance de 300 étudiants de 720p à 360p divise la facture par trois. **La qualité adaptative est aussi une politique de coût.**

Le palier gratuit couvre entièrement la phase de test.

---

<a name="17"></a>
## 17. Risques

| Risque | Gravité | Parade |
|---|---|---|
| Une cinquième implémentation apparaît dans un module futur | Élevée | `StudioLauncher` comme seul point d'entrée ; revue de code refusant tout appel direct à `livekit-token` |
| La dérive code ↔ base se reproduit | Élevée | Test de cohérence RPC automatisé dès la vague 0 |
| Coût de bande passante non maîtrisé | Moyenne | Mode `amphi` par défaut au-delà de 25, plafond mensuel avec alerte |
| Agent IA trop coûteux | Moyenne | Non activé par défaut, résumé post-séance moins cher en repli |
| Terminaux d'entrée de gamme inutilisables | Élevée | H.264 matériel, dynacast, mode faible débit, tests sur parc réel |
| Adoption enseignante faible | Élevée | Le studio doit être plus simple que Zoom, pas plus riche. Un bouton pour démarrer. |
| Les dettes de sécurité restent ouvertes | Moyenne | La rotation des clés est incluse dans la bascule LiveKit Cloud, donc faite au passage |

---

## Ce qu'il faut retenir

Le studio existe déjà à 60 %. Le code Flutter couvre chat, quiz, tableau blanc, partage d'écran, réactions, présence, live vertical et duo — davantage que Zoom sur deux points. Ce qui manque n'est pas de la fonctionnalité, c'est **une colonne vertébrale** : un point d'entrée unique, une matrice de modes, et un déploiement qui suive.

La proposition tient en une phrase : **arrêter d'écrire des écrans de live, et écrire un service de live que tous les modules appellent.**

Et le premier pas — redéployer une Edge Function oubliée depuis avril — coûte une commande.

# Architecture — AcademiaSession (Entité Unifiée)

## Principe

Un **socle unique** `academia_sessions` remplace progressivement les 3 systèmes séparés :
- `online_course_live_sessions` (cours en ligne)
- `prep_live_sessions` (concours)
- `challenge_game_live_sessions` (gaming)

## Schéma de données

```
academia_sessions (table principale)
├── academia_session_participants (qui est présent)
├── academia_session_presence (événements join/leave pour statistiques)
├── academia_session_messages (chat persisté pour replay)
├── academia_session_quiz_questions (quiz live)
└── academia_session_quiz_answers (réponses élèves)
```

## Types de session (`session_type`)

| Type | Usage |
|------|-------|
| `course` | Live d'un cours en ligne |
| `td` | Session TD interactive |
| `prep_concours` | Révision concours |
| `orientation` | Conférence orientation |
| `conference` | Conférence générale |
| `masterclass` | Masterclass invité |
| `live_pedagogique` | Live pédagogique libre |
| `revision_collective` | Révision collaborative |
| `exam_blanc` | Simulation d'examen |
| `game_challenge` | Défi gaming live |

## Cycle de vie (statuts)

```
draft → scheduled → pending_approval → approved → running → ended
                                    ↘ rejected
                          running → paused → running
                          * → cancelled
```

## RPCs

| RPC | Rôle | Appelé par |
|-----|------|------------|
| `app_learning_upsert_session` | Créer/modifier | Enseignant |
| `app_learning_list_sessions` | Lister (filtres) | Tous |
| `app_learning_list_my_sessions` | Mes sessions | Enseignant |
| `app_learning_list_available_sessions` | Disponibles | Étudiant |
| `app_learning_get_session` | Détail | Tous |
| `app_learning_start_session` | Démarrer | Enseignant (host) |
| `app_learning_end_session` | Terminer | Enseignant (host) |
| `app_learning_join_session` | Rejoindre | Étudiant |
| `app_learning_leave_session` | Quitter | Étudiant |
| `app_learning_get_presence_stats` | Stats présence | Enseignant/Admin |
| `app_admin_learning_update_session_status` | Approuver/Rejeter | Admin |

## Flutter — Architecture

```
models/
  academia_session.dart          ← Modèle + enums + SessionChapter + SessionParticipant

providers/
  academia_session_provider.dart ← Provider unifié (loadSessions, join, leave, start, end)

features/live/
  livekit_room_screen.dart       ← Réutilisé tel quel (salle LiveKit)

services/
  livekit_token_service.dart     ← Token via Edge Function (inchangé)
  livekit_recording_service.dart ← Enregistrement (inchangé)
```

## Rétrocompatibilité

Les anciens systèmes (`online_course_live_sessions`, `prep_live_sessions`) continuent de fonctionner.
Les nouveaux écrans utilisent `AcademiaSession` exclusivement.
Migration progressive : les anciennes sessions restent accessibles via leurs providers existants.

## Phases suivantes

- **Phase 3** : Connecter `AcademiaSessionProvider` au `LivekitRoomScreen` existant
- **Phase 4** : `AcademiaClassroom` — widget wrapper intégrant whiteboard + quiz + chat
- **Phase 5** : Tableau blanc via `perfect_freehand` + sync Supabase Realtime
- **Phase 8** : Présence exploitée via `academia_session_presence` + dashboard stats
- **Phase 9** : Quiz live persisté (tables `quiz_questions` / `quiz_answers`)
- **Phase 11** : Replay avec `chapters` JSONB + lecteur chapitré

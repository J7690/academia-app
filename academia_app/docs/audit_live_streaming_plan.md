# Audit Live Streaming Academia — 20 Mars 2026

## 1. ÉTAT DES LIEUX FLUTTER

### Onglets bloqués dans le dashboard étudiant
| Index | Label | État actuel | Widget actuel |
|-------|-------|-------------|---------------|
| **8** | **Cours** | ❌ `_FeatureComingSoonTab(title: 'Cours')` | Placeholder "en cours de développement" |
| **9** | **Lives** | ❌ `_FeatureComingSoonTab(title: 'Lives')` | Placeholder "en cours de développement" |

### Écrans DÉJÀ CODÉS mais non branchés aux onglets 8/9
| Fichier | Rôle | État | Utilise LiveKit ? |
|---------|------|------|-------------------|
| `StudentCoursesTab` | Bibliothèque cours + catalogue en ligne | ✅ Fonctionnel | Non (pas de live) |
| `StudentLiveSessionsTab` | Liste des sessions live cours en ligne | ✅ Fonctionnel | ✅ Oui |
| `LivekitRoomScreen` | Écran de room LiveKit (vidéo/audio/contrôles) | ✅ Fonctionnel | ✅ Oui |
| `PrepLivesTab` | Sessions live concours (dans Prep, pas dans Lives) | ✅ Fonctionnel | ✅ Oui |
| `OnlineCourseDetailScreen` | Détail cours + section lives | ✅ Fonctionnel | ✅ Oui |

### Providers DÉJÀ CODÉS
| Provider | RPC Supabase | État |
|----------|-------------|------|
| `StudentLiveSessionsProvider` | `app_student_list_my_online_course_live_sessions` | ✅ |
| `OnlineCourseLiveSessionsProvider` | `app_student_list_online_course_live_sessions` | ✅ |
| `InstructorOnlineCourseLiveSessionsProvider` | `app_ci_list_my_online_course_live_sessions` | ✅ |
| `TeacherPrepLiveSessionsProvider` | `app_prep_teacher_*_live_session` | ✅ |
| `AdminLiveSessionsProvider` | `app_admin_list_online_course_live_sessions` | ✅ |

### Services LiveKit DÉJÀ CODÉS
| Service | Fonction | État |
|---------|----------|------|
| `LivekitTokenService` | Appelle Edge Function `livekit-token` → JWT | ✅ |
| `LivekitAdminService` | Kick participant via RPC | ✅ |

### LivekitRoomScreen — Fonctionnalités existantes
- ✅ Connexion WebRTC via token
- ✅ Grille vidéo multi-participants (responsive 1/2/3 colonnes)
- ✅ Toggle micro (on/off)
- ✅ Toggle caméra (on/off)
- ✅ Main levée (SnackBar)
- ✅ Panel participants (side panel desktop, bottom sheet mobile)
- ✅ Bouton "Quitter"
- ❌ Chat texte en temps réel ("bientôt disponible")
- ❌ Partage d'écran
- ❌ Enregistrement/replay
- ❌ Réactions (emojis, applaudissements)
- ❌ Sondages/quiz en direct
- ❌ Tableau blanc partagé
- ❌ Mode présentateur (1 speaker + N viewers)
- ❌ Qualité adaptative (simulcast settings)

## 2. ÉTAT DES LIEUX SUPABASE

### Tables existantes (4)
- `prep_live_sessions` — Sessions live concours
- `prep_live_participants` — Participants sessions concours
- `online_course_live_sessions` — Sessions live cours en ligne
- `online_course_live_session_participants` — Participants cours en ligne

### RPCs existantes (~19)
- Prep: create, list, start, end, join, upsert (teacher + student + admin)
- Online course: list, upsert, submit, start (instructor + student + admin)
- Admin: list, approve, reject, ban user

### Edge Function
- `livekit-token` — ✅ Déployée, corrigée (accepte status running/approved)

### Infrastructure LiveKit
- **Serveur** : 185.220.204.214 (Kamatera Amsterdam, 2 vCPU, 4GB RAM)
- **Status** : ✅ EN LIGNE (HTTP 200)
- **Secrets Supabase** : ✅ Configurés

## 3. BENCHMARK PLATEFORMES LIVE (2026)

### Fonctionnalités clés par plateforme

| Fonctionnalité | Zoom | Google Meet | Teams | Twitch | **Academia (cible)** |
|----------------|------|-------------|-------|--------|---------------------|
| Vidéo/Audio WebRTC | ✅ | ✅ | ✅ | ✅ | ✅ (LiveKit) |
| Chat texte en direct | ✅ | ✅ | ✅ | ✅ | 🔴 À faire |
| Partage d'écran | ✅ | ✅ | ✅ | ✅ | 🔴 À faire |
| Main levée | ✅ | ✅ | ✅ | ❌ | ✅ (basique) |
| Réactions emoji | ✅ | ✅ | ✅ | ✅ | 🔴 À faire |
| Enregistrement | ✅ | ✅ | ✅ | ✅ | 🔴 À faire |
| Replay | ✅ | ✅ | ✅ | ✅ | 🔴 À faire |
| Sondages/Quiz | ✅ | ❌ | ✅ | ❌ | 🔴 À faire |
| Tableau blanc | ✅ | ✅ (Jamboard) | ✅ | ❌ | 🔴 Optionnel |
| Breakout rooms | ✅ | ✅ | ✅ | ❌ | 🟡 Futur |
| Sous-titres auto | ✅ | ✅ | ✅ | ❌ | 🟡 Futur |
| Mode présentateur | ✅ | ✅ | ✅ | ✅ | 🔴 À faire |
| Qualité adaptative | ✅ | ✅ | ✅ | ✅ | 🔴 À faire |
| Live TikTok (1→N) | ❌ | ❌ | ❌ | ✅ | 🔴 À faire |
| Live Duo | ❌ | ❌ | ❌ | ❌ | 🔴 À faire |

### Fonctionnalités SPÉCIFIQUES Academia (non présentes chez Zoom/Meet)
- **Live Challenge TikTok** : 1 streamer → N viewers avec chat/réactions
- **Live Duo** : 2 streamers split-screen → N viewers
- **Quiz en direct** : enseignant pose questions, étudiants répondent en temps réel
- **Intégration Prep Concours** : live de révision avec corrigés interactifs

## 4. PLAN D'IMPLÉMENTATION

### Phase L1 — Débloquer les onglets (1-2h)
- Remplacer `_FeatureComingSoonTab(title: 'Cours')` par `StudentCoursesTab()` (index 8)
- Remplacer `_FeatureComingSoonTab(title: 'Lives')` par `StudentLiveSessionsTab()` (index 9)
- Import des widgets existants
- **Résultat** : Les 2 onglets deviennent fonctionnels immédiatement

### Phase L2 — Chat texte en temps réel (3-4h)
- Utiliser LiveKit Data Channels pour le chat in-room
- Ajouter `_ChatMessage` model + `_ChatPanel` widget dans `livekit_room_screen.dart`
- Envoi via `room.localParticipant.publishData()` (reliable)
- Réception via `room.addListener` → `onDataReceived`
- UI : TextField en bas du side panel + liste de messages avec nom/heure
- Remplacer "Le chat texte sera bientôt disponible" par le vrai chat

### Phase L3 — Partage d'écran (2-3h)
- LiveKit Flutter SDK supporte nativement `localParticipant.setScreenShareEnabled(true)`
- Ajouter bouton partage d'écran dans la barre de contrôles
- Android nécessite un foreground service (déjà configuré pour les notifications)
- Afficher le screen share en grand (track type = screenshare)
- Toggle entre vue galerie et vue speaker quand un écran est partagé

### Phase L4 — Mode présentateur (2h)
- Quand 1 personne publie vidéo + N écoutent : layout "speaker view"
- Speaker occupe 70% de l'écran, miniatures des autres en bande
- Détection automatique du speaker actif via `activeSpeakers` de LiveKit
- L'hôte peut "mettre en avant" un participant

### Phase L5 — Réactions et main levée améliorée (2h)
- Réactions emoji via Data Channel (applaudissements, pouce, cœur, rire)
- Bulles d'emoji animées qui montent à l'écran (style TikTok live)
- Main levée persistante : badge visible sur la miniature du participant
- L'hôte voit la liste des mains levées et peut donner la parole (unmute)

### Phase L6 — Enregistrement et Replay (3-4h)
- LiveKit Egress : décommenter le service Docker Compose sur le VPS
- Configurer egress.yaml pour enregistrer en MP4 vers Supabase Storage
- Ajouter RPC `app_save_live_recording(session_id, recording_url)`
- Stocker l'URL du replay dans `replay_url` / `replay_video_url`
- L'étudiant voit "Voir le replay" après la session terminée

### Phase L7 — Live Challenge TikTok (4-5h)
- Nouveau widget `ChallengeLiveScreen` dans l'onglet Challenge
- Bouton "Go Live" dans la barre TikTok du feed
- 1 streamer publie vidéo + audio, N viewers reçoivent
- Chat vertical style TikTok (messages qui défilent par-dessus la vidéo)
- Réactions emoji qui montent (overlay animé)
- Compteur de viewers en temps réel
- LiveKit room : 1 publisher + N subscribers

### Phase L8 — Live Duo (3-4h)
- 2 publishers dans une room LiveKit (split-screen)
- Invitation : streamer A invite streamer B via Data Channel
- Layout : 2 vidéos côte à côte (portrait) ou haut/bas
- Chat et réactions partagés
- Combiné avec le feed Challenge

### Phase L9 — Quiz/Sondage en direct (3-4h)
- Enseignant crée un quiz via l'écran existant (prep_quiz_templates)
- Pendant le live, bouton "Lancer le quiz" → envoi via Data Channel
- Côté étudiant : overlay modal avec question + choix
- Réponses collectées via Data Channel → stats en temps réel
- Affichage résultats en direct (graphique barres)

### Phase L10 — Qualité adaptative + Polish (2-3h)
- Activer simulcast dans LiveKit config (3 couches : 720p, 360p, 180p)
- LiveKit gère automatiquement la qualité selon la bande passante
- Ajouter indicateur de qualité réseau dans l'UI
- Détection connexion faible → basculer en audio-only automatiquement

## 5. PRIORITÉS

### MVP (Phases L1-L3) — Immédiat (~8h)
Débloquer les onglets + chat texte + partage écran
→ **L'app a des lives fonctionnels comparable à Google Meet basique**

### V1 (Phases L4-L6) — Semaine 1 (~8h)
Mode présentateur + réactions + enregistrement
→ **Expérience comparable à Zoom pour l'éducation**

### V2 (Phases L7-L8) — Semaine 2 (~8h)
Live Challenge TikTok + Duo
→ **Fonctionnalités uniques qu'aucune plateforme concurrente n'offre**

### V3 (Phase L9-L10) — Semaine 3 (~6h)
Quiz live + qualité adaptative
→ **Expérience éducative interactive de pointe**

## 6. FICHIERS À MODIFIER/CRÉER

### Phase L1 (déblocage)
- `student_dashboard_screen.dart` : case 8 → StudentCoursesTab, case 9 → StudentLiveSessionsTab

### Phase L2 (chat)
- `livekit_room_screen.dart` : ajouter chat panel avec Data Channels

### Phase L3 (screen share)
- `livekit_room_screen.dart` : bouton + layout screen share

### Phase L7 (live TikTok)
- NOUVEAU : `lib/features/student/challenge_live_screen.dart`
- MODIFIER : `student_challenges_tab.dart` → bouton "Go Live"

### Phase L8 (duo)
- NOUVEAU : `lib/features/student/challenge_live_duo_screen.dart`

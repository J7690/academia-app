# AUDIT COMPLET — Academia Learning Engine
## Phase 1 — État des lieux au 7 Juin 2026

---

## 1. ARCHITECTURE FLUTTER (`academia_app/lib/`)

### 1.1 Écrans Cours (Online Courses)
| Fichier | Rôle |
|---------|------|
| `features/student/tabs/student_courses_tab.dart` | Bibliothèque cours + ressources (onglet 8 dashboard) |
| `features/student/tabs/student_online_trainings_tab.dart` | Formations en ligne catalog + mes cours |
| `features/student/online_course_detail_screen.dart` | Détail cours (modules, leçons, lives, forum, QA) |
| `features/student/course_resource_viewer_screen.dart` | Viewer PDF/vidéo ressource |
| `features/instructor/instructor_dashboard_screen.dart` | Onglet "Cours" (tab 8) + "Sessions" (tab 9) |

### 1.2 Écrans TD (Travaux Dirigés)
| Fichier | Rôle |
|---------|------|
| `features/student/student_td_root_screen.dart` | Root TD étudiant (9 onglets) |
| `features/student/td/td_home_tab.dart` | Accueil TD |
| `features/student/td/td_catalog_tab.dart` | Catalogue TD |
| `features/student/td/td_my_enrollments_tab.dart` | Mes inscriptions TD |
| `features/student/td/td_resources_tab.dart` | Ressources TD |
| `features/student/td/td_leaderboard_tab.dart` | Classement TD |
| `features/student/td/td_stats_tab.dart` | Statistiques TD |
| `features/student/td/td_ai_tutor_tab.dart` | IA Tuteur TD |
| `features/student/td/td_local_groups_tab.dart` | Groupes locaux |
| `features/student/td/td_exercises_tab.dart` | Exercices TD |
| `features/student/td/td_quiz_tab.dart` | Quiz TD |
| `features/student/td/td_scan_subject_screen.dart` | Scanner sujet (OCR + IA) |
| `features/instructor/teacher_td_assignments_screen.dart` | Enseignant → Mes TD |
| `features/instructor/teacher_td_exercises_screen.dart` | Enseignant → Exercices TD |
| `features/instructor/teacher_td_local_groups_screen.dart` | Enseignant → Groupes locaux |
| `features/instructor/teacher_td_resources_screen.dart` | Enseignant → Ressources |

### 1.3 Écrans Live (Sessions en direct)
| Fichier | Rôle |
|---------|------|
| `features/live/livekit_room_screen.dart` | **Salle LiveKit complète** (1330 lignes) — vidéo grid, chat, reactions, quiz, enregistrement, screen share, hand raise |
| `features/student/tabs/student_live_sessions_tab.dart` | Liste sessions live étudiant (onglet 9) |
| `features/student/challenge_live_screen.dart` | Live challenge (feed TikTok) |
| `features/student/challenge_live_duo_screen.dart` | Live duo challenge |
| `features/instructor/teacher_prep_live_sessions_screen.dart` | Enseignant → Lives concours |
| `widgets/live_quiz_overlay.dart` | **Quiz overlay en live** (QCM, resultats temps réel via Data Channel) |

### 1.4 Écrans Orientation (Candidatures + Universités)
| Fichier | Rôle |
|---------|------|
| `features/student/tabs/student_applications_tab.dart` | Onglet candidatures |
| `features/student/student_application_detail_screen.dart` | Détail candidature |
| `features/student/tabs/student_partners_tab.dart` | Universités partenaires |
| `features/student/student_university_site_screen.dart` | Mini-site université |

### 1.5 Écrans Préparation Concours
| Fichier | Rôle |
|---------|------|
| `features/student/student_prep_concours_screen.dart` | Root concours (7 onglets) |
| `features/student/prep/prep_home_tab.dart` | Accueil concours |
| `features/student/prep/prep_quiz_tab.dart` | Quiz concours |
| `features/student/prep/prep_exercises_tab.dart` | Exercices concours |
| `features/student/prep/prep_lives_tab.dart` | Lives concours |
| `features/student/prep/prep_ai_tab.dart` | IA Tuteur concours |
| `features/student/prep/prep_subjects_tab.dart` | Sujets blancs |
| `features/student/prep/prep_stats_tab.dart` | Statistiques |
| `features/student/prep/prep_scan_subject_screen.dart` | Scanner sujet concours |
| `features/student/prep/prep_progress_dashboard.dart` | Dashboard progression |
| `features/student/prep_concours/prep_exam_screen.dart` | Écran examen |
| `features/student/prep_concours/prep_training_screen.dart` | Entrainement |
| `features/student/prep_concours/prep_sujet_blanc_exam_screen.dart` | Sujet blanc |
| `features/student/prep_concours/prep_diagnostic_screen.dart` | Diagnostic |
| `features/instructor/teacher_prep_screen.dart` | Enseignant → Prépa |
| `features/instructor/teacher_prep_assignments_screen.dart` | Enseignant → Exercices concours |
| `features/instructor/teacher_prep_live_sessions_screen.dart` | Enseignant → Lives concours |

---

## 2. SERVICES EXISTANTS

### 2.1 Services LiveKit (temps réel)
| Fichier | Rôle |
|---------|------|
| `services/livekit_token_service.dart` | Obtient JWT via Edge Function `livekit-token` |
| `services/livekit_admin_service.dart` | Kick participant via RPC admin |
| `services/livekit_recording_service.dart` | Start/Stop enregistrement (Egress) via Edge Function `livekit-recording` |

### 2.2 Services Vidéo
| Fichier | Rôle |
|---------|------|
| `services/videoasset_upload_service.dart` | Ingest + upload vers Supabase Storage |
| `services/video_cache_service.dart` | Cache vidéo local |
| `services/video_preload_service.dart` | Préchargement |
| `services/video_analytics_service.dart` | Analytics vidéo |
| `services/video_reaction_service.dart` | Réactions vidéo |
| `services/video_share_service.dart` | Partage vidéo |
| `services/video_segment_merge_service.dart` | Fusion segments |
| `services/adaptive_quality_service.dart` | Qualité adaptative |
| `services/hero_render_service.dart` | Rendu hero vidéo |
| `services/hero_video_encoder_service.dart` | Encodage hero |
| `services/studio_video_service.dart` | Service studio vidéo |
| `services/studio_audio_service.dart` | Audio studio |
| `services/studio_ai_service.dart` | IA studio |
| `video/academia_playback_engine.dart` | Moteur de lecture |
| `video/academia_playback_view.dart` | Vue lecture native Android |
| `video/audio_mix_service.dart` | Mix audio |
| `video/overlay_burn_in_service.dart` | Burn overlays |

### 2.3 Services IA / Pédagogiques
| Fichier | Rôle |
|---------|------|
| `services/prep_ai_service.dart` | Service IA concours |
| `services/prep_concours_questions_service.dart` | Questions depuis JSON local |
| `services/td_service.dart` | Service TD (37KB, gros service) |

### 2.4 Autres services
| Fichier | Rôle |
|---------|------|
| `services/push_notification_service.dart` | FCM push |
| `services/push_trigger_service.dart` | Trigger push depuis dashboards |
| `services/analytics_tracking_service.dart` | Tracking navigation |
| `services/ligdicash_service.dart` | Paiement LigdiCash |
| `services/deep_link_service.dart` | Deep links |
| `services/chunked_upload_service.dart` | Upload chunked |

---

## 3. PROVIDERS (114 fichiers)

### Clés pour le Learning Engine :
| Provider | RPC(s) utilisées |
|----------|------------------|
| `student_live_sessions_provider.dart` | `app_student_list_my_online_course_live_sessions` |
| `instructor_online_course_live_sessions_provider.dart` | `app_ci_list_my_online_course_live_sessions`, `app_ci_upsert_online_course_live_session`, `app_ci_submit_*`, `app_ci_start_*` |
| `online_course_live_sessions_provider.dart` | `app_student_list_online_course_live_sessions` |
| `teacher_prep_live_sessions_provider.dart` | `app_prep_teacher_*` |
| `admin_live_sessions_provider.dart` | `app_admin_*_live_session*` |
| `student_online_courses_provider.dart` | `app_student_*_online_course*` |
| `instructor_online_courses_provider.dart` | `app_ci_*_online_course*` |
| `online_courses_catalog_provider.dart` | `app_student_list_public_online_courses` |
| `online_course_detail_provider.dart` | `app_student_get_online_course_detail` |
| `online_course_forum_provider.dart` | `app_student_*_online_course_forum*` |
| `prep_quiz_provider.dart` | `app_prep_get_quiz_questions`, etc. |
| `prep_flashcard_provider.dart` | Flashcards concours |
| `prep_weakness_provider.dart` | Apprentissage adaptatif |
| `prep_concours_provider.dart` | Provider principal concours |
| `td_gamification_provider.dart` | Gamification TD |
| `student_td_catalog_provider.dart` | Catalogue TD |
| `credit_provider.dart` | Crédits IA |
| `subscription_provider.dart` | Abonnements premium |

---

## 4. MODÈLES
| Fichier | Rôle |
|---------|------|
| `models/timed_overlay.dart` | Overlays vidéo chronométrés |

> **Note** : Pas de dossier models structuré. Les données sont manipulées comme `Map<String, dynamic>` partout.

---

## 5. SUPABASE — TABLES LIVE SESSIONS (schema `app`)

### 5.1 Tables existantes (d'après les RPCs et mémoires)
| Table | Usage |
|-------|-------|
| `online_course_live_sessions` | Sessions live des cours en ligne |
| `online_course_live_session_participants` | Participants aux lives cours |
| `prep_live_sessions` | Sessions live concours |
| `prep_live_participants` | Participants lives concours |
| `challenge_game_live_sessions` | Lives gaming (prévu, Phase 2) |

### 5.2 Tables cours en ligne
| Table | Usage |
|-------|-------|
| `online_courses` | Cours en ligne |
| `online_course_modules` | Modules |
| `online_course_lessons` | Leçons |
| `online_course_resources` | Ressources |
| `online_course_enrollments` | Inscriptions |
| `online_course_forum_posts` | Forum |

### 5.3 Tables TD (39 tables `td_*`)
- `td_programs`, `td_collections`, `td_sessions`, `td_question_banks`, `td_questions`
- `td_enrollments`, `td_student_profiles`, `td_teacher_profiles`
- `td_local_groups`, `td_local_group_members`, `td_physical_sessions`
- `td_assignments`, `td_assignment_submissions`
- `td_source_documents`, `td_doc_chunks`
- (+ 24 autres)

### 5.4 Tables Prépa Concours (24+ tables `prep_*`)
- `prep_questions`, `prep_question_banks`, `prep_flashcard_decks`, `prep_flashcards`
- `prep_quiz_attempts`, `prep_student_progress`, `prep_student_weaknesses`
- `prep_live_sessions`, `prep_live_participants`
- `prep_assignments`, `prep_assignment_submissions`
- `prep_source_documents`, `prep_doc_chunks`, `prep_topic_predictions`
- `prep_ai_conversations`, `prep_ai_messages`, `prep_ai_config`

---

## 6. SUPABASE — EDGE FUNCTIONS (38 fonctions)

### Pédagogiques (IA + Temps réel)
| Function | Rôle |
|----------|------|
| `livekit-token` | Génère JWT LiveKit (HMAC-SHA256) |
| `livekit-recording` | Start/Stop Egress (enregistrement) |
| `prep-tutor-chat` | Tuteur IA concours (RAG + cascade modèles) |
| `prep-generate-questions` | Génère QCM via IA |
| `prep-grade-assignment` | Correction IA exercices |
| `prep-scan-subject` | OCR + résolution (Gemini Vision) |
| `prep-ingest-document` | PDF → chunks → embeddings |
| `prep-analyze-trends` | Analyse récurrence → prédictions |
| `prep-compose-exam-blanc` | Composition exam blanc par IA |
| `prep-embed-chunks` | Embedding chunks (pgvector) |
| `prep-feed-actuality` | Feed actualités concours |
| `td-tutor-chat` | Tuteur IA TD |
| `td-generate-exercises` | Génère exercices TD |
| `td-scan-subject` | OCR + correction TD |
| `td-ingest-document` | Ingestion documents TD |
| `bobodo-chat` | Assistant Bobodo |
| `transcode-video` | Transcodage vidéo |
| `transcode-multi-resolution` | Multi-résolution |
| `merge-video-segments` | Fusion segments |
| `assemble-video-chunks` | Assemblage chunks |
| `send-push-notifications` | Envoi push FCM |

### Paiement & Admin
| Function | Rôle |
|----------|------|
| `ligdicash-initiate` | Paiement OTP étape 1 |
| `ligdicash-confirm` | Paiement OTP étape 2 |
| `ligdicash-callback` | Webhook callback |
| `ligdicash-payout` | Versements |
| `admin-create-*-account` (×5) | Création comptes par rôle |
| `admin-hard-delete-user-account` | Suppression définitive |
| `admin-promote-user-role` | Promotion rôle |

---

## 7. INFRASTRUCTURE KAMATERA (Serveur LiveKit)

| Composant | Détail |
|-----------|--------|
| **IP** | 185.167.97.144 |
| **OS** | Ubuntu Server 24.04 64-bit |
| **Specs** | 4 vCPU, 10GB RAM, 30GB SSD |
| **Docker** | docker-ce latest |
| **LiveKit** | livekit/livekit-server:latest, port 7880 |
| **Redis** | 7.0.15 (localhost:6379) |
| **Nginx** | 1.24.0 (reverse proxy, port 80) |
| **Certbot** | Installé (HTTPS prêt) |
| **UFW** | 22, 80, 443, 7880, 7881, 50000-60000/udp |
| **API Key** | APIKeylrmgQYJgiEZa |
| **API Secret** | uXu7tiObNgaLkYA3VydinjsKRzPJjL8SNWC9pRx8 |
| **WebSocket** | ws://185.167.97.144:7880 |

### Manquant sur Kamatera :
- ❌ Prometheus / Grafana / Loki (observabilité)
- ❌ Alertmanager
- ❌ Fail2Ban
- ❌ HTTPS/TLS (Certbot installé mais pas configuré)
- ❌ FFmpeg workers
- ❌ Domaine DNS

---

## 8. PACKAGES FLUTTER PERTINENTS (déjà installés)

| Package | Version | Usage |
|---------|---------|-------|
| `livekit_client` | ^2.6.0 | Client LiveKit (vidéo/audio/data channel) |
| `supabase_flutter` | 2.10.3 | Backend Supabase |
| `provider` | ^6.1.1 | State management |
| `go_router` | ^12.1.3 | Navigation (peu utilisé, Navigator.push dominant) |
| `fl_chart` | ^0.69.2 | Graphiques stats |
| `camera` | ^0.11.0 | Capture vidéo |
| `flame` | ^1.35.1 | Jeux gamifiés |
| `flutter_math_fork` | ^0.7.2 | Rendu LaTeX |
| `math_keyboard` | ^0.3.0 | Saisie maths |
| `gpt_markdown` | ^1.1.5 | Rendu markdown+LaTeX |
| `video_player` | ^2.10.1 | Lecture vidéo |
| `record` | ^6.1.2 | Enregistrement audio |
| `web_socket_channel` | ^2.4.0 | WebSocket |
| `perfect_freehand` | ^2.0.0 | Dessin main levée |

---

## 9. DASHBOARD ÉTUDIANT — Navigation (10 onglets)

| Index | Écran | Widget |
|-------|-------|--------|
| 0 | Accueil | `StudentHomeMobileTab` |
| 1 | Candidatures | `StudentApplicationsTab` |
| 2 | Opportunités | `StudentOpportunitiesTab` |
| 3 | Communautés | `StudentCommunitiesTab` |
| 4 | Universités | `StudentPartnersTab` |
| 5 | Concours | `StudentPrepConcoursScreen` (+ PaywallOverlay) |
| 6 | TD | `StudentTdRootScreen` |
| 7 | Challenges | `StudentChallengesTab` (feed TikTok) |
| 8 | Cours | `StudentCoursesTab` |
| 9 | Lives | `StudentLiveSessionsTab` |

---

## 10. DASHBOARD ENSEIGNANT — 11 onglets

| Index | Tab | Widget |
|-------|-----|--------|
| 0 | Accueil | `_InstructorHomeTab` |
| 1 | Mes TD | `TeacherTdAssignmentsScreen` |
| 2 | Progression | `TeacherTdResourcesScreen` |
| 3 | Groupes | `TeacherTdLocalGroupsScreen` |
| 4 | Exo TD | `TeacherTdExercisesScreen` |
| 5 | Prépa | `TeacherPrepScreen` |
| 6 | Exercices | `TeacherPrepAssignmentsScreen` |
| 7 | Lives | `TeacherPrepLiveSessionsScreen` |
| 8 | Cours | `_InstructorCoursesTab` |
| 9 | Sessions | `_InstructorLiveSessionsTab` |
| 10 | Revenus | `InstructorRevenueTab` |

---

## 11. COMPOSANTS RÉUTILISABLES IDENTIFIÉS

### Widgets clés pour le Learning Engine :
| Widget | Fichier | Réutilisabilité |
|--------|---------|-----------------|
| `LivekitRoomScreen` | `features/live/` | ✅ Salle temps réel complète (vidéo, chat, quiz, reactions, record) |
| `LiveQuizOverlay` | `widgets/` | ✅ Quiz temps réel via Data Channel |
| `AcademiaRichContent` | `widgets/` | ✅ Rendu texte+LaTeX+Markdown |
| `AcademiaMathInput` | `widgets/` | ✅ Saisie formules |
| `PaywallOverlay` | `widgets/` | ✅ Paywall abonnement |
| `CreditBalanceChip` | `widgets/` | ✅ Solde crédits IA |
| `ReportContentSheet` | `widgets/` | ✅ Signalement contenu |
| `UserAvatar` | `widgets/` | ✅ Avatar avec indicateur online |
| `MentionTextField` | `widgets/` | ✅ Champ texte avec mentions |
| `TdTheme` | `theme/` | ✅ Design system rôles (instructeur/admin/étudiant) |

### Services réutilisables :
| Service | Réutilisabilité |
|---------|-----------------|
| `LivekitTokenService` | ✅ Obtention token pour n'importe quel type de session |
| `LivekitRecordingService` | ✅ Enregistrement pour replay |
| `AnalyticsTrackingService` | ✅ Tracking navigation |
| `PushNotificationService` | ✅ Notifications push |
| `VideoassetUploadService` | ✅ Pipeline vidéo unifié |

---

## 12. CONSTATS & RECOMMANDATIONS POUR L'ARCHITECTURE CIBLE

### Points forts existants :
1. **LiveKit fonctionnel** — Salle complète avec chat, quiz, reactions, enregistrement, screen share
2. **Système de crédits IA** — Reserve/Confirm/Refund pattern
3. **6 Edge Functions IA** — Cascade multi-modèles (free→paid)
4. **Quiz temps réel** — Via Data Channel LiveKit (déjà implémenté)
5. **Enregistrement** — Egress LiveKit via Edge Function
6. **Infrastructure serveur** — Kamatera opérationnel

### Fragmentation à unifier :
1. **3 systèmes de lives séparés** : `online_course_live_sessions`, `prep_live_sessions`, `challenge_game_live_sessions`
2. **Pas de modèle Session unifié** — chaque module a ses propres tables/RPCs
3. **Pas de tableau blanc** — seulement `perfect_freehand` dans le studio vidéo
4. **Pas de suivi de présence** — entrée/sortie non trackés
5. **Pas de replay intelligent** — enregistrement existe mais pas de chapitrage
6. **Navigation fragmentée** — `Navigator.push` partout, pas de routing centralisé

### Ce qui peut être réutilisé tel quel :
- `LivekitRoomScreen` → base pour `AcademiaClassroom`
- `LiveQuizOverlay` → base pour Quiz Live (Phase 9)
- `LivekitTokenService` + Edge Function → infrastructure temps réel
- `LivekitRecordingService` → base pour Replay (Phase 11)
- `perfect_freehand` → base pour tableau blanc (Phase 5)
- `TdTheme` → extensible pour le design system unifié
- `livekit_client: ^2.6.0` → screen share déjà supporté (Phase 6)

---

## 13. RÉSUMÉ CHIFFRÉ

| Métrique | Valeur |
|----------|--------|
| **Fichiers Dart** | ~320+ |
| **Providers** | 114 |
| **Services** | 31 |
| **Écrans features** | ~195 |
| **Edge Functions** | 38 |
| **Tables Supabase** | ~178 (schema app) |
| **Tables live** | 5 (3 types séparés) |
| **Tables cours** | ~10 |
| **Tables TD** | ~39 |
| **Tables prep** | ~24+ |
| **Dashboard étudiant** | 10 onglets |
| **Dashboard enseignant** | 11 onglets |
| **Dashboard admin** | 26-27 onglets |
| **Packages pubspec** | ~55 |

---

## FIN AUDIT — PRÊT POUR PHASE 2 (Architecture AcademiaSession)

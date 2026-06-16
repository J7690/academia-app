# AUDIT COMPLET — Module TD (Travaux Dirigés) Étudiant
**Date** : 6 Avril 2026
**Scope** : Supabase (tables, RPCs, Edge Functions) + Flutter (écrans, providers, navigation)
**Objectif** : Comprendre l'architecture existante et planifier les nouvelles fonctionnalités

---

## 1. ARCHITECTURE SUPABASE

### 1.1 Tables TD (schema `app`)

| Table | Rôle | Colonnes clés |
|-------|------|---------------|
| `td_question_banks` | Banques de questions (enseignant/admin) | id, title, description, concours_type, subject |
| `td_questions` | Questions QCM universitaires | id, bank_id, question_type, content, options (jsonb), correct_index, explanation, difficulty, subject, is_active |
| `td_source_documents` | Documents PDF/texte importés | id, subject, university, study_year, storage_bucket, storage_path, extracted_text, status, page_count |
| `td_doc_chunks` | Chunks vectorisés pour RAG | id, source_document_id, chunk_index, content, metadata, embedding (vector), chunk_type, subject, university, study_year, token_count |
| `td_ai_config` | Configuration IA tuteur | config_key, config_value (ex: system_prompt) |
| `td_ai_conversations` | Conversations IA tuteur | id, student_id, subject, created_at |
| `td_ai_messages` | Messages IA tuteur | id, conversation_id, role, content, tokens_used, created_at |
| `td_scan_logs` | Logs des scans OCR | id, student_id, extracted_text, solutions, field_name, level, created_at |
| `td_programs` | Programmes TD (créés par admin) | id, title, description, field_id, level, modality, price, currency, is_published |
| `td_enrollments` | Inscriptions étudiants | id, student_id, program_id, access_scope, access_status, progress_pct |
| `td_payments` | Paiements TD | id, enrollment_id, amount_due, amount_paid, status |
| `td_sessions` | Séances TD planifiées | id, program_id, title |
| `td_session_occurrences` | Occurrences de séances | id, session_id, enrollment_id, teacher_id, scheduled_at, duration_minutes, status, location, meeting_url |
| `td_attendance` | Présences aux séances | id, occurrence_id, student_id, status, comment |
| `td_resources` | Ressources pédagogiques | id, enrollment_id, title, type, url |
| `td_messages` | Messages enseignant↔étudiant | id, enrollment_id, thread_type, sender_id, content, attachment_url |
| `td_student_requests` | Demandes TD des étudiants | id, student_id, field_id, level, subject, description, preferred_modality, preferred_schedule, status |
| `td_assignments` | Exercices/devoirs envoyés par enseignants | id, enrollment_id, title, description, subject, assignment_type, max_score, deadline |
| `td_submissions` | Soumissions étudiants aux exercices | id, assignment_id, student_id, answer_content (jsonb), status, ai_score, teacher_score |
| `td_badges` | Badges gamification | id, code, title, description, emoji, xp_reward, condition_type, condition_value |
| `td_student_badges` | Badges obtenus | id, student_id, badge_id, earned_at |
| `td_local_groups` | Groupes locaux d'étude | id, title, field_id, level, city, location, max_members |
| `td_local_group_members` | Membres des groupes | id, group_id, student_id, role |

### 1.2 RPCs Supabase TD

#### RPCs Étudiant (schema `public` ou `app`)
| RPC | Paramètres | Rôle |
|-----|-----------|------|
| `app_td_student_list_subjects` | — | Liste les matières avec compteur de questions |
| `app_td_student_get_quiz_questions` | p_subject, p_count | Récupère N questions QCM pour un quiz |
| `app_td_student_list_exercises` | — | Liste les exercices/devoirs assignés à l'étudiant |
| `app_td_student_submit_exercise` | p_assignment_id, p_answer_content | Soumet une réponse à un exercice |
| `app_td_student_create_request` | p_field_id, p_level, p_subject, p_description, p_preferred_modality, p_preferred_schedule | Demande un TD personnalisé |
| `app_td_student_list_my_requests` | — | Liste les demandes de l'étudiant |
| `app_td_student_get_dashboard` | — | Dashboard (inscriptions, prochaines séances, messages non lus) |
| `app_td_student_list_my_enrollments` | — | Liste les inscriptions TD actives |
| `app_td_student_list_my_session_occurrences` | — | Prochaines séances |
| `app_td_student_list_resources_for_enrollment` | p_enrollment_id | Ressources pour une inscription |
| `app_td_list_public_programs` | p_field_id, p_level | Catalogue des programmes TD publics |
| `app_td_get_program_detail` | p_program_id | Détail d'un programme |
| `app_td_student_create_enrollment_and_payment` | p_program_id, p_collection_id, p_access_scope, p_amount_due, p_student_notes | S'inscrire + payer |
| `app_td_list_messages_for_enrollment` | p_enrollment_id | Messages pour une inscription |
| `app_td_send_message` | p_enrollment_id, p_thread_type, p_content, p_attachment_url | Envoyer un message |
| `app_td_semantic_search` | p_query_embedding, p_subject, p_university, p_limit, p_threshold | Recherche sémantique dans td_doc_chunks |

#### RPCs Enseignant
| RPC | Rôle |
|-----|------|
| `app_td_teacher_list_assignments` | Exercices assignés |
| `app_td_teacher_get_dashboard` | Dashboard enseignant |
| `app_td_teacher_list_upcoming_sessions` | Prochaines séances |
| `app_td_teacher_update_attendance` | Marquer la présence |
| `app_td_teacher_list_resources_for_enrollment` | Ressources |

#### RPCs Admin
| RPC | Rôle |
|-----|------|
| `app_td_admin_get_dashboard` | Dashboard admin |
| `app_td_admin_assign_teacher` | Assigner un enseignant |
| `app_td_admin_list_enrollments_with_context` | Toutes les inscriptions |
| `app_td_admin_upsert_session_occurrence` | Créer/modifier une séance |
| `app_td_admin_cancel_session_occurrence` | Annuler une séance |
| `app_td_admin_list_session_occurrences` | Lister les séances |
| `app_td_admin_list_student_requests` | Demandes étudiants |
| `app_td_admin_mark_request_converted` | Marquer une demande comme convertie |

### 1.3 Edge Functions TD

| Fonction | Rôle | Tables utilisées |
|----------|------|-----------------|
| `td-generate-exercises` | Génère des QCM/exercices via LLM + RAG (embeddings td_doc_chunks) | td_questions, td_doc_chunks |
| `td-ingest-document` | Extrait texte PDF → chunks → embeddings | td_source_documents, td_doc_chunks |
| `td-scan-subject` | OCR d'un exercice + résolution IA | td_scan_logs |
| `td-tutor-chat` | Chat IA tuteur (méthode socratique) + RAG | td_ai_config, td_ai_messages, td_doc_chunks |

---

## 2. ARCHITECTURE FLUTTER

### 2.1 Écran principal : `StudentTdRootScreen`
- **10 onglets** avec TabBar scrollable
- Fichier : `student_td_root_screen.dart`

| Index | Onglet | Widget | Rôle |
|-------|--------|--------|------|
| 0 | Accueil | `TdHomeTab` | Dashboard gamifié (XP, streak, inscriptions actives, prochaine séance) |
| 1 | Quiz | `TdQuizTab` | Quiz QCM par matière (td_questions) + bouton scanner |
| 2 | Catalogue | `TdCatalogTab` | Explorer les programmes TD + demander un TD personnalisé |
| 3 | Mes TD | `TdMyEnrollmentsTab` | Inscriptions actives avec progression |
| 4 | Ressources | `TdResourcesTab` | Ressources pédagogiques par inscription |
| 5 | Classement | `TdLeaderboardTab` | Leaderboard XP |
| 6 | Stats | `TdStatsTab` | Statistiques personnelles |
| 7 | IA Tuteur | `TdAiTutorTab` | Chat IA (td-tutor-chat) |
| 8 | Groupes | `TdLocalGroupsTab` | Groupes d'étude locaux |
| 9 | Exercices | `TdExercisesTab` | Exercices assignés par enseignants |

### 2.2 Providers
| Provider | Rôle |
|----------|------|
| `TdGamificationProvider` | XP, streaks, badges, enrollments, dashboard, catalogue |
| `StudentTdCatalogProvider` | Programmes TD, détails, filtres |
| `StudentTdEnrollmentsProvider` | Inscriptions, prochaines séances |
| `StudentTdRequestsProvider` | Demandes TD personnalisées |
| `TdMessagesProvider` | Messages enseignant↔étudiant |

### 2.3 Service centralisé : `TdService`
- Fichier : `lib/services/td_service.dart`
- Encapsule tous les appels RPC `app_td_*`
- Contient aussi les méthodes Prep Concours (mixte)

### 2.4 Écrans complémentaires
| Écran | Rôle |
|-------|------|
| `TdScanSubjectScreen` | Scanner OCR + résolution IA d'un exercice |

---

## 3. ANALYSE DES FONCTIONNALITÉS EXISTANTES vs DEMANDÉES

### 3.1 ✅ Ce qui EXISTE déjà
1. **Quiz QCM par matière** (onglet Quiz) — fonctionne via `app_td_student_get_quiz_questions`
2. **Scanner un exercice** (OCR + correction IA) — `td-scan-subject`
3. **Exercices assignés par enseignant** (onglet Exercices) — `app_td_student_list_exercises`
4. **Soumission de réponses** — `app_td_student_submit_exercise`
5. **Demander un TD personnalisé** (dans le Catalogue) — `app_td_student_create_request`
6. **Chat IA tuteur** (onglet IA Tuteur) — `td-tutor-chat`
7. **Génération d'exercices via IA** (Edge Function) — `td-generate-exercises`
8. **Catalogue de programmes** — `app_td_list_public_programs`
9. **Gamification** (XP, streaks, badges, leaderboard)

### 3.2 ❌ Ce qui MANQUE (demandes utilisateur)

#### A. Bouton "Demander un enseignant humain" pour sa matière
- **État actuel** : L'étudiant peut demander un TD via le catalogue (`app_td_student_create_request`), mais c'est enfoui dans le catalogue. Il n'y a pas de bouton direct visible pour demander un enseignant humain.
- **Ce qu'il faut** : Un bouton proéminent (ex: dans l'Accueil ou le Quiz) permettant à l'étudiant de formuler une demande d'enseignant humain en précisant la matière, le niveau, la filière, le semestre.

#### B. Devoirs type pré-générés + génération à la demande
- **État actuel** : 
  - Les exercices (onglet Exercices) sont uniquement ceux assignés par un enseignant humain.
  - Le quiz (onglet Quiz) est du QCM pur depuis `td_questions`.
  - L'Edge Function `td-generate-exercises` existe mais n'est **PAS appelée depuis le Flutter étudiant**. Elle supporte les modes `exercise`, `td_session`, `exam`.
- **Ce qu'il faut** :
  - Afficher des **devoirs type déjà générés** filtrés par filière/année/semestre.
  - Un **bouton "Générer un devoir type"** qui appelle `td-generate-exercises` en mode `exam` avec les paramètres : matière, filière, année, semestre, nombre de points, temps imparti.
  - Afficher les devoirs avec : titre, matière, nombre de questions, points, temps estimé.

#### C. Exercices pré-générés + génération à la demande
- **État actuel** : Identique au point B — `td-generate-exercises` existe en backend mais n'est pas accessible depuis le Flutter étudiant en mode libre.
- **Ce qu'il faut** :
  - Dans l'onglet Exercices ou Quiz : afficher des exercices déjà générés (filtrés par filière/année/semestre).
  - Un **bouton "Générer des exercices"** qui appelle `td-generate-exercises` en mode `exercise`.

---

## 4. PLAN D'IMPLÉMENTATION

### Phase 1 : Bouton "Demander un enseignant humain"
- Ajouter un **bouton visible** dans `TdHomeTab` (Accueil) sous les actions rapides.
- Réutiliser `app_td_student_create_request` avec des champs filière, matière, niveau, semestre.
- Formulaire : matière (dropdown), filière (text), année (L1-M2), semestre (S1-S2), description libre, modalité préférée (présentiel/en ligne), créneaux.

### Phase 2 : Refonte onglet Exercices (devoirs type + exercices générés)
- **Scinder l'onglet Exercices en 2 sections** :
  1. "Exercices enseignant" (existants — `app_td_student_list_exercises`)
  2. "Exercices & Devoirs IA" (nouveaux — depuis `td_questions` filtrés + bouton générer)
- Ou bien **créer un nouvel onglet "Devoirs"** dédié.

### Phase 3 : Intégration de `td-generate-exercises` côté Flutter
- Appel HTTP vers l'Edge Function avec paramètres : subject, study_year, count, mode (exercise/exam), university.
- Afficher les résultats générés avec : question, options, correction, difficulté.
- Stocker dans `td_questions` pour réutilisation.

### Phase 4 : Filtres filière/année/semestre
- Ajouter des filtres dans le Quiz et les Exercices pour affiner par filière et année.
- Les `td_questions` ont déjà un champ `subject` mais manquent `study_year`, `semester`, `field`.

---

## 5. TABLES MANQUANTES / MODIFICATIONS REQUISES

### Ajouts sur `td_questions`
```sql
ALTER TABLE app.td_questions ADD COLUMN IF NOT EXISTS study_year TEXT;    -- L1, L2, L3, M1, M2
ALTER TABLE app.td_questions ADD COLUMN IF NOT EXISTS semester TEXT;      -- S1, S2
ALTER TABLE app.td_questions ADD COLUMN IF NOT EXISTS field TEXT;         -- Filière (Droit, Économie, Sciences...)
ALTER TABLE app.td_questions ADD COLUMN IF NOT EXISTS points INTEGER DEFAULT 10;
ALTER TABLE app.td_questions ADD COLUMN IF NOT EXISTS time_limit_seconds INTEGER DEFAULT 60;
ALTER TABLE app.td_questions ADD COLUMN IF NOT EXISTS generation_mode TEXT; -- exercise, td_session, exam
ALTER TABLE app.td_questions ADD COLUMN IF NOT EXISTS generated_by UUID;   -- student who requested generation
```

### Nouvelle table potentielle : `td_generated_assignments`
Pour stocker les "devoirs type" complets (un devoir = ensemble de questions avec barème et durée) :
```sql
CREATE TABLE IF NOT EXISTS app.td_generated_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID,                -- NULL si pré-généré par admin
  title TEXT NOT NULL,
  subject TEXT NOT NULL,
  field TEXT,
  study_year TEXT,
  semester TEXT,
  mode TEXT DEFAULT 'exam',       -- exercise, td_session, exam
  question_ids UUID[],            -- IDs des questions dans td_questions
  total_points INTEGER DEFAULT 20,
  duration_minutes INTEGER DEFAULT 60,
  created_at TIMESTAMPTZ DEFAULT now()
);
```

---

## 6. RÉSUMÉ EXÉCUTIF

| Composant | État | Action requise |
|-----------|------|----------------|
| Tables TD | ✅ Complètes (20+ tables) | Ajouter colonnes study_year, semester, field sur td_questions |
| RPCs étudiant | ✅ 15+ RPCs | Ajouter RPC pour lister questions filtrées par filière/année/semestre |
| Edge Function td-generate-exercises | ✅ Existe | Exposer dans le Flutter (appel HTTP) |
| Edge Function td-tutor-chat | ✅ Fonctionne | — |
| Edge Function td-scan-subject | ✅ Fonctionne | — |
| Onglet Quiz | ✅ QCM par matière | Ajouter filtres filière/année + bouton générer |
| Onglet Exercices | ⚠️ Limité aux assignations enseignant | Ajouter section "Exercices IA" + devoirs type |
| Bouton demander enseignant | ❌ Enfoui dans le catalogue | Créer un bouton visible dans Accueil |
| Devoirs type pré-générés | ❌ N'existe pas | Créer l'UI + les données |
| Génération exercices par étudiant | ❌ Backend OK, UI manquante | Connecter le Flutter à td-generate-exercises |

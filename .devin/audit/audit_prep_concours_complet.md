# AUDIT EXHAUSTIF — Module Préparation Concours
**Date**: 15 Mars 2026  
**Scope**: Flutter + Supabase — Rôles Étudiant, Admin, Enseignant

---

## 1. CARTOGRAPHIE SUPABASE

### 1.1 Tables (schema `app`) — 11 tables `prep_*`

| Table | Colonnes clés | Lignes | RLS |
|-------|--------------|--------|-----|
| `prep_subjects` | id, slug, title, description, sort_order, is_active | **1** | SELECT actif+entitlement |
| `prep_chapters` | id, subject_id, slug, title, description, sort_order, is_active | **0** | SELECT actif+entitlement |
| `prep_questions` | id, subject_id, chapter_id, source, question_type, level, mechanism, prompt_context, question, explanation, correct_answer, estimated_time_sec, is_published, created_by | **0** | SELECT published+entitlement |
| `prep_question_choices` | id, question_id, choice_label, choice_text, is_correct, sort_order | **0** | SELECT via question published+entitlement |
| `prep_attempts` | id, student_id, question_id, attempt_type, selected_answer, is_correct, time_spent_sec | **0** | INSERT/SELECT own+entitlement, admin SELECT all |
| `prep_exams` | id, created_by, student_id, title, subject_id, level, mode, duration_sec, is_published | **0** | SELECT published+entitlement |
| `prep_exam_items` | id, exam_id, question_id, sort_order | **0** | SELECT via exam published+entitlement |
| `prep_source_documents` | id, created_by, subject_id, year, doc_type, source_type, storage_bucket, storage_path, extracted_text, status | **0** | admin ALL, authenticated SELECT |
| `prep_doc_chunks` | id, source_document_id, chunk_index, content, metadata | **0** | admin ALL, authenticated SELECT |
| `prep_ai_generations` | id, created_by, subject_id, generation_type, input_params, output_json, status, error_message | **1** | admin ALL, authenticated SELECT |
| `prep_ai_usage_logs` | id, user_id, generation_id, subject_id, endpoint, input_hash, status, duration_ms, metadata | **4** | INSERT own, SELECT own |

### 1.2 Tables connexes `td_*` (utilisées par les RPCs du module concours)

| Table | Rôle dans le module concours |
|-------|------------------------------|
| `td_question_banks` | Banques de questions (enseignant/admin) |
| `td_questions` | Questions QCM (enseignant/admin) |
| `td_quiz_templates` | Modèles de quiz |
| `td_quiz_attempts` | Tentatives de quiz |
| `td_exam_papers` | Sujets d'épreuves |
| `td_flashcard_decks` | Decks de flashcards |
| `td_flashcards` | Cartes individuelles |
| `td_flashcard_progress` | Progression flashcards |
| `td_badges` | Badges gamification |
| `td_student_badges` | Badges obtenus par étudiant |
| `td_ai_conversations` | Conversations IA tuteur |
| `td_ai_messages` | Messages IA tuteur |
| `td_ai_config` | Configuration IA |
| `user_feature_entitlements` | Droits d'accès (prep_concours) |

**Note**: Les tables `td_*` n'ont que des politiques `service_role ALL` (pas de RLS pour authenticated).

### 1.3 RPCs Supabase — 55 RPCs `*prep*`

#### RPCs Admin (14) — schema `public`
| RPC | Paramètres |
|-----|-----------|
| `app_admin_prep_create_subject` | p_title, p_slug, p_description, p_sort_order, p_is_active |
| `app_admin_prep_list_source_documents` | p_subject_id, p_status |
| `app_admin_prep_upsert_source_document` | p_document_id, p_subject_id, p_year, p_doc_type, p_source_type, p_storage_bucket, p_storage_path, p_extracted_text, p_status |
| `app_admin_prep_update_source_document_text` | p_document_id, p_extracted_text |
| `app_admin_prep_set_source_document_status` | p_document_id, p_status |
| `app_admin_prep_list_doc_chunks` | p_source_document_id |
| `app_admin_prep_upsert_doc_chunk` | p_source_document_id, p_chunk_index, p_content, p_metadata, p_chunk_id |
| `app_admin_prep_list_ai_generations` | p_subject_id, p_status |
| `app_admin_prep_create_ai_generation` | p_subject_id, p_generation_type, p_input_params |
| `app_admin_prep_set_ai_generation_status` | p_generation_id, p_status, p_output_json, p_error_message |
| `app_admin_prep_publish_ai_generation` | p_generation_id |
| `app_admin_prep_list_entitlements` | p_feature_key, p_only_active |
| `app_admin_prep_ai_get_usage_summary` | p_days, p_endpoint |
| `app_admin_prep_get_attempts_summary` | p_subject_id, p_days |

#### RPCs Admin (schema `app`) — 5 RPCs
| RPC | Paramètres |
|-----|-----------|
| `app_prep_admin_get_stats` | (aucun) |
| `app_prep_admin_list_questions` | p_bank_id, p_subject, p_limit, p_offset |
| `app_prep_admin_toggle_question` | p_question_id, p_is_active |
| `app_prep_admin_list_ai_conversations` | p_limit |
| `app_prep_admin_upsert_badge` | p_code, p_title, p_description, p_emoji, p_xp_reward, p_condition_type, p_condition_value |
| `app_prep_update_ai_config` | p_key, p_value |

#### RPCs Étudiant/Public — schema `public`
| RPC | Paramètres |
|-----|-----------|
| `app_prep_list_subjects` | (aucun) |
| `app_prep_list_chapters` | p_subject_id |
| `app_prep_list_published_questions` | p_subject_id, p_level, p_limit, p_chapter_id (**2 surcharges**) |
| `app_prep_list_question_choices` | p_question_id |
| `app_prep_create_attempt` | p_question_id, p_attempt_type, p_selected_answer, p_is_correct, p_time_spent_sec |
| `app_prep_list_my_attempts` | p_subject_id, p_attempt_type, p_limit |
| `app_prep_get_my_subject_stats` | p_subject_id, p_days |
| `app_prep_get_my_entitlement` | (aucun) |
| `app_prep_get_rag_chunks` | (paramètres non détaillés) |
| `app_prep_ai_check_rate_limit` | p_endpoint, p_window_seconds, p_max_calls |
| `app_prep_ai_log_usage` | p_generation_id, p_subject_id, p_input_hash, p_endpoint, p_status, p_duration_ms, p_metadata |

#### RPCs Enseignant/Shared — schema `app`
| RPC | Paramètres |
|-----|-----------|
| `app_prep_list_questions` | p_bank_id, p_concours_type, p_subject, p_difficulty, p_limit |
| `app_prep_list_question_banks` | p_concours_type, p_subject |
| `app_prep_create_question_bank` | p_title, p_description, p_concours_type, p_subject |
| `app_prep_create_question` | p_bank_id, p_content, p_options, p_correct_index, p_explanation, p_difficulty, p_subject, p_image_url, p_points, p_time_limit_seconds |
| `app_prep_list_exam_papers` | p_concours_type, p_year, p_subject |
| `app_prep_create_exam_paper` | p_title, p_concours_type, p_year, p_subject, p_paper_url, p_correction_url, p_difficulty, p_is_official, p_has_correction |
| `app_prep_list_flashcard_decks` | p_subject, p_concours_type |
| `app_prep_list_flashcards` | p_deck_id |
| `app_prep_create_flashcard_deck` | p_title, p_description, p_subject, p_concours_type |
| `app_prep_create_flashcard` | p_deck_id, p_front_text, p_back_text, p_subject, p_tags |
| `app_prep_save_flashcard_review` | p_flashcard_id, p_quality, p_ease_factor, p_interval_days, p_repetitions |
| `app_prep_save_quiz_attempt` | p_template_id, p_questions_json, p_answers_json, p_score, p_total_points, p_correct_count, p_question_count, p_time_spent_seconds, p_status |
| `app_prep_get_student_progress` | (aucun) |
| `app_prep_get_subject_stats` | (aucun) |
| `app_prep_get_leaderboard` | p_limit |
| `app_prep_list_quiz_templates` | p_concours_type, p_subject |
| `app_prep_create_quiz_template` | p_title, p_bank_id, p_concours_type, p_subject, p_question_count, p_time_limit_minutes, p_shuffle, p_is_exam_mode, p_passing_score, p_description |
| `app_prep_create_ai_conversation` | p_title, p_subject |
| `app_prep_save_ai_message` | p_conversation_id, p_role, p_content, p_tokens_used |
| `app_prep_list_ai_conversations` | (aucun) |
| `app_prep_list_ai_messages` | p_conversation_id |
| `app_prep_get_ai_config` | (aucun) |

### 1.4 Triggers (8)
| Trigger | Table | Événement | Action |
|---------|-------|-----------|--------|
| `trg_app_prep_subjects_notify` | prep_subjects | INSERT/UPDATE | `app_notify_prep_concours_change()` |
| `trg_app_prep_chapters_notify` | prep_chapters | INSERT/UPDATE | `app_notify_prep_concours_change()` |
| `trg_app_prep_questions_notify` | prep_questions | INSERT/UPDATE | `app_notify_prep_concours_change()` |
| `trg_app_prep_exams_notify` | prep_exams | INSERT/UPDATE | `app_notify_prep_concours_change()` |

### 1.5 Edge Functions
| Fonction | Status |
|----------|--------|
| `prep-tutor-chat` | ✅ HTTP 200 (déployée) |

### 1.6 Storage Buckets
**Aucun bucket `prep*` ou `concours*` ou `exam*` trouvé.** 🔴

---

## 2. CARTOGRAPHIE FLUTTER

### 2.1 Providers (4)

| Provider | Fichier | Rôle |
|----------|---------|------|
| `PrepConcoursProvider` | `lib/providers/prep_concours_provider.dart` | Étudiant: sujets, chapitres, questions publiées, choix, attempts, stats |
| `AdminPrepConcoursProvider` | `lib/providers/admin_prep_concours_provider.dart` | Admin: source documents, AI generations |
| `PrepQuizProvider` | `lib/providers/prep_quiz_provider.dart` | Quiz local (données démo, XP/streak via SharedPreferences) |
| `PrepFlashcardProvider` | `lib/providers/prep_flashcard_provider.dart` | Flashcards local (données démo, algorithme SM-2 local) |

### 2.2 Services (1)

| Service | Fichier | Rôle |
|---------|---------|------|
| `PrepAiService` | `lib/services/prep_ai_service.dart` | Tuteur IA via Edge Function `prep-tutor-chat` |
| `TdService` (section prep) | `lib/services/td_service.dart` | **35+ méthodes prep** — accès aux RPCs `td_*` et `app_prep_*` |

### 2.3 Écrans Étudiant (11 fichiers)

| Fichier | Rôle |
|---------|------|
| `features/student/student_prep_concours_screen.dart` | Écran principal (5 onglets) — **Onglet index 6 du dashboard** |
| `features/student/prep/prep_home_tab.dart` | Accueil: streak, XP, quiz du jour, actions rapides |
| `features/student/prep/prep_quiz_tab.dart` | Quiz rapide, Examen blanc, Flashcards, Par matière, Par concours |
| `features/student/prep/prep_subjects_tab.dart` | Banque d'épreuves (filtres concours/année/matière) |
| `features/student/prep/prep_ai_tab.dart` | Chat IA tuteur |
| `features/student/prep/prep_stats_tab.dart` | Analytics: progression, forces/faiblesses, badges |
| `features/student/prep_concours/prep_concours_home_screen.dart` | Ancien écran home (sujets via PrepConcoursProvider) |
| `features/student/prep_concours/prep_chapters_screen.dart` | Chapitres d'un sujet |
| `features/student/prep_concours/prep_diagnostic_screen.dart` | Diagnostic |
| `features/student/prep_concours/prep_exam_screen.dart` | Examen (questions Supabase) |
| `features/student/prep_concours/prep_training_screen.dart` | Entraînement (questions Supabase) |
| `features/student/prep_concours/prep_progress_screen.dart` | Progression |

### 2.4 Écran Admin (2 fichiers)

| Fichier | Rôle |
|---------|------|
| `features/admin/admin_prep_screen.dart` | Dashboard (stats), Questions (modération), IA Config, Badges — **utilise TdService** |
| `features/admin/prep_concours/admin_prep_concours_screen.dart` | Source documents, AI generations, Entitlements — **utilise AdminPrepConcoursProvider** |

### 2.5 Écran Enseignant (1 fichier)

| Fichier | Rôle |
|---------|------|
| `features/instructor/teacher_prep_screen.dart` | Questions (banques + QCM), Sujets d'épreuve, Flashcards, Résultats — **utilise TdService** |

### 2.6 Thème

| Fichier | Rôle |
|---------|------|
| `lib/theme/prep_theme.dart` | Palette, gradients, helpers UI du module |

---

## 3. INCOHÉRENCES IDENTIFIÉES 🔴

### 3.1 CRITIQUE — Double système de tables non connecté

**Il existe DEUX systèmes de tables parallèles qui ne communiquent pas :**

| Système A — `prep_*` (schema `app`) | Système B — `td_*` (schema `app`) |
|---------------------------------------|--------------------------------------|
| `prep_subjects` | — |
| `prep_chapters` | — |
| `prep_questions` | `td_questions` |
| `prep_question_choices` | — |
| `prep_attempts` | `td_quiz_attempts` |
| `prep_exams` | `td_exam_papers` |
| `prep_exam_items` | — |
| `prep_source_documents` | — |
| `prep_doc_chunks` | — |
| `prep_ai_generations` | — |
| `prep_ai_usage_logs` | — |
| — | `td_question_banks` |
| — | `td_quiz_templates` |
| — | `td_flashcard_decks` |
| — | `td_flashcards` |
| — | `td_flashcard_progress` |
| — | `td_badges` |
| — | `td_student_badges` |
| — | `td_ai_conversations` |
| — | `td_ai_messages` |
| — | `td_ai_config` |

**Impact**: Les écrans admin et enseignant (via `TdService`) écrivent dans les tables `td_*`, tandis que les écrans étudiant (via `PrepConcoursProvider`) lisent les tables `prep_*`. **Les données ne se voient jamais.**

### 3.2 CRITIQUE — Quiz et Flashcards 100% locaux (mode démo)

- `PrepQuizProvider` utilise **uniquement** `generateDemoQuestions()` — questions hardcodées dans le code Dart, jamais de Supabase
- `PrepFlashcardProvider` utilise **uniquement** `_generateDemoCards()` — flashcards hardcodées
- XP, streak, progression stockés dans **SharedPreferences** uniquement — aucune persistence serveur
- Le quiz du jour, l'examen blanc, les flashcards ne consultent **jamais** les RPCs Supabase

### 3.3 CRITIQUE — PrepConcoursProvider (Supabase) vs PrepQuizProvider (local)

- `PrepConcoursProvider` appelle les bonnes RPCs Supabase (`app_prep_list_subjects`, `app_prep_list_published_questions`, etc.)
- Mais les écrans dans `prep/` (onglets du StudentPrepConcoursScreen) utilisent **uniquement** `PrepQuizProvider` (données démo)
- Les écrans dans `prep_concours/` (anciens écrans) utilisent `PrepConcoursProvider` (Supabase)
- **Ces deux systèmes coexistent sans connexion** — l'étudiant voit l'un ou l'autre selon la navigation

### 3.4 HAUTE — Tables `td_*` n'ont que RLS `service_role`

- Toutes les tables `td_question_banks`, `td_questions`, `td_flashcard_decks`, etc. ont **uniquement** la policy `service_role_all`
- Pas de policy pour `authenticated` → les appels client (Flutter via `anon` key) échoueront via RPC si les RPCs ne sont pas `SECURITY DEFINER`
- Les RPCs dans schema `app` fonctionnent car elles sont probablement `SECURITY DEFINER` + `search_path = 'app'`

### 3.5 HAUTE — Aucun bucket Storage pour les documents

- `prep_source_documents` a des colonnes `storage_bucket` et `storage_path`
- `td_exam_papers` est censé stocker des sujets d'épreuve
- **Aucun bucket `prep*`, `concours*`, `exam*` n'existe** dans Supabase Storage
- L'upload de documents/sujets ne fonctionnera pas

### 3.6 MOYENNE — Duplicat de RPC `app_prep_list_published_questions`

- Cette RPC existe **en double** (2 entrées) dans le schema `public`
- Probablement 2 surcharges avec des signatures différentes

### 3.7 MOYENNE — Schéma incohérent des RPCs

- RPCs admin: certaines dans `public` (prefix `app_admin_prep_*`), d'autres dans `app` (prefix `app_prep_admin_*`)
- Pas de convention unifiée → confusion sur quel schema appeler

### 3.8 BASSE — Données quasi-vides

| Table | Lignes |
|-------|--------|
| prep_subjects | 1 |
| prep_ai_generations | 1 |
| prep_ai_usage_logs | 4 |
| Toutes les autres prep_* | **0** |

Le module n'a aucune donnée de contenu réel.

### 3.9 BASSE — ProgressChart et SubjectBreakdown hardcodés

- `prep_stats_tab.dart` → `_ProgressChart` utilise des données démo hardcodées (`[65, 72, 68, 80, 75, 85, 78]`)
- `_SubjectBreakdown` utilise des scores hardcodés
- Commentaire dans le code: "Demo data — will be replaced by real data from Supabase"

### 3.10 BASSE — Listes de concours/matières hardcodées

Les listes de concours (`ENAM, ENS, ENSET, BAC, BEPC, IRIC`) et matières (`Culture Générale, Mathématiques, Droit...`) sont hardcodées dans **3 fichiers différents**:
- `prep_quiz_tab.dart`
- `prep_subjects_tab.dart`
- `teacher_prep_screen.dart`

Aucune synchronisation avec Supabase. Si on ajoute un concours en DB, l'UI ne le verra pas.

---

## 4. MATRICE CONNEXION FLUTTER ↔ SUPABASE

### Étudiant

| Fonctionnalité | Écran Flutter | Provider | RPC Supabase | Table | Status |
|----------------|--------------|----------|-------------|-------|--------|
| Lister les matières | prep_concours_home_screen | PrepConcoursProvider | `app_prep_list_subjects` | prep_subjects | ✅ Connecté |
| Lister les chapitres | prep_chapters_screen | PrepConcoursProvider | `app_prep_list_chapters` | prep_chapters | ✅ Connecté |
| Questions publiées | prep_exam/training_screen | PrepConcoursProvider | `app_prep_list_published_questions` | prep_questions | ✅ Connecté |
| Choix de questions | prep_exam/training_screen | PrepConcoursProvider | `app_prep_list_question_choices` | prep_question_choices | ✅ Connecté |
| Enregistrer attempt | prep_exam/training_screen | PrepConcoursProvider | `app_prep_create_attempt` | prep_attempts | ✅ Connecté |
| Mes attempts | — | PrepConcoursProvider | `app_prep_list_my_attempts` | prep_attempts | ✅ Connecté |
| Stats par matière | — | PrepConcoursProvider | `app_prep_get_my_subject_stats` | prep_attempts | ✅ Connecté |
| **Quiz rapide** | **prep_quiz_tab** | **PrepQuizProvider** | **AUCUNE** | **AUCUNE** | 🔴 **100% local** |
| **Examen blanc** | **prep_quiz_tab** | **PrepQuizProvider** | **AUCUNE** | **AUCUNE** | 🔴 **100% local** |
| **Flashcards** | **prep_quiz_tab** | **PrepFlashcardProvider** | **AUCUNE** | **AUCUNE** | 🔴 **100% local** |
| **XP / Streak** | **prep_home_tab** | **PrepQuizProvider** | **AUCUNE** | **SharedPreferences** | 🔴 **100% local** |
| **Stats progression** | **prep_stats_tab** | **PrepQuizProvider** | **AUCUNE** | **SharedPreferences** | 🔴 **100% local** |
| Chat IA tuteur | prep_ai_tab | PrepAiService | Edge Function `prep-tutor-chat` | td_ai_conversations/messages | ✅ Connecté |

### Admin

| Fonctionnalité | Écran Flutter | Service/Provider | RPC Supabase | Table | Status |
|----------------|--------------|-----------------|-------------|-------|--------|
| Dashboard stats | admin_prep_screen | TdService | `app_prep_admin_get_stats` | td_* | ✅ Connecté |
| Liste questions | admin_prep_screen | TdService | `app_prep_admin_list_questions` | td_questions | ✅ Connecté |
| Toggle question | admin_prep_screen | TdService | `app_prep_admin_toggle_question` | td_questions | ✅ Connecté |
| Config IA | admin_prep_screen | TdService | `app_prep_get_ai_config` / `app_prep_update_ai_config` | td_ai_config | ✅ Connecté |
| Conversations IA | admin_prep_screen | TdService | `app_prep_admin_list_ai_conversations` | td_ai_conversations | ✅ Connecté |
| Badges CRUD | admin_prep_screen | TdService | `app_prep_admin_upsert_badge` | td_badges | ✅ Connecté |
| Source documents | admin_prep_concours_screen | AdminPrepConcoursProvider | `app_admin_prep_*` | prep_source_documents | ✅ Connecté |
| AI generations | admin_prep_concours_screen | AdminPrepConcoursProvider | `app_admin_prep_*` | prep_ai_generations | ✅ Connecté |
| Entitlements | admin_prep_concours_screen | Direct Supabase | `app_admin_prep_list_entitlements` | user_feature_entitlements | ✅ Connecté |

### Enseignant

| Fonctionnalité | Écran Flutter | Service | RPC Supabase | Table | Status |
|----------------|--------------|---------|-------------|-------|--------|
| Banques de questions | teacher_prep_screen | TdService | `app_prep_list_question_banks` | td_question_banks | ✅ Connecté |
| Créer banque | teacher_prep_screen | TdService | `app_prep_create_question_bank` | td_question_banks | ✅ Connecté |
| Créer question | teacher_prep_screen | TdService | `app_prep_create_question` | td_questions | ✅ Connecté |
| Sujets d'épreuve | teacher_prep_screen | TdService | `app_prep_list_exam_papers` / `create` | td_exam_papers | ✅ Connecté |
| Flashcard decks | teacher_prep_screen | TdService | `app_prep_list_flashcard_decks` / `create` | td_flashcard_decks | ✅ Connecté |
| Créer flashcard | teacher_prep_screen | TdService | `app_prep_create_flashcard` | td_flashcards | ✅ Connecté |

---

## 5. SYNTHÈSE DES PROBLÈMES PAR PRIORITÉ

### 🔴 CRITIQUES (bloquants)

1. **Double système de tables**: Les enseignants/admins écrivent dans `td_*`, les étudiants lisent `prep_*` → **les contenus créés par les enseignants sont invisibles pour les étudiants**
2. **Quiz/Flashcards 100% démo**: L'étudiant ne voit **jamais** les vraies questions de Supabase dans les onglets Quiz/Flashcards du nouvel écran
3. **XP/Streak non persisté serveur**: Toute la gamification est locale (SharedPreferences) → perdue à la réinstallation

### 🟠 HAUTS

4. **Pas de bucket Storage** pour les documents source et sujets d'épreuve
5. **Tables `td_*` sans RLS authenticated** — risque si les RPCs ne sont pas toutes SECURITY DEFINER
6. **Deux écrans étudiant concurrents** (`prep/` vs `prep_concours/`) avec des sources de données différentes

### 🟡 MOYENS

7. **RPCs dans 2 schemas** (`public` et `app`) sans convention claire
8. **Duplicate RPC** `app_prep_list_published_questions`
9. **Listes concours/matières hardcodées** dans 3 fichiers

### 🟢 BAS

10. **Données quasi-vides** — 1 seul sujet, 0 questions, 0 chapitres
11. **Graphiques stats hardcodés** dans prep_stats_tab.dart

---

## 6. RECOMMANDATIONS

1. **Unifier les tables**: Soit migrer tout vers `prep_*`, soit connecter les RPCs `td_*` aux tables `prep_*`
2. **Connecter PrepQuizProvider à Supabase**: Remplacer `generateDemoQuestions()` par des appels aux RPCs existantes
3. **Connecter PrepFlashcardProvider à Supabase**: Utiliser `app_prep_list_flashcard_decks` / `app_prep_list_flashcards`
4. **Créer le bucket Storage** `prep-documents` pour les sujets d'épreuve
5. **Persister XP/Streak côté serveur** via une RPC dédiée
6. **Ajouter des RLS authenticated** sur les tables `td_*` ou vérifier que toutes les RPCs sont SECURITY DEFINER
7. **Supprimer les anciens écrans** `prep_concours/` ou les intégrer dans le nouvel écran 5-onglets

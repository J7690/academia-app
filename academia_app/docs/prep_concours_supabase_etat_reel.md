# Préparation Concours – État réel Supabase (Backend)

Ce document décrit **l’architecture réelle Supabase** du module Préparation Concours (tables, RLS, RPC, entitlements, analytics), telle qu’elle est actuellement déployée via les migrations `.windsurf/sql_changes/*prep_concours*`.

---

## 1. Schéma global

- Schéma PostgreSQL principal : `app`.
- Authentification : `auth.users` (Supabase standard) avec `raw_user_meta_data->>'role'` pour distinguer `student` / `admin`.
- Feature key pour le paywall Concours : `prep_concours`.

Principales familles de tables :

- **Contenus Concours** :
  - `app.prep_subjects` : matières.
  - `app.prep_chapters` : chapitres par matière.
  - `app.prep_questions` : questions (QCM etc.).
  - `app.prep_question_choices` : choix de réponses.
  - `app.prep_exams` / `app.prep_exam_items` : examens et items d’exam.
- **Activité étudiante** :
  - `app.prep_attempts` : tentatives de réponses (training / diagnostic / exam).
- **Pipeline IA & RAG** :
  - `app.prep_source_documents` : documents sources.
  - `app.prep_doc_chunks` : chunks de texte indexés.
  - `app.prep_ai_generations` : générations IA (QCM, etc.).
- **Paywall / entitlements** :
  - `app.user_feature_entitlements` : droits d’accès par feature.
- **Anti‑piratage IA & logs** :
  - `app.prep_ai_usage_logs` : logs d’usage IA + rate‑limit.

---

## 2. RLS et sécurité (résumé)

### 2.1. Paywall & entitlements

- Table `app.user_feature_entitlements` :
  - RLS :
    - `user_select_own_feature_entitlements` → un utilisateur voit seulement ses propres entitlements.
  - Grants :
    - `SELECT` pour `authenticated`.
    - `ALL` pour `service_role`.

- Fonction centrale de paywall :
  - `app_has_feature_access(p_feature_key TEXT) RETURNS BOOLEAN`
    - Utilisée dans les politiques RLS de toutes les tables Concours visibles côté étudiant (`prep_subjects`, `prep_chapters`, `prep_questions`, `prep_question_choices`, `prep_exams`, `prep_exam_items`, `prep_attempts`).
    - Règles :
      - Si non authentifié → `FALSE`.
      - Si rôle `admin` → `TRUE` (accès systématique).
      - Sinon → présence d’un entitlement actif/non expiré dans `app.user_feature_entitlements`.

### 2.2. Tables Concours (résumé RLS)

- `app.prep_subjects` :
  - `public_select_active_prep_subjects` → `is_active = TRUE` **et** `app_has_feature_access('prep_concours')`.
- `app.prep_chapters` :
  - `public_select_active_prep_chapters` → `is_active = TRUE` **et** `app_has_feature_access('prep_concours')`.
- `app.prep_questions` :
  - `public_select_published_prep_questions` → `is_published = TRUE` **et** `app_has_feature_access('prep_concours')`.
- `app.prep_question_choices` :
  - `public_select_published_prep_question_choices` → visible uniquement pour les questions publiées, **et** `app_has_feature_access('prep_concours')`.
- `app.prep_exams` / `app.prep_exam_items` :
  - `public_select_published_prep_exams` / `public_select_published_prep_exam_items` → visibles seulement si l’examen est publié **et** paywall OK.
- `app.prep_attempts` :
  - `student_select_own_prep_attempts` → `student_id = auth.uid()` **et** `app_has_feature_access('prep_concours')`.
  - `student_insert_own_prep_attempts` → même condition en `WITH CHECK`.
  - `admin_select_all_prep_attempts` → lecture globale possible pour un `admin` (analytics).

### 2.3. Pipeline IA & RAG

- `app.prep_source_documents`, `app.prep_doc_chunks`, `app.prep_ai_generations` :
  - Politiques admin : `admin_all_*` → FOR ALL, uniquement pour rôle `admin`.
  - Politiques de lecture authentifiée : `authenticated_select_*` → `auth.uid() IS NOT NULL`.

### 2.4. Logs IA & rate‑limit

- `app.prep_ai_usage_logs` :
  - RLS :
    - `user_select_own_prep_ai_usage_logs` → un utilisateur lit seulement ses propres logs.
    - `user_insert_own_prep_ai_usage_logs` → insert limité à `user_id = auth.uid()`.
  - Grants : `SELECT, INSERT` pour `authenticated`, `ALL` pour `service_role`.

---

## 3. RPC côté étudiant (module Concours)

### 3.1. Lecture des contenus & navigation

- `app_prep_list_subjects()`
  - Liste des matières actives.
- `app_prep_list_chapters(p_subject_id UUID)`
  - Liste des chapitres actifs pour une matière.
- `app_prep_list_published_questions(p_subject_id UUID, p_level TEXT DEFAULT NULL, p_limit INTEGER DEFAULT 20, p_chapter_id UUID DEFAULT NULL)`
  - Liste JSONB des questions publiées, filtrable par niveau et chapitre.
- `app_prep_list_question_choices(p_question_id UUID)`
  - Liste des choix d’une question.

### 3.2. Tentatives & stats étudiant

- `app_prep_create_attempt(p_question_id UUID, p_attempt_type TEXT, p_selected_answer TEXT, p_is_correct BOOLEAN, p_time_spent_sec INTEGER)`
  - Enregistre une tentative pour l’étudiant courant (`auth.uid()`).
- `app_prep_list_my_attempts(p_subject_id UUID DEFAULT NULL, p_attempt_type TEXT DEFAULT NULL, p_limit INTEGER DEFAULT 50)`
  - Retourne l’historique JSONB des tentatives de l’étudiant courant, filtrable.
- `app_prep_get_my_subject_stats(p_subject_id UUID, p_days INTEGER DEFAULT 30)`
  - Statistiques simples par matière sur une fenêtre de jours (volume, correct, accuracy, temps moyen).

### 3.3. Paywall – statut d’accès étudiant

- `app_prep_get_my_entitlement(p_feature_key TEXT DEFAULT 'prep_concours')`
  - Retourne un JSON structurée :
    - `success`
    - `has_access`
    - `feature_key`
    - `entitlement` : `user_id`, `granted_by`, `granted_at`, `expires_at`, `is_active`, `metadata` (ou `null`).
  - Admins sont toujours considérés comme ayant accès (`is_admin = TRUE`).

---

## 4. RPC côté admin – Concours & IA

### 4.1. Gestion des entitlements (paywall)

- `app_admin_grant_feature_access(p_user_id UUID, p_feature_key TEXT, p_expires_at TIMESTAMPTZ DEFAULT NULL)`
  - Crée ou réactive un entitlement pour un utilisateur.
- `app_admin_revoke_feature_access(p_user_id UUID, p_feature_key TEXT)`
  - Met `is_active = FALSE` pour l’entitlement concerné.
- `app_admin_prep_list_entitlements(p_feature_key TEXT DEFAULT 'prep_concours', p_only_active BOOLEAN DEFAULT TRUE)`
  - Retourne un JSON :
    - `feature_key`, `only_active`,
    - `entitlements` : liste `{ user_id, email, feature_key, is_active, granted_at, expires_at, metadata }`.
  - Restreint au rôle `admin`.

### 4.2. Pipeline IA & documents

- `app_admin_prep_list_source_documents(p_subject_id UUID DEFAULT NULL, p_status TEXT DEFAULT NULL)`
- `app_admin_prep_upsert_source_document(...)`
- `app_admin_prep_update_source_document_text(p_document_id UUID, p_extracted_text TEXT)`
- `app_admin_prep_set_source_document_status(p_document_id UUID, p_status TEXT)`
- `app_admin_prep_list_doc_chunks(p_source_document_id UUID)`
- `app_admin_prep_upsert_doc_chunk(p_chunk_id UUID DEFAULT NULL, p_source_document_id UUID, p_chunk_index INTEGER, p_content TEXT, p_metadata JSONB DEFAULT NULL)`
- `app_admin_prep_list_ai_generations(p_subject_id UUID DEFAULT NULL, p_status TEXT DEFAULT NULL)`
- `app_admin_prep_create_ai_generation(p_subject_id UUID, p_generation_type TEXT, p_input_params JSONB DEFAULT NULL)`
- `app_admin_prep_set_ai_generation_status(p_generation_id UUID, p_status TEXT, p_output_json JSONB DEFAULT NULL, p_error_message TEXT DEFAULT NULL)`

### 4.3. Publication IA → questions Concours

- `app_admin_prep_publish_ai_generation(...)`
  - Publie une génération IA validée dans `prep_questions` + `prep_question_choices`.

### 4.4. RAG (Retrieval Augmented Generation)

- `app_prep_get_rag_chunks(p_subject_id UUID, p_limit INTEGER DEFAULT 20)`
  - Retourne des chunks de texte pour le contexte IA, soumis au paywall.

### 4.5. Analytics IA & anti‑piratage

- `app_prep_ai_log_usage(...)`
  - Insère une ligne dans `prep_ai_usage_logs` pour tracer un appel IA.
- `app_prep_ai_check_rate_limit(p_endpoint TEXT DEFAULT 'ai/prep/generate', p_window_seconds INTEGER DEFAULT 3600, p_max_calls INTEGER DEFAULT 20)`
  - Retourne un JSON `{ success, allowed, count, max, window_seconds, reset_in_seconds }`.
- `app_admin_prep_ai_get_usage_summary(p_days INTEGER DEFAULT 1, p_endpoint TEXT DEFAULT 'ai/prep/generate')`
  - Résumé IA global (admin uniquement) :
    - `total` appels sur la fenêtre,
    - `by_status` : liste `{status, count}`,
    - `top_users` : top 20 `{user_id, count}`.

### 4.6. Analytics pédagogiques globales

- `app_admin_prep_get_attempts_summary(p_subject_id UUID DEFAULT NULL, p_days INTEGER DEFAULT 30)`
  - Admin uniquement.
  - Retourne :
    - `overall` : `total`, `correct`, `accuracy`, `avg_time_sec` sur la fenêtre,
    - `by_subject` : liste `{ subject_id, total, correct, accuracy }`, éventuellement filtrée par `p_subject_id`.

---

## 5. Scripts Python `.windsurf/tools` liés au module Concours

Ces scripts utilisent `SupabaseAutoManager` + les RPC admin (`admin_execute_sql`, `execute_sql`) pour opérer sur la base réelle :

- `paywall_pick_active_student_and_grant.py`
  - Sélectionne un étudiant actif récent, révoque tous les anciens entitlements `prep_concours`, et en crée un nouveau pour cet étudiant.
- `paywall_verify_prep_concours_access.py`
  - Vérifie concrètement `app_has_feature_access('prep_concours')` pour 2 étudiants.
  - Liste les politiques RLS sur `app.prep_*` afin de confirmer le lien paywall.
- `grant_prep_concours_entitlement.py`
  - Accorde `prep_concours` au dernier étudiant créé.
- `audit_prep_ai_usage_logs.py`
  - Liste les derniers logs IA,
  - Insère un log de test,
  - Vérifie le rate‑limit via `app_prep_ai_check_rate_limit`.
- `apply_one_sql_via_admin_rpc.py`
  - Applique un fichier `.sql` de `.windsurf/sql_changes` via `admin_execute_sql`.

---

## 6. Invariants & bonnes pratiques

- Toutes les fonctionnalités Concours bloquantes (accès aux matières, chapitres, questions, examens, tentatives, RAG, IA) sont **gérées côté Supabase** par :
  - RLS + `app_has_feature_access('prep_concours')`.
  - Table `app.user_feature_entitlements`.
  - RPC dédiées (étudiant, admin, analytics, IA).
- L’admin peut opérer l’ensemble du module via :
  - RPC admin (entitlements, pipeline IA, analytics),
  - Scripts Python `.windsurf/tools`.
- Les étudiants ne voient et ne modifient que leurs propres données (`prep_attempts`, logs IA, entitlements) et uniquement si le paywall leur donne accès au module Prépa concours.

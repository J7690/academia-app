# D.18 – PHASE 2: INVENTAIRE SUPABASE RÉEL

**Date**: 2026-06-26
**Mission**: D.18

---

## MÉTHODE

Source de vérité: fichiers SQL du projet (pas d'accès direct à `pg_proc`/`pg_tables` via PostgREST).

---

## 1. RPCS

### 1.1 RPCs Flutter

| Nom | Signature | RETURNS | `jsonb_build_object` exact |
|-----|-----------|---------|---------------------------|
| `public.whiteboard_create_project` | `p_student_id uuid, p_subject text, p_renderer_id text, p_theme_id text, p_narration_mode text, p_storyboard_json jsonb DEFAULT '{}'` | `jsonb` | `{'success': true, 'project_id': v_project_id}` |
| `public.whiteboard_get_project` | `p_project_id uuid` | `jsonb` | `{'success': true, 'project': to_jsonb(project_record)}` |
| `public.whiteboard_update_project` | `p_project_id uuid, p_subject text DEFAULT NULL, p_status text DEFAULT NULL, p_renderer_id text DEFAULT NULL, p_theme_id text DEFAULT NULL, p_narration_mode text DEFAULT NULL, p_storyboard_json jsonb DEFAULT NULL` | `jsonb` | `{'success': true, 'project': to_jsonb(project_record)}` |
| `public.whiteboard_list_projects` | `p_status text DEFAULT NULL` | `jsonb` | `{'success': true, 'projects': COALESCE(projects, '[]'::jsonb)}` |
| `public.whiteboard_delete_project` | `p_project_id uuid` | `jsonb` | `{'success': true, 'message': 'Project deleted'}` |
| `public.whiteboard_create_render_job` | `p_project_id uuid` | `jsonb` | `{'success': true, 'render_id': v_render_id}` |
| `public.whiteboard_get_render_status` | `p_render_id uuid` | `jsonb` | `{'success': true, 'render': to_jsonb(render_record)}` |

### 1.2 RPCs Worker

| Nom | Signature | RETURNS |
|-----|-----------|---------|
| `public.whiteboard_fetch_queued_jobs` | `p_limit integer DEFAULT 5` | `TABLE (id uuid, storyboard jsonb, created_at timestamptz)` |
| `public.whiteboard_mark_processing` | `p_job_id uuid` | `void` |
| `public.whiteboard_mark_done` | `p_job_id uuid, p_video_url text, p_duration_ms integer` | `void` |
| `public.whiteboard_mark_failed` | `p_job_id uuid, p_error_message text` | `void` |
| `public.whiteboard_get_any_student_id` | aucun | `uuid` |

---

## 2. TABLES

### 2.1 `app.whiteboard_projects`

| Colonne | Type | Contrainte |
|---------|------|------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() |
| `student_id` | UUID | REFERENCES auth.users(id) ON DELETE CASCADE |
| `subject` | VARCHAR(255) | NOT NULL |
| `status` | VARCHAR(50) | DEFAULT 'draft' |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() |
| `updated_at` | TIMESTAMPTZ | DEFAULT NOW() |
| `renderer_id` | VARCHAR(50) | NOT NULL |
| `theme_id` | VARCHAR(50) | NOT NULL |
| `narration_mode` | VARCHAR(50) | DEFAULT 'none' |
| `storyboard_json` | JSONB | nullable |

### 2.2 `app.whiteboard_renders`

| Colonne | Type | Contrainte |
|---------|------|------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() |
| `project_id` | UUID | REFERENCES app.whiteboard_projects(id) ON DELETE CASCADE |
| `status` | VARCHAR(50) | DEFAULT 'queued' |
| `video_url` | TEXT | nullable |
| `duration_ms` | INTEGER | nullable |
| `file_size_bytes` | BIGINT | nullable |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() |
| `completed_at` | TIMESTAMPTZ | nullable |
| `error_message` | TEXT | nullable |
| `progress` | INTEGER | DEFAULT 0 |

### 2.3 `app.whiteboard_ai_generations`

| Colonne | Type | Contrainte |
|---------|------|------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() |
| `created_by` | UUID | NOT NULL, REFERENCES auth.users(id) |
| `generation_type` | VARCHAR(50) | DEFAULT 'storyboard' |
| `input_params` | JSONB | NOT NULL |
| `output_json` | JSONB | NOT NULL |
| `status` | VARCHAR(50) | DEFAULT 'validated' |
| `model_used` | VARCHAR(100) | nullable |
| `tokens_input` | INTEGER | DEFAULT 0 |
| `tokens_output` | INTEGER | DEFAULT 0 |
| `cost_usd` | DECIMAL(10,6) | DEFAULT 0 |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() |
| `updated_at` | TIMESTAMPTZ | DEFAULT NOW() |

---

## 3. BUCKETS

| Bucket | Source | Statut |
|--------|--------|--------|
| `whiteboard-renders` | `academia_bobodo_backend/whiteboard_render_worker.py` | ✅ Référencé |
| `whiteboard-videos` | `.windsurf/d17_supabase_inventory.md` | ⚠️ Non confirmé dans SQL |
| `whiteboard-assets` | `.windsurf/d17_supabase_inventory.md` | ⚠️ Non confirmé dans SQL |

---

## 4. EDGE FUNCTIONS

| Edge Function | Fichier | Déployée |
|---------------|---------|----------|
| `whiteboard-generate-storyboard` | `supabase/functions/whiteboard-generate-storyboard/index.ts` | ⚠️ Non vérifié |

---

## 5. LIMITATIONS

- Aucun accès direct à `pg_proc`, `pg_tables`, `storage.buckets` via PostgREST.
- L'état réel de la base (RPCs effectivement présentes, wrappers publics, Edge Functions déployées) n'est pas confirmé par une preuve directe.
- L'inventaire ci-dessus est basé sur les fichiers SQL et Python du repo.

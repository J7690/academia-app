# D.17 - PHASE 2: INVENTAIRE SUPABASE RÉEL

**Date**: 2026-06-26
**Mission**: D.17

---

## MÉTHODE

Tentative d'accès direct à Supabase via PostgREST puis via `admin_execute_sql`.

### Résultat des tentatives

- **PostgREST direct** (`pg_proc`, `pg_tables`, `storage.buckets`): échec 404 – tables système non exposées dans le schema cache.
- **`admin_execute_sql`**: succès 200 mais retourne uniquement `{ "ok": true, "mode": "exec", "affected_rows": N }`, pas les résultats des `SELECT`.

### Conclusion méthodologique

Les preuves SQL réelles n'ont pas pu être extraites automatiquement via l'API REST. L'inventaire ci-dessous est basé sur les fichiers de source SQL présents dans le projet (archivés et actifs) et constitue une **source secondaire**.

---

## SECTION RPCS

### RPCs Flutter attendues (d'après le contrat)

| Nom | Schéma attendu | Arguments | Retour |
|-----|---------------|-----------|--------|
| `whiteboard_create_project` | `public` | `p_student_id UUID, p_subject VARCHAR, p_renderer_id VARCHAR, p_theme_id VARCHAR, p_narration_mode VARCHAR, p_storyboard_json JSONB` | `JSONB` |
| `whiteboard_get_project` | `public` | `p_project_id UUID` | `JSONB` |
| `whiteboard_update_project` | `public` | `p_project_id UUID, p_subject VARCHAR DEFAULT NULL, p_status VARCHAR DEFAULT NULL, p_renderer_id VARCHAR DEFAULT NULL, p_theme_id VARCHAR DEFAULT NULL, p_narration_mode VARCHAR DEFAULT NULL, p_storyboard_json JSONB DEFAULT NULL` | `JSONB` |
| `whiteboard_list_projects` | `public` | `p_status VARCHAR DEFAULT NULL` | `JSONB` |
| `whiteboard_delete_project` | `public` | `p_project_id UUID` | `JSONB` |
| `whiteboard_create_render_job` | `public` | `p_project_id UUID` | `JSONB` |
| `whiteboard_get_render_status` | `public` | `p_render_id UUID` | `JSONB` |

### RPCs Worker attendues (d'après les fichiers SQL)

| Nom | Schéma | Arguments | Retour |
|-----|--------|-----------|--------|
| `whiteboard_fetch_queued_jobs` | `public` | `p_limit INT DEFAULT 10` | `JSONB` |
| `whiteboard_mark_processing` | `public` | `p_render_id UUID` | `JSONB` |
| `whiteboard_mark_done` | `public` | `p_render_id UUID, p_video_url TEXT` | `JSONB` |
| `whiteboard_mark_failed` | `public` | `p_render_id UUID, p_error_message TEXT` | `JSONB` |
| `whiteboard_get_any_student_id` | `public` | aucun | `UUID` |

### RPCs internes (schema `app`)

| Nom | Schéma | Arguments | Retour |
|-----|--------|-----------|--------|
| `app.whiteboard_create_project` | `app` | `p_student_id UUID, p_subject VARCHAR, p_renderer_id VARCHAR, p_theme_id VARCHAR, p_narration_mode VARCHAR, p_storyboard_json JSONB` | `JSONB` |
| `app.whiteboard_get_project` | `app` | `p_project_id UUID` | `JSONB` |
| `app.whiteboard_update_project` | `app` | `p_project_id UUID, p_subject VARCHAR DEFAULT NULL, p_status VARCHAR DEFAULT NULL, p_renderer_id VARCHAR DEFAULT NULL, p_theme_id VARCHAR DEFAULT NULL, p_narration_mode VARCHAR DEFAULT NULL, p_storyboard_json JSONB DEFAULT NULL` | `JSONB` |
| `app.whiteboard_list_projects` | `app` | `p_status VARCHAR DEFAULT NULL` | `JSONB` |
| `app.whiteboard_delete_project` | `app` | `p_project_id UUID` | `JSONB` |

### Triggers (schema `app`)

| Nom | Table | Type |
|-----|-------|------|
| `whiteboard_projects_updated_at` | `app.whiteboard_projects` | trigger function |

---

## SECTION TABLES

| Table | Schéma | Source |
|-------|--------|--------|
| `whiteboard_projects` | `app` | `02_create_whiteboard_tables.sql` |
| `whiteboard_renders` | `app` | `02_create_whiteboard_tables.sql` / `change_20260623_whiteboard_renders_structure.sql` |
| `whiteboard_ai_generations` | `app` | `change_20260624_whiteboard_tables_buckets.sql` |

---

## SECTION STORAGE

| Bucket | Source |
|--------|--------|
| `whiteboard-videos` | `change_20260624_whiteboard_tables_buckets.sql` |
| `whiteboard-assets` | `change_20260624_whiteboard_tables_buckets.sql` |

---

## LIMITATIONS

- Les données réelles de Supabase n'ont pas pu être lues via l'API REST.
- L'état actuel de la base (RPCs effectivement présentes, wrappers publics à jour) n'est pas confirmé par une preuve directe.
- Les fichiers SQL source indiquent que les RPCs `public.*` sont des wrappers autour des RPCs `app.*`.

---

## RECOMMANDATION

Pour obtenir une preuve directe, exécuter les requêtes dans SQL Editor Supabase ou via une CLI psql connectée à la base.

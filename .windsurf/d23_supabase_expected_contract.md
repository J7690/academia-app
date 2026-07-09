# D.23 – PHASE 2 : CONTRAT ATTENDU SUPABASE

**Date** : 2026-06-28  
**Sources** : SQL réel extrait via `admin_execute_sql` (toolchain `.windsurf/d23_supabase_sql3.py`, `d23_sb01.py`)  
**Timestamp audit** : 2026-06-28T10:01:24Z → 10:02:14Z

---

## 1. `whiteboard_create_project` — DÉFINITION SQL RÉELLE

### Signature complète (D23-SB-01)

```sql
-- Source: pg_proc via admin_execute_sql
-- Résultat D23-SB-01 (HTTP 200, ok: true)

CREATE OR REPLACE FUNCTION public.whiteboard_create_project(
  p_student_id    uuid,
  p_subject       text,
  p_renderer_id   text,
  p_theme_id      text,
  p_narration_mode text,
  p_storyboard_json jsonb DEFAULT '{}'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
```

**Return type** : `jsonb`  
**Arguments** : 6 paramètres (dont `p_storyboard_json` avec défaut `{}`)

### Corps SQL réel (D23-SB-02 + D23-SB-03)

```sql
DECLARE
  v_project_id uuid;
  v_result jsonb;
BEGIN
  INSERT INTO app.whiteboard_projects (
    student_id,
    subject,
    status,
    renderer_id,
    theme_id,
    narration_mode,
    storyboard_json
  ) VALUES (
    p_student_id,
    p_subject,
    'draft',
    p_renderer_id,
    p_theme_id,
    p_narration_mode,
    p_storyboard_json
  )
  RETURNING id INTO v_project_id;

  v_result := jsonb_build_object(
    'success', true,
    'project_id', v_project_id
  );

  RETURN v_result;
END;
```

---

## 2. CONTRAT DE RETOUR RÉEL

```json
{
  "success": true,
  "project_id": "<uuid>"
}
```

**Champs retournés** :
- `success` : `bool` — toujours `true` (pas de gestion d'erreur explicite dans le corps)
- `project_id` : `uuid` — l'ID auto-généré de la nouvelle ligne

**Champs NON retournés** :
- `subject` : ❌ NON retourné
- `renderer_id` : ❌ NON retourné
- `theme_id` : ❌ NON retourné
- `narration_mode` : ❌ NON retourné
- `storyboard_json` : ❌ NON retourné
- `status` : ❌ NON retourné
- `created_at` : ❌ NON retourné
- `student_id` : ❌ NON retourné

**Preuve runtime D22** :
```
DEBUG-D19-31: service.createProject response={success: true, project_id: f04aa2f5-b456-4ffb-81f1-42216d7d36ae}
```
✅ Conforme au SQL réel.

---

## 3. CONTRAT DE RETOUR ATTENDU PAR FLUTTER

Flutter (`smart_whiteboard_provider.dart:100-102`) ne lit que :
```dart
if (result['success'] == true) {
  _currentProjectId = result['project_id'] as String;
```

**Flutter attendait** uniquement : `{success, project_id}` → **conforme** au SQL réel.

**Ce que Flutter n'attendait PAS** mais aurait eu besoin : `{success, project_id, subject, renderer_id, theme_id, narration_mode}` pour construire `WhiteboardProject` depuis la réponse.

---

## 4. `whiteboard_get_project` — DÉFINITION SQL RÉELLE

### Signature (D23-SB-04)

```sql
CREATE OR REPLACE FUNCTION public.whiteboard_get_project(p_project_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
```

### Corps SQL réel

```sql
DECLARE
  project_record RECORD;
  result JSONB;
BEGIN
  SELECT
    id,
    student_id,
    subject,
    status,
    created_at,
    updated_at,
    renderer_id,
    theme_id,
    narration_mode,
    storyboard_json
  INTO project_record
  FROM app.whiteboard_projects
  WHERE id = p_project_id
  AND student_id = auth.uid();

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Project not found');
  END IF;

  result := jsonb_build_object(
    'success', true,
    'project', to_jsonb(project_record)
  );

  RETURN result;
END;
```

**Contrat de retour** :
```json
{
  "success": true,
  "project": {
    "id": "<uuid>",
    "student_id": "<uuid>",
    "subject": "<text>",
    "status": "<text>",
    "created_at": "<timestamp>",
    "updated_at": "<timestamp>",
    "renderer_id": "<text>",
    "theme_id": "<text>",
    "narration_mode": "<text>",
    "storyboard_json": {}
  }
}
```

**Observation critique** : `whiteboard_get_project` retourne **tous les champs** du projet, dont `subject`, `renderer_id`, `theme_id`, `narration_mode`. Si Flutter appelait `getProject()` après `createProject()`, il disposerait de toutes les données pour construire `WhiteboardProject`.

---

## 5. `whiteboard_get_render_status` — CAUSE DE L'ERREUR SQL 42703

### Corps SQL réel (D23-SB-06)

```sql
SELECT
  wr.id,
  wr.project_id,
  wr.status,
  wr.video_url,
  wr.duration_ms,
  wr.file_size_bytes,   -- ← COLONNE INEXISTANTE
  wr.created_at,
  wr.completed_at,
  wr.error_message,
  wr.progress
INTO render_record
FROM app.whiteboard_renders wr
JOIN app.whiteboard_projects wp ON wr.project_id = wp.id
WHERE wr.id = p_render_id
AND wp.student_id = auth.uid();
```

### Colonnes réelles de `whiteboard_renders` (D23-SB-07)

| Colonne | Type | Nullable |
|---------|------|----------|
| `id` | uuid | NO |
| `project_id` | uuid | NO |
| `status` | text | NO |
| `video_url` | text | YES |
| `duration_ms` | integer | YES |
| `error_message` | text | YES |
| `progress` | integer | YES |
| `created_at` | timestamp | NO |
| `completed_at` | timestamp | YES |
| `started_at` | timestamp | YES |
| `video_storage_path` | text | YES |
| `video_storage_bucket` | text | YES |
| `updated_at` | timestamp | NO |
| `export_settings` | jsonb | YES |

**Colonne `file_size_bytes`** : ❌ **ABSENTE** de la table `whiteboard_renders`

**Confirmation** : La RPC référence `wr.file_size_bytes` mais la colonne n'existe pas → SQL error `42703` → HTTP 400 systématique.

---

## 6. TOUTES LES RPCs WHITEBOARD — RETURN TYPES (D23-SB-08)

| RPC | Return Type |
|-----|-------------|
| `whiteboard_create_project` | `jsonb` |
| `whiteboard_get_project` | `jsonb` |
| `whiteboard_update_project` | `jsonb` |
| `whiteboard_delete_project` | `jsonb` |
| `whiteboard_list_projects` | `jsonb` |
| `whiteboard_create_render_job` | `jsonb` |
| `whiteboard_get_render_status` | `jsonb` (**cassée SQL**) |
| `whiteboard_fetch_queued_jobs` | `TABLE(id uuid, storyboard jsonb, created_at timestamp)` |
| `whiteboard_mark_processing` | `void` |
| `whiteboard_mark_done` | `void` |
| `whiteboard_mark_failed` | `void` |
| `whiteboard_get_any_student_id` | `uuid` |

---

## 7. ANALYSE DU CONTRAT : CONFORME OU ÉCART ?

| Aspect | Contrat Supabase réel | Contrat Flutter attendu | Conforme ? |
|--------|-----------------------|------------------------|-----------|
| `whiteboard_create_project` retourne | `{success, project_id}` | `{success, project_id}` | ✅ OUI |
| Données projet dans la réponse | **NON** (pas de subject/renderer/theme) | Implicitement attendues pour `_currentProject` | ❌ ÉCART |
| `whiteboard_get_project` retourne | `{success, project: {...tous les champs...}}` | `{success, project}` lu dans `getProject()` | ✅ conforme SI appelé |
| `whiteboard_get_render_status` | HTTP 400 SQL 42703 | HTTP 200 `{success, render}` | ❌ CASSÉE |

---

## 8. CONCLUSION PHASE 2

La RPC `whiteboard_create_project` **retourne intentionnellement uniquement** `{success, project_id}` — c'est un contrat délibéré (INSERT + RETURNING id uniquement). Elle ne retourne pas les données projet car le développeur SQL **supposait** que Flutter connaissait déjà les valeurs envoyées (ce qui est vrai — les paramètres sont dans le scope de `createProject()`).

**La Supabase n'est pas la cause du bug.** Elle retourne ce qui était prévu. Le bug est côté Flutter : après réception de `project_id`, Flutter devait construire l'objet `WhiteboardProject` localement depuis ses propres paramètres — et ne l'a pas fait.

---

**DOCUMENT CLÔTURÉ** — SQL réel extrait via toolchain `.windsurf/d23_supabase_sql3.py` + `d23_sb01.py`.

# D.17.1 – PHASE 1: CONTRATS JSON RÉELS DES 7 RPC FLUTTER

**Date**: 2026-06-26
**Mission**: D.17.1
**Source de vérité SQL**: `.windsurf/create_missing_flutter_rpcs.sql`

---

## 1. `whiteboard_create_project`

### SQL exact

```sql
@.windsurf/create_missing_flutter_rpcs.sql:29-71
CREATE OR REPLACE FUNCTION public.whiteboard_create_project(
  p_student_id uuid,
  p_subject text,
  p_renderer_id text,
  p_theme_id text,
  p_narration_mode text,
  p_storyboard_json jsonb DEFAULT '{}'::jsonb
)
RETURNS jsonb
...
  v_result := jsonb_build_object(
    'success', true,
    'project_id', v_project_id
  );
```

### JSON final renvoyé

```json
{
  "success": true,
  "project_id": "<uuid>"
}
```

---

## 2. `whiteboard_get_project`

### SQL exact

```sql
@.windsurf/create_missing_flutter_rpcs.sql:79-117
CREATE OR REPLACE FUNCTION public.whiteboard_get_project(
  p_project_id uuid
)
RETURNS jsonb
...
  result := jsonb_build_object(
    'success', true,
    'project', to_jsonb(project_record)
  );
```

### JSON final renvoyé

```json
{
  "success": true,
  "project": {
    "id": "<uuid>",
    "student_id": "<uuid>",
    "subject": "...",
    "status": "...",
    "created_at": "...",
    "updated_at": "...",
    "renderer_id": "...",
    "theme_id": "...",
    "narration_mode": "...",
    "storyboard_json": {...}
  }
}
```

---

## 3. `whiteboard_update_project`

### SQL exact

```sql
@.windsurf/create_missing_flutter_rpcs.sql:127-168
CREATE OR REPLACE FUNCTION public.whiteboard_update_project(
  p_project_id uuid,
  p_subject text DEFAULT NULL,
  p_status text DEFAULT NULL,
  p_renderer_id text DEFAULT NULL,
  p_theme_id text DEFAULT NULL,
  p_narration_mode text DEFAULT NULL,
  p_storyboard_json jsonb DEFAULT NULL
)
RETURNS jsonb
...
  result := jsonb_build_object(
    'success', true,
    'project', to_jsonb(project_record)
  );
```

### JSON final renvoyé

```json
{
  "success": true,
  "project": {
    "id": "<uuid>",
    "student_id": "<uuid>",
    "subject": "...",
    "status": "...",
    "created_at": "...",
    "updated_at": "...",
    "renderer_id": "...",
    "theme_id": "...",
    "narration_mode": "...",
    "storyboard_json": {...}
  }
}
```

---

## 4. `whiteboard_list_projects`

### SQL exact

```sql
@.windsurf/create_missing_flutter_rpcs.sql:178-215
CREATE OR REPLACE FUNCTION public.whiteboard_list_projects(
  p_status text DEFAULT NULL
)
RETURNS jsonb
...
  result := jsonb_build_object(
    'success', true,
    'projects', COALESCE(projects, '[]'::jsonb)
  );
```

### JSON final renvoyé

```json
{
  "success": true,
  "projects": [
    {
      "id": "<uuid>",
      "student_id": "<uuid>",
      "subject": "...",
      "status": "...",
      "created_at": "...",
      "updated_at": "...",
      "renderer_id": "...",
      "theme_id": "...",
      "narration_mode": "..."
    }
  ]
}
```

---

## 5. `whiteboard_delete_project`

### SQL exact

```sql
@.windsurf/create_missing_flutter_rpcs.sql:223-244
CREATE OR REPLACE FUNCTION public.whiteboard_delete_project(
  p_project_id uuid
)
RETURNS jsonb
...
  result := jsonb_build_object(
    'success', true,
    'message', 'Project deleted'
  );
```

### JSON final renvoyé

```json
{
  "success": true,
  "message": "Project deleted"
}
```

---

## 6. `whiteboard_create_render_job`

### SQL exact

```sql
@.windsurf/create_missing_flutter_rpcs.sql:252-294
CREATE OR REPLACE FUNCTION public.whiteboard_create_render_job(
  p_project_id uuid
)
RETURNS jsonb
...
  v_result := jsonb_build_object(
    'success', true,
    'render_id', v_render_id
  );
```

### JSON final renvoyé

```json
{
  "success": true,
  "render_id": "<uuid>"
}
```

---

## 7. `whiteboard_get_render_status`

### SQL exact

```sql
@.windsurf/create_missing_flutter_rpcs.sql:302-341
CREATE OR REPLACE FUNCTION public.whiteboard_get_render_status(
  p_render_id uuid
)
RETURNS jsonb
...
  result := jsonb_build_object(
    'success', true,
    'render', to_jsonb(render_record)
  );
```

### JSON final renvoyé

```json
{
  "success": true,
  "render": {
    "id": "<uuid>",
    "project_id": "<uuid>",
    "status": "...",
    "video_url": "...",
    "duration_ms": ...,
    "file_size_bytes": ...,
    "created_at": "...",
    "completed_at": "...",
    "error_message": "...",
    "progress": ...
  }
}
```

---

## RÉSUMÉ

| RPC | Clé principale du succès | Type JSON |
|-----|--------------------------|-----------|
| `whiteboard_create_project` | `project_id` | `String` |
| `whiteboard_get_project` | `project` | `Map` |
| `whiteboard_update_project` | `project` | `Map` |
| `whiteboard_list_projects` | `projects` | `List` |
| `whiteboard_delete_project` | `message` | `String` |
| `whiteboard_create_render_job` | `render_id` | `String` |
| `whiteboard_get_render_status` | `render` | `Map` |

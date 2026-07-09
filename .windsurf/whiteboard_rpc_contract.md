# WHITEBOARD RPC CONTRACT

## CONTRAT OFFICIEL UNIQUE

**Date**: 2026-06-25
**Version**: 1.0
**Schéma cible**: public (toutes les RPCs accessibles via PostgREST)

---

## RPC: whiteboard_create_project

**SCHEMA**: public

**SIGNATURE UNIQUE**:
```sql
(
  p_student_id uuid,
  p_subject text,
  p_renderer_id text,
  p_theme_id text,
  p_narration_mode text,
  p_storyboard_json jsonb
)
RETURNS jsonb
```

**VALEUR DE RETOUR**:
```json
{
  "success": true,
  "project_id": "uuid"
}
```

**UTILISATEURS**:
- Flutter: `SmartWhiteboardService.createProject()`
- Edge Functions: `whiteboard-generate-storyboard`

---

## RPC: whiteboard_get_project

**SCHEMA**: public

**SIGNATURE UNIQUE**:
```sql
(
  p_project_id uuid
)
RETURNS jsonb
```

**VALEUR DE RETOUR**:
```json
{
  "success": true,
  "project": {
    "id": "uuid",
    "student_id": "uuid",
    "subject": "text",
    "status": "text",
    "created_at": "timestamptz",
    "updated_at": "timestamptz",
    "renderer_id": "text",
    "theme_id": "text",
    "narration_mode": "text",
    "storyboard_json": "jsonb"
  }
}
```

**UTILISATEURS**:
- Flutter: `SmartWhiteboardService.getProject()`

---

## RPC: whiteboard_update_project

**SCHEMA**: public

**SIGNATURE UNIQUE**:
```sql
(
  p_project_id uuid,
  p_subject text DEFAULT NULL,
  p_status text DEFAULT NULL,
  p_renderer_id text DEFAULT NULL,
  p_theme_id text DEFAULT NULL,
  p_narration_mode text DEFAULT NULL,
  p_storyboard_json jsonb DEFAULT NULL
)
RETURNS jsonb
```

**VALEUR DE RETOUR**:
```json
{
  "success": true,
  "project": { ... }
}
```

**UTILISATEURS**:
- Flutter: `SmartWhiteboardService.updateProject()`

---

## RPC: whiteboard_delete_project

**SCHEMA**: public

**SIGNATURE UNIQUE**:
```sql
(
  p_project_id uuid
)
RETURNS jsonb
```

**VALEUR DE RETOUR**:
```json
{
  "success": true,
  "message": "Project deleted"
}
```

**UTILISATEURS**:
- Flutter: `SmartWhiteboardService.deleteProject()`

---

## RPC: whiteboard_list_projects

**SCHEMA**: public

**SIGNATURE UNIQUE**:
```sql
(
  p_status text DEFAULT NULL
)
RETURNS jsonb
```

**VALEUR DE RETOUR**:
```json
{
  "success": true,
  "projects": [
    {
      "id": "uuid",
      "student_id": "uuid",
      "subject": "text",
      "status": "text",
      "created_at": "timestamptz",
      "updated_at": "timestamptz",
      "renderer_id": "text",
      "theme_id": "text",
      "narration_mode": "text"
    }
  ]
}
```

**UTILISATEURS**:
- Flutter: `SmartWhiteboardService.listProjects()`

---

## RPC: whiteboard_create_render_job

**SCHEMA**: public

**SIGNATURE UNIQUE**:
```sql
(
  p_project_id uuid
)
RETURNS jsonb
```

**VALEUR DE RETOUR**:
```json
{
  "success": true,
  "render_id": "uuid"
}
```

**UTILISATEURS**:
- Flutter: `SmartWhiteboardRenderService.createRenderJob()`

---

## RPC: whiteboard_get_render_status

**SCHEMA**: public

**SIGNATURE UNIQUE**:
```sql
(
  p_render_id uuid
)
RETURNS jsonb
```

**VALEUR DE RETOUR**:
```json
{
  "success": true,
  "render": {
    "id": "uuid",
    "project_id": "uuid",
    "status": "text",
    "video_url": "text",
    "duration_ms": "integer",
    "file_size_bytes": "bigint",
    "created_at": "timestamptz",
    "completed_at": "timestamptz",
    "error_message": "text",
    "progress": "integer"
  }
}
```

**UTILISATEURS**:
- Flutter: `SmartWhiteboardRenderService.getRenderStatus()`

---

## RPC: whiteboard_fetch_queued_jobs

**SCHEMA**: public

**SIGNATURE UNIQUE**:
```sql
(
  p_limit integer DEFAULT 5
)
RETURNS TABLE (
  id uuid,
  storyboard jsonb,
  created_at timestamptz
)
```

**UTILISATEURS**:
- Worker Python (backend)

---

## RPC: whiteboard_mark_processing

**SCHEMA**: public

**SIGNATURE UNIQUE**:
```sql
(
  p_job_id uuid
)
RETURNS void
```

**UTILISATEURS**:
- Worker Python (backend)

---

## RPC: whiteboard_mark_done

**SCHEMA**: public

**SIGNATURE UNIQUE**:
```sql
(
  p_job_id uuid,
  p_video_url text,
  p_duration_ms integer
)
RETURNS void
```

**UTILISATEURS**:
- Worker Python (backend)

---

## RPC: whiteboard_mark_failed

**SCHEMA**: public

**SIGNATURE UNIQUE**:
```sql
(
  p_job_id uuid,
  p_error_message text
)
RETURNS void
```

**UTILISATEURS**:
- Worker Python (backend)

---

## RPC: whiteboard_get_any_student_id

**SCHEMA**: public

**SIGNATURE UNIQUE**:
```sql
()
RETURNS uuid
```

**UTILISATEURS**:
- Worker Python (backend)

---

## CONVENTIONS

1. **Toutes les RPCs sont dans le schéma public** pour être accessibles via PostgREST
2. **Les paramètres sont préfixés par p_** pour éviter les conflits avec les noms de colonnes
3. **Les retours sont en format JSONB** pour faciliter le parsing côté client
4. **Les erreurs sont retournées dans le JSON** avec un champ "error" plutôt que de lancer des exceptions PostgreSQL
5. **Les paramètres optionnels ont une valeur DEFAULT NULL** pour permettre les appels partiels

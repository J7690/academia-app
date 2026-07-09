# D.18.1 – PHASE 2: CONTRATS JSON SQL RÉELS

**Date**: 2026-06-26
**Mission**: D.18.1
**Source unique**: `create_missing_flutter_rpcs.sql`

---

## 1. `whiteboard_create_project`

### SQL

```sql
@.windsurf/create_missing_flutter_rpcs.sql:64-67
v_result := jsonb_build_object(
  'success', true,
  'project_id', v_project_id
);
```

### Contrat JSON

```json
{
  "success": true,
  "project_id": "uuid"
}
```

### Clés exactes

| Clé | Type | Nullable | Source |
|-----|------|----------|--------|
| `success` | `boolean` | non | `jsonb_build_object` |
| `project_id` | `uuid` | non | `RETURNING id` |

---

## 2. `whiteboard_get_project`

### SQL

```sql
@.windsurf/create_missing_flutter_rpcs.sql:106-113
IF NOT FOUND THEN
  RETURN jsonb_build_object('success', false, 'error', 'Project not found');
END IF;

result := jsonb_build_object(
  'success', true,
  'project', to_jsonb(project_record)
);
```

### Contrat JSON (succès)

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

### Contrat JSON (erreur)

```json
{
  "success": false,
  "error": "Project not found"
}
```

### Clés exactes

| Clé | Type | Nullable | Source |
|-----|------|----------|--------|
| `success` | `boolean` | non | `jsonb_build_object` |
| `project` | `object` | non | `to_jsonb(project_record)` |
| `project.id` | `uuid` | non | table |
| `project.student_id` | `uuid` | non | table |
| `project.subject` | `text` | non | table |
| `project.status` | `text` | non | table |
| `project.created_at` | `timestamptz` | non | table |
| `project.updated_at` | `timestamptz` | non | table |
| `project.renderer_id` | `text` | non | table |
| `project.theme_id` | `text` | non | table |
| `project.narration_mode` | `text` | non | table (DEFAULT 'none') |
| `project.storyboard_json` | `jsonb` | oui | table |
| `error` | `text` | oui | erreur seulement |

---

## 3. `whiteboard_update_project`

### SQL

```sql
@.windsurf/create_missing_flutter_rpcs.sql:157-164
IF NOT FOUND THEN
  RETURN jsonb_build_object('success', false, 'error', 'Project not found');
END IF;

result := jsonb_build_object(
  'success', true,
  'project', to_jsonb(project_record)
);
```

### Contrat JSON (succès)

Identique à `whiteboard_get_project`.

### Contrat JSON (erreur)

```json
{
  "success": false,
  "error": "Project not found"
}
```

---

## 4. `whiteboard_list_projects`

### SQL

```sql
@.windsurf/create_missing_flutter_rpcs.sql:189-211
SELECT jsonb_agg(to_jsonb(t))
INTO projects
FROM (
  SELECT 
    id,
    student_id,
    subject,
    status,
    created_at,
    updated_at,
    renderer_id,
    theme_id,
    narration_mode
  FROM app.whiteboard_projects
  WHERE student_id = auth.uid()
  AND (p_status IS NULL OR status = p_status)
  ORDER BY created_at DESC
) t;

result := jsonb_build_object(
  'success', true,
  'projects', COALESCE(projects, '[]'::jsonb)
);
```

### Contrat JSON

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

### Clés exactes

| Clé | Type | Nullable | Source |
|-----|------|----------|--------|
| `success` | `boolean` | non | `jsonb_build_object` |
| `projects` | `array` | non | `jsonb_agg` |
| `projects[].id` | `uuid` | non | table |
| `projects[].student_id` | `uuid` | non | table |
| `projects[].subject` | `text` | non | table |
| `projects[].status` | `text` | non | table |
| `projects[].created_at` | `timestamptz` | non | table |
| `projects[].updated_at` | `timestamptz` | non | table |
| `projects[].renderer_id` | `text` | non | table |
| `projects[].theme_id` | `text` | non | table |
| `projects[].narration_mode` | `text` | non | table |

---

## 5. `whiteboard_delete_project`

### SQL

```sql
@.windsurf/create_missing_flutter_rpcs.sql:237-240
result := jsonb_build_object(
  'success', true,
  'message', 'Project deleted'
);
```

### Contrat JSON

```json
{
  "success": true,
  "message": "Project deleted"
}
```

### Clés exactes

| Clé | Type | Nullable | Source |
|-----|------|----------|--------|
| `success` | `boolean` | non | `jsonb_build_object` |
| `message` | `text` | non | `jsonb_build_object` |

---

## 6. `whiteboard_create_render_job`

### SQL

```sql
@.windsurf/create_missing_flutter_rpcs.sql:270-290
IF NOT v_project_exists THEN
  RETURN jsonb_build_object(
    'success', false,
    'error', 'Project not found or unauthorized'
  );
END IF;

INSERT INTO app.whiteboard_renders (...) RETURNING id INTO v_render_id;

v_result := jsonb_build_object(
  'success', true,
  'render_id', v_render_id
);
```

### Contrat JSON (succès)

```json
{
  "success": true,
  "render_id": "uuid"
}
```

### Contrat JSON (erreur)

```json
{
  "success": false,
  "error": "Project not found or unauthorized"
}
```

### Clés exactes

| Clé | Type | Nullable | Source |
|-----|------|----------|--------|
| `success` | `boolean` | non | `jsonb_build_object` |
| `render_id` | `uuid` | non | `RETURNING id` |
| `error` | `text` | oui | erreur seulement |

---

## 7. `whiteboard_get_render_status`

### SQL

```sql
@.windsurf/create_missing_flutter_rpcs.sql:330-337
IF NOT FOUND THEN
  RETURN jsonb_build_object('success', false, 'error', 'Render not found');
END IF;

result := jsonb_build_object(
  'success', true,
  'render', to_jsonb(render_record)
);
```

### Contrat JSON (succès)

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

### Contrat JSON (erreur)

```json
{
  "success": false,
  "error": "Render not found"
}
```

### Clés exactes

| Clé | Type | Nullable | Source |
|-----|------|----------|--------|
| `success` | `boolean` | non | `jsonb_build_object` |
| `render` | `object` | non | `to_jsonb(render_record)` |
| `render.id` | `uuid` | non | table |
| `render.project_id` | `uuid` | non | table |
| `render.status` | `text` | non | table (DEFAULT 'queued') |
| `render.video_url` | `text` | oui | table |
| `render.duration_ms` | `integer` | oui | table |
| `render.file_size_bytes` | `bigint` | oui | table |
| `render.created_at` | `timestamptz` | non | table |
| `render.completed_at` | `timestamptz` | oui | table |
| `render.error_message` | `text` | oui | table |
| `render.progress` | `integer` | non | table (DEFAULT 0) |
| `error` | `text` | oui | erreur seulement |

---

## RÉSUMÉ DES MISMATCHES POTENTIELS

| RPC | Clé Flutter | Type Flutter | Type SQL | Statut |
|-----|-------------|--------------|----------|--------|
| `whiteboard_list_projects` | réponse directe | `List<dynamic>` | `Map` | ❌ MISMATCH |
| `whiteboard_get_project` | `project` | `Map` | `Map` | ✅ MATCH |
| `whiteboard_update_project` | `project` | `Map` | `Map` | ✅ MATCH |
| `whiteboard_create_project` | `project_id` | `String` | `uuid` | ✅ MATCH |
| `whiteboard_create_render_job` | `render_id` | `String` | `uuid` | ✅ MATCH |
| `whiteboard_get_render_status` | `render` | `Map` | `Map` | ✅ MATCH |
| `whiteboard_delete_project` | `success` | `bool` | `bool` | ✅ MATCH |

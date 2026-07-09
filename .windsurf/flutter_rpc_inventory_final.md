# FLUTTER RPC INVENTORY FINAL - WHITEBOARD

**Date**: 2026-06-26
**Version app**: 1.0.6+11
**Source**: `academia_app/lib/features/challenge/smart_whiteboard/`

---

## MÉTHODOLOGIE

Analyse exhaustive des appels `_supabase.rpc(...)` et `client.rpc(...)` dans le dossier `smart_whiteboard/`.

Fichiers analysés:
- `services/smart_whiteboard_service.dart`
- `services/smart_whiteboard_render_service.dart`
- `providers/smart_whiteboard_provider.dart`

---

## 1. whiteboard_create_project

**Fichier**: `services/smart_whiteboard_service.dart`
**Ligne**: 24

### Appel Flutter

```dart
final response = await _supabase.rpc(
  'whiteboard_create_project',
  params: {
    'p_student_id': _supabase.auth.currentUser?.id,
    'p_subject': subject,
    'p_renderer_id': rendererId,
    'p_theme_id': themeId,
    'p_narration_mode': narrationMode,
    'p_storyboard_json': storyboardJson ?? {},
  },
);
```

### Paramètres

| Paramètre | Type Dart | Type SQL | Obligatoire |
|-----------|-----------|----------|-------------|
| p_student_id | String? | uuid | Oui (si auth) |
| p_subject | String | text | Oui |
| p_renderer_id | String | text | Oui |
| p_theme_id | String | text | Oui |
| p_narration_mode | String | text | Oui (défaut: 'none') |
| p_storyboard_json | Map<String, dynamic>? | jsonb | Non (défaut: {}) |

### Signature SQL attendue

```sql
CREATE OR REPLACE FUNCTION public.whiteboard_create_project(
  p_student_id uuid,
  p_subject text,
  p_renderer_id text,
  p_theme_id text,
  p_narration_mode text,
  p_storyboard_json jsonb DEFAULT '{}'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
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
$$;
```

---

## 2. whiteboard_get_project

**Fichier**: `services/smart_whiteboard_service.dart`
**Ligne**: 41

### Appel Flutter

```dart
final response = await _supabase.rpc(
  'whiteboard_get_project',
  params: {
    'p_project_id': projectId,
  },
);
```

### Paramètres

| Paramètre | Type Dart | Type SQL | Obligatoire |
|-----------|-----------|----------|-------------|
| p_project_id | String | uuid | Oui |

### Signature SQL attendue

```sql
CREATE OR REPLACE FUNCTION public.whiteboard_get_project(
  p_project_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
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
$$;
```

---

## 3. whiteboard_update_project

**Fichier**: `services/smart_whiteboard_service.dart`
**Ligne**: 61

### Appel Flutter

```dart
final response = await _supabase.rpc(
  'whiteboard_update_project',
  params: {
    'p_project_id': projectId,
    'p_subject': subject,
    'p_status': status,
    'p_renderer_id': rendererId,
    'p_theme_id': themeId,
    'p_narration_mode': narrationMode,
    'p_storyboard_json': storyboardJson,
  },
);
```

### Paramètres

| Paramètre | Type Dart | Type SQL | Obligatoire |
|-----------|-----------|----------|-------------|
| p_project_id | String | uuid | Oui |
| p_subject | String? | text | Non |
| p_status | String? | text | Non |
| p_renderer_id | String? | text | Non |
| p_theme_id | String? | text | Non |
| p_narration_mode | String? | text | Non |
| p_storyboard_json | Map<String, dynamic>? | jsonb | Non |

### Signature SQL attendue

```sql
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
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  project_record RECORD;
  result JSONB;
BEGIN
  UPDATE app.whiteboard_projects
  SET 
    subject = COALESCE(p_subject, subject),
    status = COALESCE(p_status, status),
    renderer_id = COALESCE(p_renderer_id, renderer_id),
    theme_id = COALESCE(p_theme_id, theme_id),
    narration_mode = COALESCE(p_narration_mode, narration_mode),
    storyboard_json = COALESCE(p_storyboard_json, storyboard_json),
    updated_at = NOW()
  WHERE id = p_project_id
  AND student_id = auth.uid()
  RETURNING * INTO project_record;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Project not found');
  END IF;

  result := jsonb_build_object(
    'success', true,
    'project', to_jsonb(project_record)
  );

  RETURN result;
END;
$$;
```

---

## 4. whiteboard_list_projects

**Fichiers**:
- `services/smart_whiteboard_service.dart` ligne 79
- `providers/smart_whiteboard_provider.dart` ligne 531

### Appel Flutter #1 (avec status)

```dart
final response = await _supabase.rpc(
  'whiteboard_list_projects',
  params: {
    'p_status': status,
  },
);
```

### Appel Flutter #2 (sans paramètre)

```dart
final response = await client.rpc('whiteboard_list_projects');
```

### Paramètres

| Paramètre | Type Dart | Type SQL | Obligatoire |
|-----------|-----------|----------|-------------|
| p_status | String? | text | Non |

### Signature SQL attendue

```sql
CREATE OR REPLACE FUNCTION public.whiteboard_list_projects(
  p_status text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  projects JSONB;
  result JSONB;
BEGIN
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

  RETURN result;
END;
$$;
```

---

## 5. whiteboard_delete_project

**Fichier**: `services/smart_whiteboard_service.dart`
**Ligne**: 91

### Appel Flutter

```dart
final response = await _supabase.rpc(
  'whiteboard_delete_project',
  params: {
    'p_project_id': projectId,
  },
);
```

### Paramètres

| Paramètre | Type Dart | Type SQL | Obligatoire |
|-----------|-----------|----------|-------------|
| p_project_id | String | uuid | Oui |

### Signature SQL attendue

```sql
CREATE OR REPLACE FUNCTION public.whiteboard_delete_project(
  p_project_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result JSONB;
BEGIN
  DELETE FROM app.whiteboard_projects
  WHERE id = p_project_id
  AND student_id = auth.uid();

  result := jsonb_build_object(
    'success', true,
    'message', 'Project deleted'
  );

  RETURN result;
END;
$$;
```

---

## 6. whiteboard_create_render_job

**Fichier**: `services/smart_whiteboard_render_service.dart`
**Ligne**: 18

### Appel Flutter

```dart
final response = await _supabase.rpc(
  'whiteboard_create_render_job',
  params: {
    'p_project_id': projectId,
  },
);
```

### Paramètres

| Paramètre | Type Dart | Type SQL | Obligatoire |
|-----------|-----------|----------|-------------|
| p_project_id | String | uuid | Oui |

### Signature SQL attendue

```sql
CREATE OR REPLACE FUNCTION public.whiteboard_create_render_job(
  p_project_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_render_id uuid;
  v_project_exists boolean;
  v_result jsonb;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM app.whiteboard_projects
    WHERE id = p_project_id AND student_id = auth.uid()
  ) INTO v_project_exists;

  IF NOT v_project_exists THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Project not found or unauthorized'
    );
  END IF;

  INSERT INTO app.whiteboard_renders (
    project_id,
    status,
    progress
  ) VALUES (
    p_project_id,
    'queued',
    0
  )
  RETURNING id INTO v_render_id;

  v_result := jsonb_build_object(
    'success', true,
    'render_id', v_render_id
  );

  RETURN v_result;
END;
$$;
```

---

## 7. whiteboard_get_render_status

**Fichier**: `services/smart_whiteboard_render_service.dart`
**Ligne**: 30

### Appel Flutter

```dart
final response = await _supabase.rpc(
  'whiteboard_get_render_status',
  params: {
    'p_render_id': renderId,
  },
);
```

### Paramètres

| Paramètre | Type Dart | Type SQL | Obligatoire |
|-----------|-----------|----------|-------------|
| p_render_id | String | uuid | Oui |

### Signature SQL attendue

```sql
CREATE OR REPLACE FUNCTION public.whiteboard_get_render_status(
  p_render_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  render_record RECORD;
  result JSONB;
BEGIN
  SELECT 
    wr.id,
    wr.project_id,
    wr.status,
    wr.video_url,
    wr.duration_ms,
    wr.file_size_bytes,
    wr.created_at,
    wr.completed_at,
    wr.error_message,
    wr.progress
  INTO render_record
  FROM app.whiteboard_renders wr
  JOIN app.whiteboard_projects wp ON wr.project_id = wp.id
  WHERE wr.id = p_render_id
  AND wp.student_id = auth.uid();

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Render not found');
  END IF;

  result := jsonb_build_object(
    'success', true,
    'render', to_jsonb(render_record)
  );

  RETURN result;
END;
$$;
```

---

## SYNTHÈSE

| # | RPC | Fichier | Ligne | Paramètres | Schéma | Statut |
|---|-----|---------|-------|------------|--------|--------|
| 1 | whiteboard_create_project | smart_whiteboard_service.dart | 24 | 6 | public | MISSING |
| 2 | whiteboard_get_project | smart_whiteboard_service.dart | 41 | 1 | public | MISSING |
| 3 | whiteboard_update_project | smart_whiteboard_service.dart | 61 | 7 | public | MISSING |
| 4 | whiteboard_list_projects | smart_whiteboard_service.dart | 79 | 1 optionnel | public | MISSING |
| 4 | whiteboard_list_projects | smart_whiteboard_provider.dart | 531 | 0 | public | MISSING |
| 5 | whiteboard_delete_project | smart_whiteboard_service.dart | 91 | 1 | public | MISSING |
| 6 | whiteboard_create_render_job | smart_whiteboard_render_service.dart | 18 | 1 | public | MISSING |
| 7 | whiteboard_get_render_status | smart_whiteboard_render_service.dart | 30 | 1 | public | MISSING |

---

## RÈGLE

Ces 7 RPCs sont appelées par Flutter. Aucune n'existe dans `pg_proc` avec la signature exacte attendue après le nettoyage D.13. Elles doivent être créées dans le schéma `public` sans overload, sans doublon, sans aucune version dans `app`.

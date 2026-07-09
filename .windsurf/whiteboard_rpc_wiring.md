# WHITEBOARD RPC WIRING

## CARTOGRAPHIE DES APPELS FLUTTER → SUPABASE

---

### whiteboard_create_project

**FICHIER FLUTTER**:
`academia_app/lib/features/challenge/smart_whiteboard/services/smart_whiteboard_service.dart`

**LIGNE**: 24

**CODE FLUTTER**:
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

**RPC APPELÉE**: `public.whiteboard_create_project`

**SIGNATURE ATTENDUE**:
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

**SCHÉMA ATTENDU**: public

---

### whiteboard_get_project

**FICHIER FLUTTER**:
`academia_app/lib/features/challenge/smart_whiteboard/services/smart_whiteboard_service.dart`

**LIGNE**: 41

**CODE FLUTTER**:
```dart
final response = await _supabase.rpc(
  'whiteboard_get_project',
  params: {
    'p_project_id': projectId,
  },
);
```

**RPC APPELÉE**: `public.whiteboard_get_project`

**SIGNATURE ATTENDUE**:
```sql
(
  p_project_id uuid
)
RETURNS jsonb
```

**SCHÉMA ATTENDU**: public

---

### whiteboard_update_project

**FICHIER FLUTTER**:
`academia_app/lib/features/challenge/smart_whiteboard/services/smart_whiteboard_service.dart`

**LIGNE**: 61

**CODE FLUTTER**:
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

**RPC APPELÉE**: `public.whiteboard_update_project`

**SIGNATURE ATTENDUE**:
```sql
(
  p_project_id uuid,
  p_subject text,
  p_status text,
  p_renderer_id text,
  p_theme_id text,
  p_narration_mode text,
  p_storyboard_json jsonb
)
RETURNS jsonb
```

**SCHÉMA ATTENDU**: public

---

### whiteboard_list_projects

**FICHIER FLUTTER**:
`academia_app/lib/features/challenge/smart_whiteboard/services/smart_whiteboard_service.dart`

**LIGNE**: 79

**CODE FLUTTER**:
```dart
final response = await _supabase.rpc(
  'whiteboard_list_projects',
  params: {
    'p_status': status,
  },
);
```

**RPC APPELÉE**: `public.whiteboard_list_projects`

**SIGNATURE ATTENDUE**:
```sql
(
  p_status text
)
RETURNS jsonb
```

**SCHÉMA ATTENDU**: public

---

### whiteboard_delete_project

**FICHIER FLUTTER**:
`academia_app/lib/features/challenge/smart_whiteboard/services/smart_whiteboard_service.dart`

**LIGNE**: 91

**CODE FLUTTER**:
```dart
final response = await _supabase.rpc(
  'whiteboard_delete_project',
  params: {
    'p_project_id': projectId,
  },
);
```

**RPC APPELÉE**: `public.whiteboard_delete_project`

**SIGNATURE ATTENDUE**:
```sql
(
  p_project_id uuid
)
RETURNS jsonb
```

**SCHÉMA ATTENDU**: public

---

### whiteboard_create_render_job

**FICHIER FLUTTER**:
`academia_app/lib/features/challenge/smart_whiteboard/services/smart_whiteboard_render_service.dart`

**LIGNE**: 18

**CODE FLUTTER**:
```dart
final response = await _supabase.rpc(
  'whiteboard_create_render_job',
  params: {
    'p_project_id': projectId,
  },
);
```

**RPC APPELÉE**: `public.whiteboard_create_render_job`

**SIGNATURE ATTENDUE**:
```sql
(
  p_project_id uuid
)
RETURNS jsonb
```

**SCHÉMA ATTENDU**: public

---

### whiteboard_get_render_status

**FICHIER FLUTTER**:
`academia_app/lib/features/challenge/smart_whiteboard/services/smart_whiteboard_render_service.dart`

**LIGNE**: 30

**CODE FLUTTER**:
```dart
final response = await _supabase.rpc(
  'whiteboard_get_render_status',
  params: {
    'p_render_id': renderId,
  },
);
```

**RPC APPELÉE**: `public.whiteboard_get_render_status`

**SIGNATURE ATTENDUE**:
```sql
(
  p_render_id uuid
)
RETURNS jsonb
```

**SCHÉMA ATTENDU**: public

---

## CARTOGRAPHIE DES APPELS WORKER PYTHON → SUPABASE

---

### whiteboard_fetch_queued_jobs

**UTILISÉ PAR**: Worker Python (backend)

**RPC APPELÉE**: `public.whiteboard_fetch_queued_jobs`

**SIGNATURE ATTENDUE**:
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

**SCHÉMA ATTENDU**: public

---

### whiteboard_mark_processing

**UTILISÉ PAR**: Worker Python (backend)

**RPC APPELÉE**: `public.whiteboard_mark_processing`

**SIGNATURE ATTENDUE**:
```sql
(
  p_job_id uuid
)
RETURNS void
```

**SCHÉMA ATTENDU**: public

---

### whiteboard_mark_done

**UTILISÉ PAR**: Worker Python (backend)

**RPC APPELÉE**: `public.whiteboard_mark_done`

**SIGNATURE ATTENDUE**:
```sql
(
  p_job_id uuid,
  p_video_url text,
  p_duration_ms integer
)
RETURNS void
```

**SCHÉMA ATTENDU**: public

---

### whiteboard_mark_failed

**UTILISÉ PAR**: Worker Python (backend)

**RPC APPELÉE**: `public.whiteboard_mark_failed`

**SIGNATURE ATTENDUE**:
```sql
(
  p_job_id uuid,
  p_error_message text
)
RETURNS void
```

**SCHÉMA ATTENDU**: public

---

### whiteboard_get_any_student_id

**UTILISÉ PAR**: Worker Python (backend)

**RPC APPELÉE**: `public.whiteboard_get_any_student_id`

**SIGNATURE ATTENDUE**:
```sql
()
RETURNS uuid
```

**SCHÉMA ATTENDU**: public

---

## RÉSUMÉ

**Total RPCs appelées par Flutter**: 7
**Total RPCs appelées par Worker Python**: 5
**Total RPCs uniques**: 12

**Toutes les RPCs doivent être dans le schéma public** pour être accessibles via PostgREST.

**Aucun doublon détecté** dans les appels Flutter - chaque RPC a un nom unique.

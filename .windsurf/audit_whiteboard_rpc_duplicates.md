# AUDIT WHITEBOARD RPC DUPLICATES

## ÉTAT ACTUEL SUPABASE

**Date**: 2026-06-25
**Nombre total de fonctions whiteboard trouvées dans Supabase**: 0

**Conclusion**: AUCUNE RPC whiteboard n'existe actuellement dans la base de données.

---

## RPCs ATTENDUES PAR FLUTTER

### whiteboard_create_project

**Fichier source**: `academia_app/lib/features/challenge/smart_whiteboard/services/smart_whiteboard_service.dart` (ligne 24)

**Appel Flutter**:
```dart
_supabase.rpc(
  'whiteboard_create_project',
  params: {
    'p_student_id': _supabase.auth.currentUser?.id,
    'p_subject': subject,
    'p_renderer_id': rendererId,
    'p_theme_id': themeId,
    'p_narration_mode': narrationMode,
    'p_storyboard_json': storyboardJson ?? {},
  },
)
```

**Signature attendue**:
```
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

**État dans Supabase**: ❌ N'EXISTE PAS

**Décision**: KEEP (à créer)

---

### whiteboard_get_project

**Fichier source**: `academia_app/lib/features/challenge/smart_whiteboard/services/smart_whiteboard_service.dart` (ligne 41)

**Appel Flutter**:
```dart
_supabase.rpc(
  'whiteboard_get_project',
  params: {
    'p_project_id': projectId,
  },
)
```

**Signature attendue**:
```
(
  p_project_id uuid
)
RETURNS jsonb
```

**État dans Supabase**: ❌ N'EXISTE PAS

**Décision**: KEEP (à créer)

---

### whiteboard_update_project

**Fichier source**: `academia_app/lib/features/challenge/smart_whiteboard/services/smart_whiteboard_service.dart` (ligne 61)

**Appel Flutter**:
```dart
_supabase.rpc(
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
)
```

**Signature attendue**:
```
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

**État dans Supabase**: ❌ N'EXISTE PAS

**Décision**: KEEP (à créer)

---

### whiteboard_list_projects

**Fichier source**: `academia_app/lib/features/challenge/smart_whiteboard/services/smart_whiteboard_service.dart` (ligne 79)

**Appel Flutter**:
```dart
_supabase.rpc(
  'whiteboard_list_projects',
  params: {
    'p_status': status,
  },
)
```

**Signature attendue**:
```
(
  p_status text
)
RETURNS jsonb
```

**État dans Supabase**: ❌ N'EXISTE PAS

**Décision**: KEEP (à créer)

---

### whiteboard_delete_project

**Fichier source**: `academia_app/lib/features/challenge/smart_whiteboard/services/smart_whiteboard_service.dart` (ligne 91)

**Appel Flutter**:
```dart
_supabase.rpc(
  'whiteboard_delete_project',
  params: {
    'p_project_id': projectId,
  },
)
```

**Signature attendue**:
```
(
  p_project_id uuid
)
RETURNS jsonb
```

**État dans Supabase**: ❌ N'EXISTE PAS

**Décision**: KEEP (à créer)

---

### whiteboard_create_render_job

**Fichier source**: `academia_app/lib/features/challenge/smart_whiteboard/services/smart_whiteboard_render_service.dart` (ligne 18)

**Appel Flutter**:
```dart
_supabase.rpc(
  'whiteboard_create_render_job',
  params: {
    'p_project_id': projectId,
  },
)
```

**Signature attendue**:
```
(
  p_project_id uuid
)
RETURNS jsonb
```

**État dans Supabase**: ❌ N'EXISTE PAS

**Décision**: KEEP (à créer)

---

### whiteboard_get_render_status

**Fichier source**: `academia_app/lib/features/challenge/smart_whiteboard/services/smart_whiteboard_render_service.dart` (ligne 30)

**Appel Flutter**:
```dart
_supabase.rpc(
  'whiteboard_get_render_status',
  params: {
    'p_render_id': renderId,
  },
)
```

**Signature attendue**:
```
(
  p_render_id uuid
)
RETURNS jsonb
```

**État dans Supabase**: ❌ N'EXISTE PAS

**Décision**: KEEP (à créer)

---

## RPCs WORKER (pour worker Python)

### whiteboard_fetch_queued_jobs

**Utilisée par**: Worker Python (backend)

**Signature attendue**:
```
(
  p_limit integer DEFAULT 5
)
RETURNS TABLE (
  id uuid,
  storyboard jsonb,
  created_at timestamptz
)
```

**État dans Supabase**: ❌ N'EXISTE PAS

**Décision**: KEEP (à créer)

---

### whiteboard_mark_processing

**Utilisée par**: Worker Python (backend)

**Signature attendue**:
```
(
  p_job_id uuid
)
RETURNS void
```

**État dans Supabase**: ❌ N'EXISTE PAS

**Décision**: KEEP (à créer)

---

### whiteboard_mark_done

**Utilisée par**: Worker Python (backend)

**Signature attendue**:
```
(
  p_job_id uuid,
  p_video_url text,
  p_duration_ms integer
)
RETURNS void
```

**État dans Supabase**: ❌ N'EXISTE PAS

**Décision**: KEEP (à créer)

---

### whiteboard_mark_failed

**Utilisée par**: Worker Python (backend)

**Signature attendue**:
```
(
  p_job_id uuid,
  p_error_message text
)
RETURNS void
```

**État dans Supabase**: ❌ N'EXISTE PAS

**Décision**: KEEP (à créer)

---

### whiteboard_get_any_student_id

**Utilisée par**: Worker Python (backend)

**Signature attendue**:
```
()
RETURNS uuid
```

**État dans Supabase**: ❌ N'EXISTE PAS

**Décision**: KEEP (à créer)

---

## RÉSUMÉ

**Total RPCs à créer**: 12
**Total RPCs à supprimer**: 0
**Doublons détectés**: 0

**Problème PGRST203**: Non applicable (aucune fonction n'existe)

**Action requise**: Déployer les 12 RPCs via les scripts SQL prévus.

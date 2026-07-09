# FLUTTER RPC CONTRACTS - SMART WHITEBOARD

**Date**: 2026-06-26
**Dossier scruté**: `academia_app/lib/features/challenge/smart_whiteboard/`
**Méthode**: Recherche de tous les appels `.rpc(...)`

---

## APPELS RPC TROUVÉS

### 1. whiteboard_create_project

**FICHIER**: `academia_app/lib/features/challenge/smart_whiteboard/services/smart_whiteboard_service.dart`

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

**RPC**: `whiteboard_create_project`

**PARAMÈTRES**:
| Paramètre | Type Dart | Requis | Valeur |
|-----------|-----------|--------|--------|
| p_student_id | String? | Oui | `_supabase.auth.currentUser?.id` |
| p_subject | String | Oui | `subject` |
| p_renderer_id | String | Oui | `rendererId` |
| p_theme_id | String | Oui | `themeId` |
| p_narration_mode | String | Oui | `narrationMode` (default 'none') |
| p_storyboard_json | Map<String, dynamic>? | Non | `storyboardJson ?? {}` |

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

**SCHÉMA ATTENDU**: `public`

**VALEUR DE RETOUR ATTENDUE**:
```json
{
  "success": true,
  "project_id": "uuid"
}
```

**UTILISÉ PAR**:
- `SmartWhiteboardService.createProject()`
- `SmartWhiteboardProvider.createProject()` (ligne 88)

---

### 2. whiteboard_get_project

**FICHIER**: `academia_app/lib/features/challenge/smart_whiteboard/services/smart_whiteboard_service.dart`

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

**RPC**: `whiteboard_get_project`

**PARAMÈTRES**:
| Paramètre | Type Dart | Requis | Valeur |
|-----------|-----------|--------|--------|
| p_project_id | String | Oui | `projectId` |

**SIGNATURE ATTENDUE**:
```sql
(
  p_project_id uuid
)
RETURNS jsonb
```

**SCHÉMA ATTENDU**: `public`

**VALEUR DE RETOUR ATTENDUE**:
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

**UTILISÉ PAR**:
- `SmartWhiteboardService.getProject()`

---

### 3. whiteboard_update_project

**FICHIER**: `academia_app/lib/features/challenge/smart_whiteboard/services/smart_whiteboard_service.dart`

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

**RPC**: `whiteboard_update_project`

**PARAMÈTRES**:
| Paramètre | Type Dart | Requis | Valeur |
|-----------|-----------|--------|--------|
| p_project_id | String | Oui | `projectId` |
| p_subject | String? | Non | `subject` |
| p_status | String? | Non | `status` |
| p_renderer_id | String? | Non | `rendererId` |
| p_theme_id | String? | Non | `themeId` |
| p_narration_mode | String? | Non | `narrationMode` |
| p_storyboard_json | Map<String, dynamic>? | Non | `storyboardJson` |

**SIGNATURE ATTENDUE**:
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

**SCHÉMA ATTENDU**: `public`

**VALEUR DE RETOUR ATTENDUE**:
```json
{
  "success": true,
  "project": { ... }
}
```

**UTILISÉ PAR**:
- `SmartWhiteboardService.updateProject()`

---

### 4. whiteboard_list_projects

**FICHIER**: `academia_app/lib/features/challenge/smart_whiteboard/services/smart_whiteboard_service.dart`

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

**RPC**: `whiteboard_list_projects`

**PARAMÈTRES**:
| Paramètre | Type Dart | Requis | Valeur |
|-----------|-----------|--------|--------|
| p_status | String? | Non | `status` |

**SIGNATURE ATTENDUE**:
```sql
(
  p_status text DEFAULT NULL
)
RETURNS jsonb
```

**SCHÉMA ATTENDU**: `public`

**VALEUR DE RETOUR ATTENDUE**:
```json
{
  "success": true,
  "projects": [ ... ]
}
```

**UTILISÉ PAR**:
- `SmartWhiteboardService.listProjects()`

---

### 5. whiteboard_delete_project

**FICHIER**: `academia_app/lib/features/challenge/smart_whiteboard/services/smart_whiteboard_service.dart`

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

**RPC**: `whiteboard_delete_project`

**PARAMÈTRES**:
| Paramètre | Type Dart | Requis | Valeur |
|-----------|-----------|--------|--------|
| p_project_id | String | Oui | `projectId` |

**SIGNATURE ATTENDUE**:
```sql
(
  p_project_id uuid
)
RETURNS jsonb
```

**SCHÉMA ATTENDU**: `public`

**VALEUR DE RETOUR ATTENDUE**:
```json
{
  "success": true,
  "message": "Project deleted"
}
```

**UTILISÉ PAR**:
- `SmartWhiteboardService.deleteProject()`

---

### 6. whiteboard_create_render_job

**FICHIER**: `academia_app/lib/features/challenge/smart_whiteboard/services/smart_whiteboard_render_service.dart`

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

**RPC**: `whiteboard_create_render_job`

**PARAMÈTRES**:
| Paramètre | Type Dart | Requis | Valeur |
|-----------|-----------|--------|--------|
| p_project_id | String | Oui | `projectId` |

**SIGNATURE ATTENDUE**:
```sql
(
  p_project_id uuid
)
RETURNS jsonb
```

**SCHÉMA ATTENDU**: `public`

**VALEUR DE RETOUR ATTENDUE**:
```json
{
  "success": true,
  "render_id": "uuid"
}
```

**UTILISÉ PAR**:
- `SmartWhiteboardRenderService.createRenderJob()`

---

### 7. whiteboard_get_render_status

**FICHIER**: `academia_app/lib/features/challenge/smart_whiteboard/services/smart_whiteboard_render_service.dart`

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

**RPC**: `whiteboard_get_render_status`

**PARAMÈTRES**:
| Paramètre | Type Dart | Requis | Valeur |
|-----------|-----------|--------|--------|
| p_render_id | String | Oui | `renderId` |

**SIGNATURE ATTENDUE**:
```sql
(
  p_render_id uuid
)
RETURNS jsonb
```

**SCHÉMA ATTENDU**: `public`

**VALEUR DE RETOUR ATTENDUE**:
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

**UTILISÉ PAR**:
- `SmartWhiteboardRenderService.getRenderStatus()`
- `SmartWhiteboardRenderService.waitForRenderCompletion()` (ligne 57)
- `SmartWhiteboardRenderService.getRenderVideoUrl()` (ligne 73)

---

## SYNTHÈSE DES RPCs ATTENDUES PAR FLUTTER

| RPC | Schéma | Paramètres | Appelant | Statut |
|-----|--------|------------|----------|--------|
| whiteboard_create_project | public | 6 paramètres | SmartWhiteboardService | MANQUANT/DOUBLON |
| whiteboard_get_project | public | 1 paramètre | SmartWhiteboardService | MANQUANT/DOUBLON |
| whiteboard_update_project | public | 7 paramètres | SmartWhiteboardService | MANQUANT/DOUBLON |
| whiteboard_list_projects | public | 1 paramètre optionnel | SmartWhiteboardService | MANQUANT/DOUBLON |
| whiteboard_delete_project | public | 1 paramètre | SmartWhiteboardService | MANQUANT/DOUBLON |
| whiteboard_create_render_job | public | 1 paramètre | SmartWhiteboardRenderService | MANQUANT |
| whiteboard_get_render_status | public | 1 paramètre | SmartWhiteboardRenderService | MANQUANT |

**RÉSEAU D'APPELS**:
- `SmartWhiteboardProvider` appelle `SmartWhiteboardService`
- `SmartWhiteboardService` appelle `_supabase.rpc()`
- `SmartWhiteboardRenderService` appelle `_supabase.rpc()`
- Aucun appel direct RPC dans le Provider (sauf via les services)

**RÈGLE**: Chaque RPC appelée par Flutter DOIT exister dans le schéma public avec la signature exacte attendue. Aucune RPC dans le schéma app ne peut être appelée directement par Flutter via PostgREST.

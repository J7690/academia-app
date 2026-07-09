# D.18.1 – PHASE 1: INVENTAIRE DES CONSOMMATEURS JSON FLUTTER

**Date**: 2026-06-26
**Mission**: D.18.1
**Dossier scanné**: `academia_app/lib/features/challenge/smart_whiteboard/`

---

## 1. CONSOMMATEURS DANS `smart_whiteboard_provider.dart`

### 1.1 `createProject()`

- **Fichier**: `providers/smart_whiteboard_provider.dart`
- **Lignes**: 97-100
- **Code**:
  ```dart
  if (result['success'] == true) {
    _currentProjectId = result['project_id'] as String;
  }
  ```
- **Clé attendue**: `project_id`
- **Type attendu**: `String`
- **Nullable**: non

### 1.2 `generateStoryboard()` – erreurs Edge Function

- **Fichier**: `providers/smart_whiteboard_provider.dart`
- **Lignes**: 149-161
- **Code**:
  ```dart
  final errorData = response.data as Map<String, dynamic>?;
  if (errorData?['error'] == 'insufficient_credits') { ... }
  else if (errorData?['error'] == 'invalid_json') { ... }
  else if (errorData?['error'] == 'invalid_storyboard') { ... }
  ```
- **Clé attendue**: `error`
- **Type attendu**: `String`
- **Nullable**: oui

### 1.3 `generateStoryboard()` – storyboard_json

- **Fichier**: `providers/smart_whiteboard_provider.dart`
- **Lignes**: 164-169
- **Code**:
  ```dart
  final data = response.data as Map<String, dynamic>;
  final storyboardJson = data['storyboard_json'] as Map<String, dynamic>?;
  ```
- **Clé attendue**: `storyboard_json`
- **Type attendu**: `Map<String, dynamic>`
- **Nullable**: oui

### 1.4 `updateStoryboard()`

- **Fichier**: `providers/smart_whiteboard_provider.dart`
- **Lignes**: 245-249
- **Code**:
  ```dart
  if (result['success'] == true) {
    _currentStoryboard = storyboard;
  } else {
    _setError(result['error'] as String? ?? 'Failed to update storyboard');
  }
  ```
- **Clé attendue**: `success`, `error`
- **Type attendu**: `bool`, `String?`
- **Nullable**: `error` est nullable

### 1.5 `createRenderJob()`

- **Fichier**: `providers/smart_whiteboard_provider.dart`
- **Lignes**: 458-462
- **Code**:
  ```dart
  if (result['success'] == true) {
    _currentRenderJobId = result['render_id'] as String;
  } else {
    _setError(result['error'] as String? ?? 'Failed to create render job');
  }
  ```
- **Clé attendue**: `render_id`
- **Type attendu**: `String`
- **Nullable**: non

### 1.6 `pollRenderJob()`

- **Fichier**: `providers/smart_whiteboard_provider.dart`
- **Lignes**: 480-487
- **Code**:
  ```dart
  final render = result['render'] as Map<String, dynamic>;
  final status = render['status'] as String;
  if (status == 'done') {
    _renderVideoUrl = render['video_url'] as String?;
  } else if (status == 'failed') {
    _setError(render['error_message'] as String? ?? 'Render failed');
  }
  ```
- **Clés attendues**: `render`, `render.status`, `render.video_url`, `render.error_message`
- **Types attendus**: `Map<String, dynamic>`, `String`, `String?`, `String?`
- **Nullable**: `video_url` et `error_message` sont nullable

### 1.7 `loadProjects()`

- **Fichier**: `providers/smart_whiteboard_provider.dart`
- **Lignes**: 531-534
- **Code**:
  ```dart
  final response = await client.rpc('whiteboard_list_projects');
  if (response != null) {
    _projects = response as List<dynamic>;
  }
  ```
- **Clé attendue**: aucune (la réponse elle-même est castée)
- **Type attendu**: `List<dynamic>`
- **Nullable**: non (géré par `if (response != null)`)

---

## 2. CONSOMMATEURS DANS `smart_whiteboard_service.dart`

### 2.1 `createProject()`

- **Fichier**: `services/smart_whiteboard_service.dart`
- **Ligne**: 24
- **Code**:
  ```dart
  final response = await _supabase.rpc(...);
  return response as Map<String, dynamic>;
  ```
- **Type attendu**: `Map<String, dynamic>`
- **Nullable**: non

### 2.2 `getProject()`

- **Fichier**: `services/smart_whiteboard_service.dart`
- **Ligne**: 41
- **Code**:
  ```dart
  return response as Map<String, dynamic>;
  ```
- **Type attendu**: `Map<String, dynamic>`
- **Nullable**: non

### 2.3 `updateProject()`

- **Fichier**: `services/smart_whiteboard_service.dart`
- **Ligne**: 61
- **Code**:
  ```dart
  return response as Map<String, dynamic>;
  ```
- **Type attendu**: `Map<String, dynamic>`
- **Nullable**: non

### 2.4 `listProjects()`

- **Fichier**: `services/smart_whiteboard_service.dart`
- **Ligne**: 79
- **Code**:
  ```dart
  return response as Map<String, dynamic>;
  ```
- **Type attendu**: `Map<String, dynamic>`
- **Nullable**: non

### 2.5 `deleteProject()`

- **Fichier**: `services/smart_whiteboard_service.dart`
- **Ligne**: 91
- **Code**:
  ```dart
  return response as Map<String, dynamic>;
  ```
- **Type attendu**: `Map<String, dynamic>`
- **Nullable**: non

---

## 3. CONSOMMATEURS DANS `smart_whiteboard_render_service.dart`

### 3.1 `createRenderJob()`

- **Fichier**: `services/smart_whiteboard_render_service.dart`
- **Ligne**: 18
- **Code**:
  ```dart
  return response as Map<String, dynamic>;
  ```
- **Type attendu**: `Map<String, dynamic>`
- **Nullable**: non

### 3.2 `getRenderStatus()`

- **Fichier**: `services/smart_whiteboard_render_service.dart`
- **Ligne**: 30
- **Code**:
  ```dart
  return response as Map<String, dynamic>;
  ```
- **Type attendu**: `Map<String, dynamic>`
- **Nullable**: non

### 3.3 `waitForRenderCompletion()`

- **Fichier**: `services/smart_whiteboard_render_service.dart`
- **Lignes**: 57-59
- **Code**:
  ```dart
  final status = await getRenderStatus(renderId);
  final render = status['render'] as Map<String, dynamic>;
  final renderStatus = render['status'] as String;
  ```
- **Clés attendues**: `render`, `render.status`
- **Types attendus**: `Map<String, dynamic>`, `String`
- **Nullable**: non

### 3.4 `getRenderVideoUrl()`

- **Fichier**: `services/smart_whiteboard_render_service.dart`
- **Lignes**: 73-81
- **Code**:
  ```dart
  final status = await getRenderStatus(renderId);
  final render = status['render'] as Map<String, dynamic>;
  final renderStatus = render['status'] as String;
  if (renderStatus != 'done') {
    return null;
  }
  return render['video_url'] as String?;
  ```
- **Clés attendues**: `render`, `render.status`, `render.video_url`
- **Types attendus**: `Map<String, dynamic>`, `String`, `String?`
- **Nullable**: `video_url` est nullable

---

## 4. CONSOMMATEURS DANS `storyboard_models.dart`

### 4.1 `Storyboard.fromJson`

- **Fichier**: `models/storyboard_models.dart`
- **Lignes**: 895-929
- **Clés attendues**:
  - `version`: `String`
  - `created_at`: `String`
  - `created_by`: `String`
  - `subject`: `String`
  - `renderer`: `String`
  - `theme`: `String`
  - `narration_mode`: `String`
  - `export_settings`: `Map<String, dynamic>`
  - `scenes`: `List<dynamic>`
- **Nullable**: toutes les clés sont non-nullables (casts non-nullables)

### 4.2 `ExportSettings.fromJson`

- **Fichier**: `models/storyboard_models.dart`
- **Lignes**: 94-109
- **Clés attendues**:
  - `format`: `String`
  - `resolution`: `Map<String, dynamic>`
  - `frame_rate`: `int`
  - `video_codec`: `String`
  - `audio_codec`: `String`
- **Nullable**: toutes les clés sont non-nullables

### 4.3 `Resolution.fromJson`

- **Fichier**: `models/storyboard_models.dart`
- **Lignes**: 145-149
- **Clés attendues**:
  - `width`: `int`
  - `height`: `int`
- **Nullable**: non

### 4.4 `Scene.fromJson`

- **Fichier**: `models/storyboard_models.dart`
- **Lignes**: 821-833
- **Clés attendues**:
  - `id`: `String`
  - `order`: `int`
  - `title`: `String`
  - `duration_ms`: `int`
  - `transition`: `Map<String, dynamic>?`
  - `blocks`: `List<dynamic>?`
- **Nullable**: `transition` et `blocks` sont nullable

### 4.5 `Block.fromJson`

- **Fichier**: `models/storyboard_models.dart`
- **Lignes**: 341-364
- **Clés attendues**:
  - `id`: `String`
  - `type`: `String`
  - `content`: `String`
  - `order`: `int`
  - `visible`: `bool`
  - `animation`: `Map<String, dynamic>?`
  - `position`: `Map<String, dynamic>?`
  - `style`: `Map<String, dynamic>?`
- **Nullable**: `animation`, `position`, `style` sont nullable

### 4.6 `WhiteboardProject.fromJson`

- **Fichier**: `models/storyboard_models.dart`
- **Lignes**: 1001-1029
- **Clés attendues**:
  - `id`: `String`
  - `student_id`: `String`
  - `subject`: `String`
  - `status`: `String`
  - `created_at`: `String`
  - `updated_at`: `String`
  - `renderer_id`: `String`
  - `theme_id`: `String`
  - `narration_mode`: `String`
  - `storyboard`: `Map<String, dynamic>`
- **Nullable**: non (mais pas utilisé dans le code actuel)

---

## 5. RÉSUMÉ

| Consommateur | Fichier | Ligne | Clé | Type attendu | Nullable |
|--------------|---------|-------|-----|--------------|----------|
| `createProject` | provider | 100 | `project_id` | `String` | non |
| `generateStoryboard` erreurs | provider | 152 | `error` | `String` | oui |
| `generateStoryboard` data | provider | 169 | `storyboard_json` | `Map<String, dynamic>` | oui |
| `updateStoryboard` | provider | 245 | `success` | `bool` | non |
| `updateStoryboard` | provider | 249 | `error` | `String` | oui |
| `createRenderJob` | provider | 459 | `render_id` | `String` | non |
| `pollRenderJob` | provider | 480 | `render` | `Map<String, dynamic>` | non |
| `pollRenderJob` | provider | 481 | `render.status` | `String` | non |
| `pollRenderJob` | provider | 484 | `render.video_url` | `String` | oui |
| `pollRenderJob` | provider | 487 | `render.error_message` | `String` | oui |
| `loadProjects` | provider | 531 | (réponse) | `List<dynamic>` | non |
| `Storyboard.fromJson` | models | 907 | `version` | `String` | non |
| `Storyboard.fromJson` | models | 908 | `created_at` | `String` | non |
| `Storyboard.fromJson` | models | 909 | `created_by` | `String` | non |
| `Storyboard.fromJson` | models | 910 | `subject` | `String` | non |
| `Storyboard.fromJson` | models | 911 | `renderer` | `String` | non |
| `Storyboard.fromJson` | models | 912 | `theme` | `String` | non |
| `Storyboard.fromJson` | models | 913 | `narration_mode` | `String` | non |
| `Storyboard.fromJson` | models | 923 | `export_settings` | `Map<String, dynamic>` | non |
| `Storyboard.fromJson` | models | 925 | `scenes` | `List<dynamic>` | oui |
| `ExportSettings.fromJson` | models | 104 | `format` | `String` | non |
| `ExportSettings.fromJson` | models | 105 | `resolution` | `Map<String, dynamic>` | non |
| `ExportSettings.fromJson` | models | 106 | `frame_rate` | `int` | non |
| `ExportSettings.fromJson` | models | 107 | `video_codec` | `String` | non |
| `ExportSettings.fromJson` | models | 108 | `audio_codec` | `String` | non |

---

## MISMATCH IDENTIFIÉ

- `loadProjects` ligne 531: attend `List<dynamic>` au lieu de `Map<String, dynamic>.projects`.

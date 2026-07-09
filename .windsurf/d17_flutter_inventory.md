# D.17 - PHASE 1: INVENTAIRE FLUTTER (SOURCE DE VÉRITÉ FRONT)

**Date**: 2026-06-26
**Mission**: D.17
**Dossier scanné**: `academia_app/lib/features/challenge/smart_whiteboard/`

---

## Méthode

Recherche des appels `.rpc()`, `functions.invoke()`, `Supabase.instance.client` dans le code source Flutter.

---

## Inventaire des appels

### 1. `whiteboard_create_project`

- **Fichier**: `academia_app/lib/features/challenge/smart_whiteboard/services/smart_whiteboard_service.dart`
- **Ligne**: 24
- **Type**: RPC
- **Nom exact utilisé**: `whiteboard_create_project`
- **Paramètres envoyés**:
  ```dart
  {
    'p_student_id': _supabase.auth.currentUser?.id,
    'p_subject': subject,
    'p_renderer_id': rendererId,
    'p_theme_id': themeId,
    'p_narration_mode': narrationMode,
    'p_storyboard_json': storyboardJson ?? {},
  }
  ```
- **Valeur de retour attendue**: `Map<String, dynamic>` avec `success` et `project_id`
- **Écran Flutter qui utilise cet appel**: `smart_whiteboard_input_screen.dart` via `SmartWhiteboardProvider.createProject`

---

### 2. `whiteboard_get_project`

- **Fichier**: `academia_app/lib/features/challenge/smart_whiteboard/services/smart_whiteboard_service.dart`
- **Ligne**: 41
- **Type**: RPC
- **Nom exact utilisé**: `whiteboard_get_project`
- **Paramètres envoyés**:
  ```dart
  { 'p_project_id': projectId }
  ```
- **Valeur de retour attendue**: `Map<String, dynamic>` avec `success` et `project`
- **Écran Flutter qui utilise cet appel**: `smart_whiteboard_storyboard_editor_screen.dart` (probablement)

---

### 3. `whiteboard_update_project`

- **Fichier**: `academia_app/lib/features/challenge/smart_whiteboard/services/smart_whiteboard_service.dart`
- **Ligne**: 61
- **Type**: RPC
- **Nom exact utilisé**: `whiteboard_update_project`
- **Paramètres envoyés**:
  ```dart
  {
    'p_project_id': projectId,
    'p_subject': subject,
    'p_status': status,
    'p_renderer_id': rendererId,
    'p_theme_id': themeId,
    'p_narration_mode': narrationMode,
    'p_storyboard_json': storyboardJson,
  }
  ```
- **Valeur de retour attendue**: `Map<String, dynamic>` avec `success` et `project`
- **Écran Flutter qui utilise cet appel**: `smart_whiteboard_storyboard_editor_screen.dart` via `SmartWhiteboardProvider.updateStoryboard`

---

### 4. `whiteboard_list_projects`

- **Fichier**: `academia_app/lib/features/challenge/smart_whiteboard/services/smart_whiteboard_service.dart`
- **Ligne**: 79
- **Type**: RPC
- **Nom exact utilisé**: `whiteboard_list_projects`
- **Paramètres envoyés**:
  ```dart
  { 'p_status': status }
  ```
- **Valeur de retour attendue**: `Map<String, dynamic>` avec `success` et `projects`
- **Écran Flutter qui utilise cet appel**: `smart_whiteboard_projects_list_screen.dart` via `SmartWhiteboardProvider.loadProjects`

---

### 5. `whiteboard_delete_project`

- **Fichier**: `academia_app/lib/features/challenge/smart_whiteboard/services/smart_whiteboard_service.dart`
- **Ligne**: 91
- **Type**: RPC
- **Nom exact utilisé**: `whiteboard_delete_project`
- **Paramètres envoyés**:
  ```dart
  { 'p_project_id': projectId }
  ```
- **Valeur de retour attendue**: `Map<String, dynamic>` avec `success` et `message`
- **Écran Flutter qui utilise cet appel**: `smart_whiteboard_projects_list_screen.dart`

---

### 6. `whiteboard_create_render_job`

- **Fichier**: `academia_app/lib/features/challenge/smart_whiteboard/services/smart_whiteboard_render_service.dart`
- **Ligne**: 18
- **Type**: RPC
- **Nom exact utilisé**: `whiteboard_create_render_job`
- **Paramètres envoyés**:
  ```dart
  { 'p_project_id': projectId }
  ```
- **Valeur de retour attendue**: `Map<String, dynamic>` avec `success` et `render_id`
- **Écran Flutter qui utilise cet appel**: `smart_whiteboard_storyboard_editor_screen.dart` via `SmartWhiteboardProvider.createRenderJob`

---

### 7. `whiteboard_get_render_status`

- **Fichier**: `academia_app/lib/features/challenge/smart_whiteboard/services/smart_whiteboard_render_service.dart`
- **Ligne**: 30
- **Type**: RPC
- **Nom exact utilisé**: `whiteboard_get_render_status`
- **Paramètres envoyés**:
  ```dart
  { 'p_render_id': renderId }
  ```
- **Valeur de retour attendue**: `Map<String, dynamic>` avec `success` et `render`
- **Écran Flutter qui utilise cet appel**: `smart_whiteboard_storyboard_editor_screen.dart` via `SmartWhiteboardProvider.pollRenderJob`

---

### 8. `whiteboard_list_projects` (appel direct)

- **Fichier**: `academia_app/lib/features/challenge/smart_whiteboard/providers/smart_whiteboard_provider.dart`
- **Ligne**: 531
- **Type**: RPC
- **Nom exact utilisé**: `whiteboard_list_projects`
- **Paramètres envoyés**: aucun
- **Valeur de retour attendue**: `List<dynamic>`
- **Écran Flutter qui utilise cet appel**: `smart_whiteboard_projects_list_screen.dart`

---

### 9. Edge Function `whiteboard-generate-storyboard`

- **Fichier**: `academia_app/lib/features/challenge/smart_whiteboard/providers/smart_whiteboard_provider.dart`
- **Ligne**: 133
- **Type**: EDGE FUNCTION
- **Nom exact utilisé**: `whiteboard-generate-storyboard`
- **Paramètres envoyés**:
  ```dart
  {
    'mode': mode,
    'subject': _currentProject?.subject ?? '',
    'content': content,
    'renderer': _currentProject?.rendererId ?? 'scientific',
    'theme': _currentProject?.themeId ?? 'scientific',
    'narration_mode': _currentProject?.narrationMode ?? 'none',
  }
  ```
- **Valeur de retour attendue**: `Map<String, dynamic>` avec `storyboard_json`
- **Écran Flutter qui utilise cet appel**: `smart_whiteboard_input_screen.dart` via `SmartWhiteboardProvider.generateStoryboard`

---

## Résumé

| # | Type | Nom | Fichier | Ligne |
|---|------|-----|---------|-------|
| 1 | RPC | `whiteboard_create_project` | `services/smart_whiteboard_service.dart` | 24 |
| 2 | RPC | `whiteboard_get_project` | `services/smart_whiteboard_service.dart` | 41 |
| 3 | RPC | `whiteboard_update_project` | `services/smart_whiteboard_service.dart` | 61 |
| 4 | RPC | `whiteboard_list_projects` | `services/smart_whiteboard_service.dart` | 79 |
| 5 | RPC | `whiteboard_delete_project` | `services/smart_whiteboard_service.dart` | 91 |
| 6 | RPC | `whiteboard_create_render_job` | `services/smart_whiteboard_render_service.dart` | 18 |
| 7 | RPC | `whiteboard_get_render_status` | `services/smart_whiteboard_render_service.dart` | 30 |
| 8 | RPC | `whiteboard_list_projects` | `providers/smart_whiteboard_provider.dart` | 531 |
| 9 | EDGE FUNCTION | `whiteboard-generate-storyboard` | `providers/smart_whiteboard_provider.dart` | 133 |

---

## Notes

- Aucun appel direct à `storage.from()` n'a été trouvé dans le module Smart Whiteboard.
- Aucun appel direct à une table (`from()`) n'a été trouvé dans le module Smart Whiteboard.
- Tous les appels passent par des RPC ou l'Edge Function.

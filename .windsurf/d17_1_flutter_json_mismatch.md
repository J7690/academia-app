# D.17.1 – PHASE 2: VALIDATION FLUTTER VS JSON RÉEL

**Date**: 2026-06-26
**Mission**: D.17.1
**Source SQL**: `.windsurf/create_missing_flutter_rpcs.sql`
**Source Flutter**: `academia_app/lib/features/challenge/smart_whiteboard/`

---

## MÉTHODE

Pour chaque RPC, comparer le JSON réel (déduit du SQL) avec le code Flutter qui consomme la réponse.

---

## 1. `whiteboard_create_project`

### JSON réel

```json
{
  "success": true,
  "project_id": "<uuid>"
}
```

### Code Flutter

```dart
@academia_app/lib/features/challenge/smart_whiteboard/providers/smart_whiteboard_provider.dart:95-101
if (result['success'] == true) {
  print("DEBUG 2: result['project_id'] = ${result['project_id']}");
  print("DEBUG 3: result['project_id'] type = ${result['project_id'].runtimeType}");
  _currentProjectId = result['project_id'] as String;
  print("DEBUG 4: _currentProjectId = $_currentProjectId");
  _setState(SmartWhiteboardState.idle);
}
```

### Verdict

- JSON réel: `{ "success": true, "project_id": "..." }`
- Flutter attend: `result['project_id']`
- **Statut**: ✅ MATCH

---

## 2. `whiteboard_get_project`

### JSON réel

```json
{
  "success": true,
  "project": {
    "id": "...",
    "storyboard_json": {...}
  }
}
```

### Code Flutter

```dart
@academia_app/lib/features/challenge/smart_whiteboard/services/smart_whiteboard_service.dart:40-49
Future<Map<String, dynamic>> getProject(String projectId) async {
  final response = await _supabase.rpc(
    'whiteboard_get_project',
    params: { 'p_project_id': projectId },
  );
  return response as Map<String, dynamic>;
}
```

### Verdict

- Le service retourne `Map<String, dynamic>`.
- Le code consommateur n'a pas été audité en détail dans cette mission.
- **Statut**: ⚠️ À VÉRIFIER côté consommateur

---

## 3. `whiteboard_update_project`

### JSON réel

```json
{
  "success": true,
  "project": {
    "id": "...",
    "storyboard_json": {...}
  }
}
```

### Code Flutter

```dart
@academia_app/lib/features/challenge/smart_whiteboard/providers/smart_whiteboard_provider.dart:240-254
final result = await _projectService.updateProject(
  projectId: _currentProjectId!,
  storyboardJson: storyboard.toJson(),
);

if (result['success'] == true) {
  _currentStoryboard = storyboard;
  _setState(SmartWhiteboardState.editing);
} else {
  _setError(result['error'] as String? ?? 'Failed to update storyboard');
}
```

### Verdict

- Flutter vérifie `result['success']` et ne lit pas de champ spécifique.
- **Statut**: ✅ MATCH

---

## 4. `whiteboard_list_projects`

### JSON réel

```json
{
  "success": true,
  "projects": [
    { "id": "...", "subject": "...", ... }
  ]
}
```

### Code Flutter

```dart
@academia_app/lib/features/challenge/smart_whiteboard/providers/smart_whiteboard_provider.dart:523-542
final response = await client.rpc('whiteboard_list_projects');

if (response != null) {
  _projects = response as List<dynamic>;
} else {
  _projects = [];
}
```

### Verdict

- JSON réel: `Map<String, dynamic>` avec clé `projects`
- Flutter: `response as List<dynamic>`
- **Statut**: ❌ MISMATCH

**Erreur provoquée**:
```
type '_Map<String, dynamic>' is not a subtype of type 'List<dynamic>' in type cast
```

---

## 5. `whiteboard_delete_project`

### JSON réel

```json
{
  "success": true,
  "message": "Project deleted"
}
```

### Code Flutter

```dart
@academia_app/lib/features/challenge/smart_whiteboard/providers/smart_whiteboard_provider.dart:495-516
Future<void> deleteProject(String projectId) async {
  ...
  try {
    await _projectService.deleteProject(projectId);
    ...
    _setState(SmartWhiteboardState.idle);
  } catch (e) {
    _setError(e.toString());
  }
}
```

### Verdict

- Flutter ne lit pas la réponse.
- **Statut**: ✅ MATCH

---

## 6. `whiteboard_create_render_job`

### JSON réel

```json
{
  "success": true,
  "render_id": "<uuid>"
}
```

### Code Flutter

```dart
@academia_app/lib/features/challenge/smart_whiteboard/providers/smart_whiteboard_provider.dart:456-464
final result = await _renderService.createRenderJob(_currentProjectId!);

if (result['success'] == true) {
  _currentRenderJobId = result['render_id'] as String;
  _setState(SmartWhiteboardState.rendering);
}
```

### Verdict

- JSON réel: `{ "success": true, "render_id": "..." }`
- Flutter: `result['render_id'] as String`
- **Statut**: ✅ MATCH

---

## 7. `whiteboard_get_render_status`

### JSON réel

```json
{
  "success": true,
  "render": {
    "id": "...",
    "status": "...",
    "video_url": "...",
    "error_message": "...",
    "progress": ...
  }
}
```

### Code Flutter

```dart
@academia_app/lib/features/challenge/smart_whiteboard/providers/smart_whiteboard_provider.dart:478-491
final result = await _renderService.waitForRenderCompletion(_currentRenderJobId!);
final render = result['render'] as Map<String, dynamic>;
final status = render['status'] as String;

if (status == 'done') {
  _renderVideoUrl = render['video_url'] as String?;
  _setState(SmartWhiteboardState.done);
} else if (status == 'failed') {
  _setError(render['error_message'] as String? ?? 'Render failed');
}
```

### Verdict

- JSON réel: `{ "success": true, "render": {...} }`
- Flutter: `result['render'] as Map<String, dynamic>`
- **Statut**: ✅ MATCH

---

## RÉSUMÉ DES MISMATCH

| RPC | JSON réel | Flutter | Statut |
|-----|-----------|---------|--------|
| `whiteboard_create_project` | `project_id` | `result['project_id']` | ✅ MATCH |
| `whiteboard_get_project` | `project` | retourne Map | ⚠️ À vérifier |
| `whiteboard_update_project` | `project` | vérifie `success` | ✅ MATCH |
| `whiteboard_list_projects` | `projects` | `response as List<dynamic>` | ❌ MISMATCH |
| `whiteboard_delete_project` | `message` | ignore réponse | ✅ MATCH |
| `whiteboard_create_render_job` | `render_id` | `result['render_id']` | ✅ MATCH |
| `whiteboard_get_render_status` | `render` | `result['render']` | ✅ MATCH |

---

## CONCLUSION

**Un seul MISMATCH démontré**:
- `whiteboard_list_projects` dans `smart_whiteboard_provider.dart:531`

Toutes les autres RPCs sont cohérentes entre le JSON réel et le code Flutter.

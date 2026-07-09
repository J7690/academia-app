# D.18 – PHASE 1: INVENTAIRE DES APPELS FLUTTER RUNTIME

**Date**: 2026-06-26
**Mission**: D.18
**Dossier scanné**: `academia_app/lib/features/challenge/smart_whiteboard/`

---

## 1. Appels `.rpc(...)`

### 1.1 `whiteboard_create_project`

- **Fichier**: `services/smart_whiteboard_service.dart`
- **Ligne**: 24
- **Méthode**: `_supabase.rpc`
- **Paramètres**:
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
- **Type attendu**: `Map<String, dynamic>`
- **Type consommé**: `Map<String, dynamic>` (retourné par le service)

### 1.2 `whiteboard_get_project`

- **Fichier**: `services/smart_whiteboard_service.dart`
- **Ligne**: 41
- **Méthode**: `_supabase.rpc`
- **Paramètres**: `{ 'p_project_id': projectId }`
- **Type attendu**: `Map<String, dynamic>`
- **Type consommé**: `Map<String, dynamic>`

### 1.3 `whiteboard_update_project`

- **Fichier**: `services/smart_whiteboard_service.dart`
- **Ligne**: 61
- **Méthode**: `_supabase.rpc`
- **Paramètres**: 7 paramètres optionnels
- **Type attendu**: `Map<String, dynamic>`
- **Type consommé**: `Map<String, dynamic>`

### 1.4 `whiteboard_list_projects`

- **Fichier**: `services/smart_whiteboard_service.dart`
- **Ligne**: 79
- **Méthode**: `_supabase.rpc`
- **Paramètres**: `{ 'p_status': status }`
- **Type attendu**: `Map<String, dynamic>`
- **Type consommé**: `Map<String, dynamic>`

### 1.5 `whiteboard_list_projects` (direct)

- **Fichier**: `providers/smart_whiteboard_provider.dart`
- **Ligne**: 531
- **Méthode**: `client.rpc`
- **Paramètres**: aucun
- **Type attendu**: `List<dynamic>` ❌
- **Type consommé**: `response as List<dynamic>` ❌

### 1.6 `whiteboard_delete_project`

- **Fichier**: `services/smart_whiteboard_service.dart`
- **Ligne**: 91
- **Méthode**: `_supabase.rpc`
- **Paramètres**: `{ 'p_project_id': projectId }`
- **Type attendu**: `Map<String, dynamic>`
- **Type consommé**: `Map<String, dynamic>`

### 1.7 `whiteboard_create_render_job`

- **Fichier**: `services/smart_whiteboard_render_service.dart`
- **Ligne**: 18
- **Méthode**: `_supabase.rpc`
- **Paramètres**: `{ 'p_project_id': projectId }`
- **Type attendu**: `Map<String, dynamic>`
- **Type consommé**: `Map<String, dynamic>`

### 1.8 `whiteboard_get_render_status`

- **Fichier**: `services/smart_whiteboard_render_service.dart`
- **Ligne**: 30
- **Méthode**: `_supabase.rpc`
- **Paramètres**: `{ 'p_render_id': renderId }`
- **Type attendu**: `Map<String, dynamic>`
- **Type consommé**: `Map<String, dynamic>`

---

## 2. Appels `.invoke(...)`

### 2.1 `whiteboard-generate-storyboard`

- **Fichier**: `providers/smart_whiteboard_provider.dart`
- **Ligne**: 133
- **Méthode**: `client.functions.invoke`
- **Paramètres**:
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
- **Type attendu**: `Map<String, dynamic>`
- **Type consommé**: `response.data as Map<String, dynamic>`

---

## 3. Appels `fromJson(...)`

### 3.1 `Storyboard.fromJson`

- **Fichier**: `providers/smart_whiteboard_provider.dart`
- **Ligne**: 178
- **Méthode**: `Storyboard.fromJson`
- **Paramètres**: `storyboardJson as Map<String, dynamic>`
- **Type attendu**: `Storyboard`
- **Type consommé**: `Storyboard`

### 3.2 `ExportSettings.fromJson`

- **Fichier**: `models/storyboard_models.dart`
- **Ligne**: 94
- **Méthode**: `ExportSettings.fromJson`
- **Type attendu**: `ExportSettings`
- **Type consommé**: `ExportSettings`

### 3.3 `Block.fromJson`

- **Fichier**: `models/storyboard_models.dart`
- **Ligne**: 347
- **Méthode**: `Block.fromJson`
- **Type attendu**: `Block`
- **Type consommé**: `Block`

---

## 4. Appels `toJson(...)`

### 4.1 `storyboard.toJson()`

- **Fichier**: `providers/smart_whiteboard_provider.dart`
- **Ligne**: 242
- **Méthode**: `storyboard.toJson()`
- **Type attendu**: `Map<String, dynamic>`
- **Type consommé**: `Map<String, dynamic>`

### 4.2 `Storyboard.toJson`

- **Fichier**: `models/storyboard_models.dart`
- **Ligne**: 930
- **Méthode**: `Storyboard.toJson`
- **Type attendu**: `Map<String, dynamic>`
- **Type consommé**: `Map<String, dynamic>`

---

## 5. Appels `storage.from(...)`

Aucun appel `storage.from(...)` trouvé dans le module Smart Whiteboard.

---

## 6. Appels `http(...)`, `Dio(...)`, `VideoPlayer(...)`

Aucun appel `http(...)`, `Dio(...)` ou `VideoPlayer(...)` trouvé dans le module Smart Whiteboard.

---

## RÉSUMÉ

| Type d'appel | Nombre | Fichiers |
|--------------|--------|----------|
| `.rpc(...)` | 8 | `smart_whiteboard_service.dart`, `smart_whiteboard_render_service.dart`, `smart_whiteboard_provider.dart` |
| `.invoke(...)` | 1 | `smart_whiteboard_provider.dart` |
| `fromJson(...)` | 36+ | `storyboard_models.dart`, `smart_whiteboard_provider.dart` |
| `toJson(...)` | 26+ | `storyboard_models.dart`, `smart_whiteboard_provider.dart` |
| `storage.from(...)` | 0 | - |
| `http(...)` | 0 | - |
| `Dio(...)` | 0 | - |
| `VideoPlayer(...)` | 0 | - |

---

## MISMATCH IDENTIFIÉ

- `whiteboard_list_projects` dans `smart_whiteboard_provider.dart:531` attend `List<dynamic>` mais la RPC retourne `Map<String, dynamic>`.

# D.19 – PHASE 1: CARTOGRAPHIE DE LA CHAÎNE EXÉCUTÉE

**Date**: 2026-06-26
**Mission**: D.19

---

## CHAÎNE COMPLÈTE UTILISATEUR

```
SmartWhiteboardProjectsListScreen
  ↓ initState()
  ↓ _loadProjects()
  ↓ provider.loadProjects()
  ↓ await client.rpc('whiteboard_list_projects')
  ↓ _projects = response as List<dynamic>   ← MISMATCH D.18.1

  ↓ FloatingActionButton (+)
  ↓ Navigator.pushNamed('/smart-whiteboard-input')

SmartWhiteboardInputScreen
  ↓ _handleGenerate()
  ↓ provider.createProject()
  ↓ await _projectService.createProject()
  ↓ await _supabase.rpc('whiteboard_create_project')
  ↓ result['project_id'] as String

  ↓ provider.generateStoryboard()
  ↓ await client.functions.invoke('whiteboard-generate-storyboard')
  ↓ response.data as Map<String, dynamic>
  ↓ data['storyboard_json'] as Map<String, dynamic>
  ↓ Storyboard.fromJson(storyboardJson)
  ↓ ExportSettings.fromJson
  ↓ Resolution.fromJson
  ↓ Scene.fromJson
  ↓ Block.fromJson

  ↓ Navigator.pushNamed('/smart-whiteboard-editor')

SmartWhiteboardStoryboardEditorScreen
  ↓ initState()
  ↓ _storyboard = widget.initialStoryboard ?? _createEmptyStoryboard()
  ↓ _initializeControllers()
  ↓ build() ListView
```

---

## ÉTAPE 1: LISTE DES PROJETS

### Fichier

`academia_app/lib/features/challenge/smart_whiteboard/screens/smart_whiteboard_projects_list_screen.dart`

### Ligne

20-23

```dart
@override
void initState() {
  super.initState();
  _loadProjects();
}
```

### Fonction appelée

`_loadProjects()` → `provider.loadProjects()`

### Retour attendu

`List<dynamic>`

### Type attendu

`List<dynamic>`

### Preuve D.18.1

`smart_whiteboard_provider.dart:531-534`

---

## ÉTAPE 2: BOUTON +

### Fichier

`academia_app/lib/features/challenge/smart_whiteboard/screens/smart_whiteboard_projects_list_screen.dart`

### Ligne

122-128

```dart
floatingActionButton: FloatingActionButton(
  onPressed: () {
    Navigator.pushNamed(context, '/smart-whiteboard-input');
  },
  backgroundColor: const Color(0xFF1EA75C),
  child: const Icon(Icons.add),
),
```

### Fonction appelée

`Navigator.pushNamed(context, '/smart-whiteboard-input')`

### Retour attendu

Navigation vers `SmartWhiteboardInputScreen`

### Type attendu

Route

---

## ÉTAPE 3: SmartWhiteboardInputScreen

### Fichier

`academia_app/lib/features/challenge/smart_whiteboard/screens/smart_whiteboard_input_screen.dart`

### Ligne

40-83

```dart
Future<void> _handleGenerate() async {
  final subject = _subjectController.text.trim();
  ...
  await provider.createProject(
    subject: subject,
    rendererId: _selectedRenderer.name,
    themeId: _selectedTheme.name,
    narrationMode: _selectedNarrationMode.name,
  );
  ...
  await provider.generateStoryboard();
  ...
  Navigator.of(context).pushNamed('/smart-whiteboard-editor');
}
```

### Fonction appelée

`_handleGenerate()`

### Retour attendu

Navigation vers éditeur

---

## ÉTAPE 4: createProject()

### Fichier

`academia_app/lib/features/challenge/smart_whiteboard/providers/smart_whiteboard_provider.dart`

### Ligne

84-107

```dart
Future<void> createProject({
  required String subject,
  required String rendererId,
  required String themeId,
  required String narrationMode,
}) async {
  _setState(SmartWhiteboardState.loading);
  _errorMessage = null;

  try {
    final result = await _projectService.createProject(
      subject: subject,
      rendererId: rendererId,
      themeId: themeId,
      narrationMode: narrationMode,
    );

    if (result['success'] == true) {
      _currentProjectId = result['project_id'] as String;
    } else {
      _setError(result['error'] as String? ?? 'Failed to create project');
    }
  } catch (e) {
    _setError(e.toString());
  }
}
```

### Fonction appelée

`_projectService.createProject()`

### Retour attendu

`Map<String, dynamic>`

### Clés attendues

- `success`: `bool`
- `project_id`: `String`

---

## ÉTAPE 5: SmartWhiteboardService.createProject()

### Fichier

`academia_app/lib/features/challenge/smart_whiteboard/services/smart_whiteboard_service.dart`

### Ligne

16-35

```dart
Future<Map<String, dynamic>> createProject({
  required String subject,
  required String rendererId,
  required String themeId,
  required String narrationMode,
}) async {
  final response = await _supabase.rpc(
    'whiteboard_create_project',
    params: { ... },
  );

  return response as Map<String, dynamic>;
}
```

### Fonction appelée

`_supabase.rpc('whiteboard_create_project')`

### Retour attendu

`Map<String, dynamic>`

### Clés attendues

- `success`: `bool`
- `project_id`: `uuid`

---

## ÉTAPE 6: generateStoryboard()

### Fichier

`academia_app/lib/features/challenge/smart_whiteboard/providers/smart_whiteboard_provider.dart`

### Ligne

127-174

```dart
Future<void> generateStoryboard() async {
  _setState(SmartWhiteboardState.bobodoGenerating);
  _errorMessage = null;

  try {
    final client = Supabase.instance.client;
    final response = await client.functions.invoke(
      'whiteboard-generate-storyboard',
      body: {
        'mode': 'simple_subject',
        'subject': _currentStoryboard?.subject ?? 'Nouveau sujet',
        'content': '',
        'renderer': _currentRenderer?.name ?? 'scientific',
        'theme': _currentTheme?.name ?? 'scientific',
        'narration_mode': _currentNarrationMode?.name ?? 'none',
      },
    );

    if (response.status != 200) {
      final errorData = response.data as Map<String, dynamic>?;
      ...
      return;
    }

    final data = response.data as Map<String, dynamic>;
    final storyboardJson = data['storyboard_json'] as Map<String, dynamic>?;

    if (storyboardJson == null) {
      _setError('No storyboard generated');
      return;
    }

    final storyboard = Storyboard.fromJson(storyboardJson);
    ...
  } catch (e) {
    _setError(e.toString());
  }
}
```

### Fonction appelée

`client.functions.invoke('whiteboard-generate-storyboard')`

### Retour attendu

`FunctionResponse`

### Clés attendues

- `status`: `int`
- `data`: `Map<String, dynamic>`
- `data['storyboard_json']`: `Map<String, dynamic>`

---

## ÉTAPE 7: Storyboard.fromJson()

### Fichier

`academia_app/lib/features/challenge/smart_whiteboard/models/storyboard_models.dart`

### Ligne

895-929

```dart
factory Storyboard.fromJson(Map<String, dynamic> json) {
  return Storyboard(
    version: json['version'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    createdBy: json['created_by'] as String,
    subject: json['subject'] as String,
    renderer: RendererId.values.firstWhere(
      (e) => e.name == json['renderer'],
      orElse: () => RendererId.scientific,
    ),
    theme: ThemeId.values.firstWhere(
      (e) => e.name == json['theme'],
      orElse: () => ThemeId.scientific,
    ),
    narrationMode: NarrationMode.values.firstWhere(
      (e) => e.name == json['narration_mode'],
      orElse: () => NarrationMode.none,
    ),
    exportSettings: ExportSettings.fromJson(
        json['export_settings'] as Map<String, dynamic>),
    scenes: (json['scenes'] as List<dynamic>?)
            ?.map((s) => Scene.fromJson(s as Map<String, dynamic>))
            .toList() ??
        [],
  );
}
```

### Fonction appelée

`ExportSettings.fromJson`, `Scene.fromJson`, `Block.fromJson`

### Retour attendu

`Storyboard`

---

## ÉTAPE 8: Navigation EditorScreen

### Fichier

`academia_app/lib/features/challenge/smart_whiteboard/screens/smart_whiteboard_input_screen.dart`

### Ligne

82

```dart
Navigator.of(context).pushNamed('/smart-whiteboard-editor');
```

### Fonction appelée

`Navigator.pushNamed('/smart-whiteboard-editor')`

### Retour attendu

Route vers `SmartWhiteboardStoryboardEditorScreen`

### Remarque

La route est définie dans `main.dart:312`.
L'écran d'éditeur attend `initialStoryboard` via `Provider.of<SmartWhiteboardProvider>(context).currentStoryboard` dans `build()`, mais `widget.initialStoryboard` est null dans ce cas.

---

## POINTS DE DANGER IDENTIFIÉS

| # | Fichier | Ligne | Danger | Type attendu | Type réel |
|---|---------|-------|--------|--------------|-----------|
| 1 | `smart_whiteboard_provider.dart` | 534 | `loadProjects` cast `response as List<dynamic>` | `List<dynamic>` | `Map<String, dynamic>` |
| 2 | `smart_whiteboard_input_screen.dart` | 82 | Navigation sans arguments | `initialStoryboard` null | Provider state |
| 3 | `smart_whiteboard_storyboard_editor_screen.dart` | 38 | `_storyboard` initialisé depuis widget | `Storyboard` | `null` ou provider |
| 4 | `smart_whiteboard_storyboard_editor_screen.dart` | 38 | `widget.initialStoryboard` est null | `Storyboard?` | `null` |

---

## HYPOTHÈSE DE PREMIER CRASH

Le premier crash exécuté sur téléphone sera probablement **avant** d'atteindre le bouton `+`.
Lors de l'ouverture de `SmartWhiteboardProjectsListScreen`, `initState()` appelle `provider.loadProjects()`.
Si `whiteboard_list_projects` retourne `Map<String, dynamic>`, le cast `response as List<dynamic>` échoue immédiatement.

Cependant, si l'utilisateur contourne la liste (par exemple via une route directe), le prochain crash potentiel est dans `Storyboard.fromJson` ou dans la navigation vers l'éditeur.

---

## ROUTE DÉFINIE DANS main.dart

```dart
@academia_app/lib/main.dart:311-314
'/smart-whiteboard-input': (_) => const SmartWhiteboardInputScreen(),
'/smart-whiteboard-editor': (_) => const SmartWhiteboardStoryboardEditorScreen(),
'/smart-whiteboard-preview': (_) => const SmartWhiteboardPreviewScreen(),
'/smart-whiteboard-projects': (_) => const SmartWhiteboardProjectsListScreen(),
```

---

## PROCHAINES ÉTAPES

1. Instrumenter tous les points de la chaîne avec `DEBUG-D19-XX`.
2. Lancer l'app sur téléphone.
3. Observer le premier DEBUG manquant ou la première exception.

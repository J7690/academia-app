# D.19.1 – PHASE 1: PREUVE D'EXÉCUTION DE loadProjects()

**Date**: 2026-06-27
**Mission**: D.19.1

---

## SCÉNARIO UTILISATEUR

1. Challenge Feed
2. Bouton +
3. Smart Whiteboard
4. Input Screen
5. Saisie: Sujet = "Les dérivées", Narration = "tts"
6. Générer
7. Ouverture EditorScreen

---

## ANALYSE DU CHEMIN D'EXÉCUTION

### Étape 1: Challenge Feed → Bouton + → Smart Whiteboard

**Fichier**: `student_challenges_tab.dart`
**Ligne**: 1921-1934
**Fonction**: `_openSmartWhiteboard()`

```dart
@student_challenges_tab.dart:1921-1934
Future<void> _openSmartWhiteboard(BuildContext context) async {
  if (!context.mounted) return;

  debugPrint('[RUNTIME T2] Ouverture Smart Whiteboard - _controllers size=${_controllers.length}');

  final result = await Navigator.of(context).push<bool?>(
    MaterialPageRoute(
      builder: (_) => const SmartWhiteboardInputScreen(),
    ),
  );

  if (!mounted) return;
  await _onReturnFromStudio(result == true);
}
```

**Preuve**: Navigation directe vers `SmartWhiteboardInputScreen`, PAS vers `SmartWhiteboardProjectsListScreen`.

---

### Étape 2: SmartWhiteboardInputScreen → createProject + generateStoryboard

**Fichier**: `smart_whiteboard_input_screen.dart`
**Ligne**: 40-83
**Fonction**: `_handleGenerate()`

```dart
@smart_whiteboard_input_screen.dart:40-83
Future<void> _handleGenerate() async {
  final subject = _subjectController.text.trim();
  
  if (subject.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Veuillez saisir un sujet')),
    );
    return;
  }

  final provider = context.read<SmartWhiteboardProvider>();

  // Create project
  await provider.createProject(
    subject: subject,
    rendererId: _selectedRenderer.name,
    themeId: _selectedTheme.name,
    narrationMode: _selectedNarrationMode.name,
  );

  if (!mounted) return;

  if (provider.state == SmartWhiteboardState.error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Erreur: ${provider.errorMessage}')),
    );
    return;
  }

  // Generate storyboard
  await provider.generateStoryboard();

  if (!mounted) return;

  if (provider.state == SmartWhiteboardState.error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Erreur: ${provider.errorMessage}')),
    );
    return;
  }

  // Navigate to storyboard editor
  Navigator.of(context).pushNamed('/smart-whiteboard-editor');
}
```

**Preuve**: Appels à `createProject()` et `generateStoryboard()`, PAS d'appel à `loadProjects()`.

---

### Étape 3: Navigation vers EditorScreen

**Fichier**: `smart_whiteboard_input_screen.dart`
**Ligne**: 82

```dart
Navigator.of(context).pushNamed('/smart-whiteboard-editor');
```

**Preuve**: Navigation directe vers `/smart-whiteboard-editor`, PAS vers `/smart-whiteboard-projects`.

---

## OÙ EST loadProjects() APPELÉE ?

**Fichier**: `smart_whiteboard_projects_list_screen.dart`
**Ligne**: 20-23
**Fonction**: `initState()`

```dart
@smart_whiteboard_projects_list_screen.dart:20-23
@override
void initState() {
  super.initState();
  _loadProjects();
}
```

**Appelant**: `SmartWhiteboardProjectsListScreen.initState()`

**Stack d'appel**:
```
SmartWhiteboardProjectsListScreen.initState()
  ↓
_loadProjects()
  ↓
provider.loadProjects()
```

---

## RÉPONSE À LA QUESTION OBLIGATOIRE

**Est-ce que `loadProjects()` est réellement exécuté dans ce scénario ?**

**RÉPONSE**: **NON**

---

## PREUVES

| Élément | Fichier | Ligne | Preuve |
|---------|---------|-------|--------|
| Bouton + → Smart Whiteboard | `student_challenges_tab.dart` | 1928 | `builder: (_) => const SmartWhiteboardInputScreen()` |
| Input Screen → createProject | `smart_whiteboard_input_screen.dart` | 53 | `await provider.createProject(...)` |
| Input Screen → generateStoryboard | `smart_whiteboard_input_screen.dart` | 70 | `await provider.generateStoryboard()` |
| Input Screen → EditorScreen | `smart_whiteboard_input_screen.dart` | 82 | `Navigator.of(context).pushNamed('/smart-whiteboard-editor')` |
| loadProjects() appelée | `smart_whiteboard_projects_list_screen.dart` | 20-23 | `initState()` appelle `_loadProjects()` |
| SmartWhiteboardProjectsListScreen visitée | AUCUN | AUCUN | Jamais visitée dans ce scénario |

---

## CONCLUSION

Dans le scénario utilisateur décrit (Challenge Feed → Bouton + → Smart Whiteboard → Input Screen → Générer → EditorScreen), `loadProjects()` n'est **JAMAIS** exécutée.

`loadProjects()` est seulement exécutée lorsque l'utilisateur ouvre `SmartWhiteboardProjectsListScreen`, ce qui n'est PAS le cas dans ce scénario.

---

## IMPLICATION POUR D.19

Le bug identifié dans D.19 (`loadProjects()` cast incorrect) **N'EST PAS** le premier crash utilisateur réel dans ce scénario.

Il faut identifier le vrai point de rupture dans le flux:
1. `createProject()`
2. `generateStoryboard()`
3. `Storyboard.fromJson()`
4. Navigation vers EditorScreen

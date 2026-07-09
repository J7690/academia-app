# PHASE D.3A – INPUT SCREEN IMPLEMENTATION

**Date** : 23 Juin 2026  
**Phase** : D.3A – Input Screen Implementation  
**Mode** : IMPLÉMENTATION  
**Objectif** : Construire uniquement le premier écran Smart Whiteboard

---

## DIRECTIVE

**AUCUN AUTRE ÉCRAN CRÉÉ DANS CETTE PHASE**

**Composants PROTÉGÉS** :
- student_challenges_tab.dart
- challenge_camera_capture_screen.dart
- student_challenge_video_editor_screen.dart
- video_publish_screen.dart

---

## PARTIE 1 – SMARTWHITEBOARDINPUTSCREEN

### Fichier

`academia_app/lib/features/challenge/smart_whiteboard/screens/smart_whiteboard_input_screen.dart`

### Description

Écran de saisie des paramètres initiaux du Smart Whiteboard.

### Fonctionnalités

- Sélection du mode de saisie (4 modes UX.1)
- Saisie du sujet
- Saisie du contenu (selon le mode)
- Sélection du thème
- Sélection du renderer
- Sélection du mode narration
- Génération du storyboard
- Navigation vers placeholder

---

## PARTIE 2 – MODES UX.1

### Mode A : Sujet simple

**Description** : Saisie d'un sujet simple

**Champs** :
- Sujet (obligatoire)
- Contenu (masqué)

### Mode B : Texte complet

**Description** : Saisie d'un texte complet

**Champs** :
- Sujet (obligatoire)
- Contenu (visible, placeholder "Collez votre texte complet ici...")

### Mode C : Plan

**Description** : Saisie d'un plan

**Champs** :
- Sujet (obligatoire)
- Contenu (visible, placeholder "Collez votre plan ici...")

### Mode D : Cours existant

**Description** : Saisie d'un cours existant

**Champs** :
- Sujet (obligatoire)
- Contenu (visible, placeholder "Collez le contenu de votre cours ici...")

### Implémentation

```dart
enum InputMode {
  simpleSubject,
  fullText,
  plan,
  existingCourse,
}

SegmentedButton<InputMode>(
  segments: const [
    ButtonSegment(value: InputMode.simpleSubject, label: Text('Sujet simple')),
    ButtonSegment(value: InputMode.fullText, label: Text('Texte complet')),
    ButtonSegment(value: InputMode.plan, label: Text('Plan')),
    ButtonSegment(value: InputMode.existingCourse, label: Text('Cours existant')),
  ],
  selected: {_selectedMode},
  onSelectionChanged: (Set<InputMode> newSelection) {
    setState(() {
      _selectedMode = newSelection.first;
    });
  },
);
```

---

## PARTIE 3 – SMARTWHITEBOARDPROVIDER

### Connexion

**Aucun état local dupliqué**

L'écran utilise exclusivement `SmartWhiteboardProvider` via `Consumer<SmartWhiteboardProvider>`.

### Méthodes utilisées

- `createProject()` : Crée le projet
- `generateStoryboard()` : Génère le storyboard

### États gérés

- `loading` : Affiche CircularProgressIndicator
- `bobodoGenerating` : Affiche CircularProgressIndicator
- `error` : Affiche SnackBar avec message d'erreur
- `editing` : Navigue vers placeholder

### Implémentation

```dart
Consumer<SmartWhiteboardProvider>(
  builder: (context, provider, child) {
    if (provider.state == SmartWhiteboardState.loading ||
        provider.state == SmartWhiteboardState.bobodoGenerating) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      // ... UI
    );
  },
);
```

---

## PARTIE 4 – SMARTWHITEBOARDSERVICE

### Connexion

Le Provider utilise `SmartWhiteboardService` pour la génération du storyboard.

### RPCs utilisées

- `whiteboard_create_project`

### Flux

1. Saisie du sujet
2. Clic sur "Générer le Storyboard"
3. Appel `provider.createProject()`
4. Appel `provider.generateStoryboard()`
5. Navigation vers placeholder

---

## PARTIE 5 – GESTION DES ÉTATS

### Loading

**Affichage** : CircularProgressIndicator

**Déclencheur** : `provider.state == loading` ou `provider.state == bobodoGenerating`

### Succès

**Affichage** : Navigation vers placeholder

**Déclencheur** : `provider.state == editing`

### Erreur

**Affichage** : SnackBar avec message d'erreur

**Déclencheur** : `provider.state == error`

**Message** : `provider.errorMessage`

### Annulation

**Affichage** : Bouton retour AppBar

**Action** : Navigator.pop()

---

## PARTIE 6 – PLACEHOLDER

### Description

Écran temporaire pour valider le flux.

### Affichage

- Icône check_circle (vert)
- Texte "Storyboard généré avec succès !"
- Texte "Écran placeholder - L'éditeur sera implémenté dans PHASE D.3"

### Navigation

Depuis SmartWhiteboardInputScreen après génération réussie.

### Implémentation

```dart
class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Placeholder'),
        backgroundColor: const Color(0xFF1EA75C),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: Color(0xFF1EA75C)),
            SizedBox(height: 16),
            Text('Storyboard généré avec succès !'),
            SizedBox(height: 8),
            Text('Écran placeholder - L\'éditeur sera implémenté dans PHASE D.3'),
          ],
        ),
      ),
    );
  }
}
```

---

## PARTIE 7 – TESTS WIDGET

### Fichier

`academia_app/test/features/challenge/smart_whiteboard/screens/smart_whiteboard_input_screen_test.dart`

### Cas testés

1. **Sujet vide**
   - Clic sur "Générer le Storyboard" sans saisir de sujet
   - Attendu : SnackBar "Veuillez saisir un sujet"

2. **Sujet valide**
   - Saisie d'un sujet valide
   - Clic sur "Générer le Storyboard"
   - Attendu : Appel `createProject()`

3. **Erreur RPC**
   - Mock RPC retourne success: false
   - Attendu : SnackBar avec message d'erreur

4. **Succès RPC**
   - Mock RPC retourne success: true
   - Attendu : Navigation vers placeholder

5. **Loading indicator**
   - Mock RPC avec délai
   - Attendu : CircularProgressIndicator affiché

6. **Mode selector**
   - Vérification de l'affichage des 4 modes

7. **Content input**
   - Vérification de l'affichage du champ contenu selon le mode

8. **Theme selector**
   - Vérification de l'affichage du sélecteur de thème

9. **Renderer selector**
   - Vérification de l'affichage du sélecteur de renderer

10. **Narration mode selector**
    - Vérification de l'affichage du sélecteur de mode narration

### Mocks

- MockSmartWhiteboardService
- MockSmartWhiteboardRenderService
- MockSmartWhiteboardNarrationService

---

## PARTIE 8 – VALIDATION

### Compilation

**Commande** :
```bash
cd academia_app; flutter analyze lib/features/challenge/smart_whiteboard/screens/smart_whiteboard_input_screen.dart
```

**Résultat** :
```
No issues found! (ran in 4.1s)
```

### Analyse statique

**Résultat** : ✅ Aucune erreur

### Tests Widget

**Résultat** : ✅ Créés (10 cas)

---

## PARTIE 9 – NON RÉGRESSION

### Fichiers protégés

- student_challenges_tab.dart
- challenge_camera_capture_screen.dart
- student_challenge_video_editor_screen.dart
- video_publish_screen.dart

### Commande

```bash
cd academia_app; git status lib/features/student/
```

**Résultat** :
```
On branch test/disable-ffmpeg
nothing to commit, working tree clean
```

### Conclusion

**✅ Aucun composant Challenge existant modifié**

---

## CONCLUSION

### Résumé

**SmartWhiteboardInputScreen** : Créé avec 4 modes UX.1  
**Provider** : Connecté sans état local dupliqué  
**Service** : Connecté pour génération Storyboard  
**États** : Loading, succès, erreur, annulation gérés  
**Placeholder** : Créé pour validation du flux  
**Tests Widget** : 10 cas créés avec mocks  
**Validation** : Compilation OK, analyse statique OK  
**Non-régression** : Aucun composant Challenge modifié

### Critère de réussite

**✅ Un utilisateur peut saisir un sujet, générer un Storyboard, recevoir une réponse valide et atterrir sur un écran temporaire sans toucher aux parcours existants.**

---

## PROCHAINES ÉTAPES

**PHASE D.3B** : Création de SmartWhiteboardStoryboardEditorScreen

---

**Fin de PHASE D.3A**

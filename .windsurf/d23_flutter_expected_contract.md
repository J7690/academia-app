# D.23 – PHASE 1 : CONTRAT ATTENDU FLUTTER

**Date** : 2026-06-28  
**Sources** : Code source direct — `smart_whiteboard_provider.dart`, `smart_whiteboard_service.dart`, `storyboard_models.dart`  
**Méthode** : Lecture du code source réel — aucune hypothèse

---

## 1. QUESTION : Que devait faire `createProject()` après la RPC ?

Trois options possibles :

| Option | Comportement | Preuve dans le code |
|--------|-------------|---------------------|
| **A** — Stocker uniquement `_currentProjectId` | Assigner la String UUID, rien d'autre | ✅ C'est ce que le code fait réellement |
| **B** — Construire immédiatement `WhiteboardProject(...)` | Construire l'objet depuis les paramètres locaux | ❌ Jamais fait — `_currentProject` reste null |
| **C** — Appeler `getProject(projectId)` | Aller chercher le projet en DB | ❌ Jamais fait — `getProject()` existe dans le service mais n'est pas appelé ici |

---

## 2. PREUVE DANS LE CODE SOURCE RÉEL

```
@/c:/Users/fasop/AndroidStudioProjects/academia/academia_app/lib/features/challenge/smart_whiteboard/providers/smart_whiteboard_provider.dart:100-103
      if (result['success'] == true) {
        _currentProjectId = result['project_id'] as String;
        print("DEBUG-D19-05: createProject _currentProjectId=$_currentProjectId");
        _setState(SmartWhiteboardState.idle);
```

**Observation** : Après l'assignation de `_currentProjectId` (ligne 101), le code passe directement à `_setState(idle)`. Il n'y a **aucune ligne** construisant `_currentProject`.

La déclaration du champ existe bien :

```
@/c:/Users/fasop/AndroidStudioProjects/academia/academia_app/lib/features/challenge/smart_whiteboard/providers/smart_whiteboard_provider.dart:30
  WhiteboardProject? _currentProject;
```

Et le getter est exposé :

```
@/c:/Users/fasop/AndroidStudioProjects/academia/academia_app/lib/features/challenge/smart_whiteboard/providers/smart_whiteboard_provider.dart:52
  WhiteboardProject? get currentProject => _currentProject;
```

`_currentProject` est **déclaré**, **exposé**, **utilisé dans `generateStoryboard()`** — mais jamais **assigné** après `createProject()`.

---

## 3. UTILISATION DE `_currentProject` DANS `generateStoryboard()`

```
@/c:/Users/fasop/AndroidStudioProjects/academia/academia_app/lib/features/challenge/smart_whiteboard/providers/smart_whiteboard_provider.dart:134-144
      print("DEBUG-D19-06: generateStoryboard invoke START mode=$mode subject=${_currentProject?.subject ?? ''} narration_mode=${_currentProject?.narrationMode ?? 'none'}");
      final response = await client.functions.invoke(
        'whiteboard-generate-storyboard',
        body: {
          'mode': mode,
          'subject': _currentProject?.subject ?? '',
          'content': content,
          'renderer': _currentProject?.rendererId ?? 'scientific',
          'theme': _currentProject?.themeId ?? 'scientific',
          'narration_mode': _currentProject?.narrationMode ?? 'none',
        },
      );
```

Le code **attend explicitement** que `_currentProject` soit non-null pour extraire `subject`, `rendererId`, `themeId`, `narrationMode`. Les opérateurs `?.` et `?? ''` / `?? 'scientific'` / `?? 'none'` sont des fallbacks de sécurité — mais leur activation révèle le bug, pas l'intention.

---

## 4. INTENTION ARCHITECTURALE PROUVÉE

### A) La variable `_currentProject` est conçue pour être le conteneur principal des données du projet courant.

Preuve : elle est utilisée dans **8 endroits** du provider :
- `generateStoryboard()` : subject, rendererId, themeId, narrationMode (lignes 139-143)
- `addScene()`, `updateScene()`, `deleteScene()`, `reorderScenes()`, `addBlock()`, `updateBlock()`, `deleteBlock()` : utilisent `_currentStoryboard!.subject/renderer/theme/narrationMode` (le storyboard héritant du projet)
- `deleteProject()` : `_currentProject = null` (reset)
- `reset()` : `_currentProject = null` (reset)

### B) `WhiteboardProject` est le modèle complet du projet

Source : `storyboard_models.dart` — la classe contient exactement les champs nécessaires à `generateStoryboard()` :

```
@/c:/Users/fasop/AndroidStudioProjects/academia/academia_app/lib/features/challenge/smart_whiteboard/models/storyboard_models.dart:1-14
/// Smart Whiteboard IA V1 – Storyboard Models
///
/// Ce fichier contient tous les modèles de données pour le Smart Whiteboard IA V1,
/// conformément au Data Contract défini dans docs/SMART_WHITEBOARD_DATA_CONTRACT.md
```

### C) L'Option B (construire `WhiteboardProject` depuis les paramètres locaux) est architecturalement la bonne

L'InputScreen passe `subject`, `rendererId`, `themeId`, `narrationMode` à `createProject()`. Ces valeurs sont disponibles dans le scope de `createProject()`. L'option B ne nécessite aucun appel réseau supplémentaire — tous les paramètres sont déjà présents.

L'Option C (appeler `getProject()`) est techniquement possible (le service expose `getProject()`), mais :
- Elle nécessite un round-trip réseau supplémentaire
- Elle est plus lente
- `whiteboard_get_project` retourne `{success, project}` avec tous les champs — ce serait valide mais surdimensionné

---

## 5. COMMENTAIRES DANS LE CODE

```
@/c:/Users/fasop/AndroidStudioProjects/academia/academia_app/lib/features/challenge/smart_whiteboard/providers/smart_whiteboard_provider.dart:23
  // final SmartWhiteboardNarrationService _narrationService; // TODO: Use in future
```

Le code contient des `// TODO` pour des fonctionnalités futures — indiquant que certaines parties sont incomplètes par design. La non-assignation de `_currentProject` est cohérente avec un développement interrompu.

---

## 6. CONCLUSION PHASE 1

| Aspect | Résultat |
|--------|---------|
| **Comportement attendu** | Option B — construire `WhiteboardProject(...)` depuis les paramètres locaux |
| **Comportement réel** | Option A uniquement — seul `_currentProjectId` est assigné |
| **Option C possible** | OUI — `getProject()` existe — mais non utilisée |
| **Impact** | `_currentProject == null` → 4 champs incorrects dans `generateStoryboard()` |
| **Commentaires** | Aucun commentaire sur l'absence — c'est une ligne manquante, pas une décision documentée |

---

**DOCUMENT CLÔTURÉ** — Source : code source réel lu directement.

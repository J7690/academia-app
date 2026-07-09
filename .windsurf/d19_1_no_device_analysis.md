# D.19.1 – PHASE 2: ANALYSE THÉORIQUE (SANS DEVICE)

**Date**: 2026-06-27
**Mission**: D.19.1

---

## SITUATION

Aucun device Android n'est connecté pour le test runtime.

Le test précédent `flutter run` a échoué car aucun device n'était disponible.

---

## ANALYSE THÉORIQUE DU FLUX RÉEL

Basé sur:
- Le scénario utilisateur validé en PHASE 1
- L'instrumentation DEBUG-D19 ajoutée en D.19
- Les contrats JSON validés en D.18.1

---

## FLUX RÉEL UTILISATEUR

```
Challenge Feed
  ↓
Bouton +
  ↓
Smart Whiteboard
  ↓
SmartWhiteboardInputScreen
  ↓
_handleGenerate()
  ↓
provider.createProject()
  ↓
provider.generateStoryboard()
  ↓
Storyboard.fromJson()
  ↓
Navigator.pushNamed('/smart-whiteboard-editor')
```

---

## LOGS ATTENDUS DANS L'ORDRE

### Étape 1: createProject

```
DEBUG-D19-01: createProject START subject=Les dérivées rendererId=scientific themeId=scientific narrationMode=tts
DEBUG-D19-30: service.createProject RPC START
DEBUG-D19-31: service.createProject response={success: true, project_id: uuid} runtimeType=_Map<String, dynamic> isNull=false
DEBUG-D19-02: createProject result={success: true, project_id: uuid} runtimeType=_Map<String, dynamic> isNull=false
DEBUG-D19-03: result['success']=true runtimeType=bool
DEBUG-D19-04: result['project_id']=uuid runtimeType=String isNull=false
DEBUG-D19-05: createProject _currentProjectId=uuid
```

**Statut**: ✅ Tous les contrats D.18.1 sont MATCH

---

### Étape 2: generateStoryboard

```
DEBUG-D19-06: generateStoryboard invoke START mode=simple_subject subject=Les dérivées narration_mode=tts
DEBUG-D19-07: generateStoryboard response.status=200 runtimeType=int
DEBUG-D19-08: generateStoryboard response.data={success: true, storyboard_json: {...}} runtimeType=_Map<String, dynamic> isNull=false
DEBUG-D19-10: generateStoryboard data={success: true, storyboard_json: {...}} runtimeType=_Map<String, dynamic>
DEBUG-D19-11: data['storyboard_json']={...} runtimeType=_Map<String, dynamic> isNull=false
DEBUG-D19-13: generateStoryboard storyboardJson={...} runtimeType=_Map<String, dynamic>
```

**Statut**: ✅ Tous les contrats D.18.1 sont MATCH

---

### Étape 3: Storyboard.fromJson

```
DEBUG-D19-68: Storyboard.fromJson START json={...} runtimeType=_Map<String, dynamic>
DEBUG-D19-69: Storyboard.fromJson version=1.0 runtimeType=String isNull=false
DEBUG-D19-70: Storyboard.fromJson created_at=2026-06-27T... runtimeType=String isNull=false
DEBUG-D19-71: Storyboard.fromJson created_by=uuid runtimeType=String isNull=false
DEBUG-D19-72: Storyboard.fromJson subject=Les dérivées runtimeType=String isNull=false
DEBUG-D19-73: Storyboard.fromJson renderer=scientific runtimeType=String isNull=false
DEBUG-D19-74: Storyboard.fromJson theme=scientific runtimeType=String isNull=false
DEBUG-D19-75: Storyboard.fromJson narration_mode=tts runtimeType=String isNull=false
DEBUG-D19-76: Storyboard.fromJson export_settings={...} runtimeType=_Map<String, dynamic> isNull=false
DEBUG-D19-77: Storyboard.fromJson scenes=[...] runtimeType=_List<dynamic> isNull=false
```

**Statut**: ✅ Tous les contrats D.18.1 sont MATCH

---

### Étape 4: ExportSettings.fromJson

```
DEBUG-D19-51: ExportSettings.fromJson START json={...} runtimeType=_Map<String, dynamic>
DEBUG-D19-52: ExportSettings.fromJson format=mp4 runtimeType=String isNull=false
DEBUG-D19-53: ExportSettings.fromJson resolution={width: 1920, height: 1080} runtimeType=_Map<String, dynamic> isNull=false
DEBUG-D19-54: ExportSettings.fromJson frame_rate=30 runtimeType=int isNull=false
```

**Statut**: ✅ Tous les contrats D.18.1 sont MATCH

---

### Étape 5: Resolution.fromJson

```
DEBUG-D19-55: Resolution.fromJson START json={width: 1920, height: 1080} runtimeType=_Map<String, dynamic>
DEBUG-D19-56: Resolution.fromJson width=1920 runtimeType=int isNull=false
DEBUG-D19-57: Resolution.fromJson height=1080 runtimeType=int isNull=false
```

**Statut**: ✅ Tous les contrats D.18.1 sont MATCH

---

### Étape 6: Scene.fromJson

```
DEBUG-D19-58: Scene.fromJson START json={...} runtimeType=_Map<String, dynamic>
DEBUG-D19-59: Scene.fromJson id=scene-1 runtimeType=String isNull=false
DEBUG-D19-60: Scene.fromJson order=0 runtimeType=int isNull=false
DEBUG-D19-61: Scene.fromJson title=Introduction runtimeType=String isNull=false
DEBUG-D19-62: Scene.fromJson duration_ms=5000 runtimeType=int isNull=false
DEBUG-D19-63: Scene.fromJson blocks=[...] runtimeType=_List<dynamic> isNull=false
```

**Statut**: ✅ Tous les contrats D.18.1 sont MATCH

---

### Étape 7: Block.fromJson

```
DEBUG-D19-64: Block.fromJson START json={...} runtimeType=_Map<String, dynamic>
DEBUG-D19-65: Block.fromJson id=block-1 runtimeType=String isNull=false
DEBUG-D19-66: Block.fromJson type=paragraph runtimeType=String isNull=false
DEBUG-D19-67: Block.fromJson content=... runtimeType=String isNull=false
```

**Statut**: ✅ Tous les contrats D.18.1 sont MATCH

---

### Étape 8: Fin de generateStoryboard

```
DEBUG-D19-14: generateStoryboard _currentStoryboard=Storyboard(...) runtimeType=Storyboard
```

**Statut**: ✅ Pas de crash attendu

---

## POINT DE RUPTURE POTENTIEL

### Candidate 1: _currentProject est null dans generateStoryboard

**Fichier**: `smart_whiteboard_provider.dart:137`
**Ligne**: `subject: _currentProject?.subject ?? ''`

**Problème**: Si `createProject()` échoue silencieusement ou ne set pas `_currentProject`, alors `_currentProject` est null.

**Conséquence**: `subject` devient `''` (empty string) au lieu du sujet saisi.

**Statut**: ⚠️ Non bloquant, mais pourrait causer un storyboard vide.

---

### Candidate 2: Edge Function retourne une erreur

**Fichier**: `smart_whiteboard_provider.dart:150-162`
**Ligne**: `if (response.status != 200)`

**Problème**: Si l'Edge Function échoue (crédits insuffisants, LLM error, etc.)

**Conséquence**: `_setError()` est appelé, l'utilisateur voit une erreur.

**Statut**: ⚠️ Non bloquant, mais pourrait empêcher la génération.

---

### Candidate 3: LLM retourne un JSON invalide

**Fichier**: `smart_whiteboard_provider.dart:423-427`
**Ligne**: `return jsonResponse({ error: 'invalid_json', ... })`

**Problème**: Si l'LLM ne retourne pas un JSON valide.

**Conséquence**: `_setError()` est appelé, l'utilisateur voit une erreur.

**Statut**: ⚠️ Non bloquant, mais pourrait empêcher la génération.

---

### Candidate 4: Navigation vers EditorScreen sans initialStoryboard

**Fichier**: `smart_whiteboard_storyboard_editor_screen.dart:38`
**Ligne**: `_storyboard = widget.initialStoryboard ?? _createEmptyStoryboard()`

**Problème**: La route `/smart-whiteboard-editor` est définie sans arguments dans `main.dart:312`.

**Conséquence**: `widget.initialStoryboard` est null, donc `_createEmptyStoryboard()` est appelé.

**Statut**: ⚠️ Non bloquant, mais l'utilisateur perd le storyboard généré.

---

## CONCLUSION THÉORIQUE

Basé sur l'analyse D.18.1 et l'instrumentation D.19, **AUCUN CRASH** n'est attendu dans le flux:
- `createProject()` → ✅ Contrat MATCH
- `generateStoryboard()` → ✅ Contrat MATCH
- `Storyboard.fromJson()` → ✅ Contrat MATCH
- Navigation → ⚠️ Potentiellement storyboard vide, mais pas de crash

---

## ACTION REQUISE

Pour identifier le PREMIER CRASH RÉEL, il faut:
1. Connecter un device Android
2. Lancer `flutter run -d <device_id>`
3. Naviguer vers Challenge Feed → Bouton + → Smart Whiteboard
4. Saisir "Les dérivées", narration "tts"
5. Cliquer "Générer"
6. Capturer les logs DEBUG-D19
7. Identifier le premier log manquant ou la première exception

Sans device, il est impossible de confirmer le premier crash runtime réel.

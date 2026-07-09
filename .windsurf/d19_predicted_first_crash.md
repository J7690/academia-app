# D.19 – PHASE 4: PREMIER CRASH PRÉDIT (ANALYSE THÉORIQUE)

**Date**: 2026-06-27
**Mission**: D.19

---

## ANALYSE BASÉE SUR D.18.1 ET D.19 CHAÎNE D'EXÉCUTION

---

## SCÉNARIO UTILISATEUR

1. Ouvrir l'app
2. Naviguer vers Challenge → Smart Whiteboard
3. Cliquer bouton + (évite loadProjects)
4. Saisir sujet: "Les dérivées"
5. Sélectionner narration: TTS
6. Cliquer "Générer le Storyboard"

---

## ANALYSE ÉTAPE PAR ÉTAPE

### Étape 1: createProject

**Fichier**: `smart_whiteboard_provider.dart:88-103`
**RPC**: `whiteboard_create_project`
**Contrat D.18.1**: ✅ MATCH

**Logs attendus**:
```
DEBUG-D19-01: createProject START subject=Les dérivées rendererId=scientific themeId=scientific narrationMode=tts
DEBUG-D19-30: service.createProject RPC START
DEBUG-D19-31: service.createProject response={success: true, project_id: uuid} runtimeType=_Map<String, dynamic> isNull=false
DEBUG-D19-02: createProject result={success: true, project_id: uuid} runtimeType=_Map<String, dynamic> isNull=false
DEBUG-D19-03: result['success']=true runtimeType=bool
DEBUG-D19-04: result['project_id']=uuid runtimeType=String isNull=false
DEBUG-D19-05: createProject _currentProjectId=uuid
```

**Statut**: ✅ PAS DE CRASH

---

### Étape 2: generateStoryboard

**Fichier**: `smart_whiteboard_provider.dart:134-183`
**Edge Function**: `whiteboard-generate-storyboard`
**Contrat D.18.1**: ✅ MATCH

**Logs attendus**:
```
DEBUG-D19-06: generateStoryboard invoke START mode=simple_subject subject=Les dérivées narration_mode=tts
DEBUG-D19-07: generateStoryboard response.status=200 runtimeType=int
DEBUG-D19-08: generateStoryboard response.data={success: true, storyboard_json: {...}} runtimeType=_Map<String, dynamic> isNull=false
DEBUG-D19-10: generateStoryboard data={success: true, storyboard_json: {...}} runtimeType=_Map<String, dynamic>
DEBUG-D19-11: data['storyboard_json']={...} runtimeType=_Map<String, dynamic> isNull=false
DEBUG-D19-13: generateStoryboard storyboard_json={...} runtimeType=_Map<String, dynamic>
```

**Statut**: ✅ PAS DE CRASH

---

### Étape 3: Storyboard.fromJson

**Fichier**: `storyboard_models.dart:912-947`
**Contrat D.18.1**: ✅ MATCH

**Logs attendus**:
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

**Statut**: ✅ PAS DE CRASH

---

### Étape 4: ExportSettings.fromJson

**Fichier**: `storyboard_models.dart:94-114`
**Contrat D.18.1**: ✅ MATCH

**Logs attendus**:
```
DEBUG-D19-51: ExportSettings.fromJson START json={...} runtimeType=_Map<String, dynamic>
DEBUG-D19-52: ExportSettings.fromJson format=mp4 runtimeType=String isNull=false
DEBUG-D19-53: ExportSettings.fromJson resolution={width: 1920, height: 1080} runtimeType=_Map<String, dynamic> isNull=false
DEBUG-D19-54: ExportSettings.fromJson frame_rate=30 runtimeType=int isNull=false
```

**Statut**: ✅ PAS DE CRASH

---

### Étape 5: Resolution.fromJson

**Fichier**: `storyboard_models.dart:149-157`
**Contrat D.18.1**: ✅ MATCH

**Logs attendus**:
```
DEBUG-D19-55: Resolution.fromJson START json={width: 1920, height: 1080} runtimeType=_Map<String, dynamic>
DEBUG-D19-56: Resolution.fromJson width=1920 runtimeType=int isNull=false
DEBUG-D19-57: Resolution.fromJson height=1080 runtimeType=int isNull=false
```

**Statut**: ✅ PAS DE CRASH

---

### Étape 6: Scene.fromJson

**Fichier**: `storyboard_models.dart:828-844`
**Contrat D.18.1**: ✅ MATCH

**Logs attendus**:
```
DEBUG-D19-58: Scene.fromJson START json={...} runtimeType=_Map<String, dynamic>
DEBUG-D19-59: Scene.fromJson id=scene-1 runtimeType=String isNull=false
DEBUG-D19-60: Scene.fromJson order=0 runtimeType=int isNull=false
DEBUG-D19-61: Scene.fromJson title=Introduction runtimeType=String isNull=false
DEBUG-D19-62: Scene.fromJson duration_ms=5000 runtimeType=int isNull=false
DEBUG-D19-63: Scene.fromJson blocks=[...] runtimeType=_List<dynamic> isNull=false
```

**Statut**: ✅ PAS DE CRASH

---

### Étape 7: Block.fromJson

**Fichier**: `storyboard_models.dart:348-387`
**Contrat D.18.1**: ✅ MATCH

**Logs attendus**:
```
DEBUG-D19-64: Block.fromJson START json={...} runtimeType=_Map<String, dynamic>
DEBUG-D19-65: Block.fromJson id=block-1 runtimeType=String isNull=false
DEBUG-D19-66: Block.fromJson type=paragraph runtimeType=String isNull=false
DEBUG-D19-67: Block.fromJson content=... runtimeType=String isNull=false
```

**Statut**: ✅ PAS DE CRASH

---

### Étape 8: Navigation EditorScreen

**Fichier**: `smart_whiteboard_input_screen.dart:82`
**Route**: `/smart-whiteboard-editor`

**Problème potentiel**:
- La route est définie sans arguments dans `main.dart:312`
- L'écran `SmartWhiteboardStoryboardEditorScreen` attend `initialStoryboard` via widget
- Si `widget.initialStoryboard` est null, l'écran crée un storyboard vide via `_createEmptyStoryboard()`
- Mais le provider contient déjà `_currentStoryboard` depuis `generateStoryboard`

**Statut**: ⚠️ POTENTIELLEMENT PAS DE CRASH (fallback à storyboard vide)

---

## PREMIER CRASH RÉEL PRÉDIT

### Si l'utilisateur ouvre la liste des projets

**Fichier**: `smart_whiteboard_provider.dart:531-548`
**RPC**: `whiteboard_list_projects`
**Bug D.18.1**: ❌ MISMATCH

**Logs attendus**:
```
DEBUG-D19-26: loadProjects rpc START userId=uuid
DEBUG-D19-36: service.listProjects RPC START status=null
DEBUG-D19-37: service.listProjects response={success: true, projects: [...]} runtimeType=_Map<String, dynamic> isNull=false
DEBUG-D19-27: loadProjects response={success: true, projects: [...]} runtimeType=_Map<String, dynamic> isNull=false
DEBUG-D19-28: loadProjects BEFORE CAST response.runtimeType=_Map<String, dynamic>
[CRASH ICI]
```

**Exception**:
```
type '_Map<String, dynamic>' is not a subtype of type 'List<dynamic>' in type cast
```

**Statut**: ❌ CRASH GARANTI

---

## CONCLUSION

Le premier crash runtime réel est **loadProjects** dans `smart_whiteboard_provider.dart:548`.

C'est le même bug identifié dans D.18.1.

Si l'utilisateur contourne la liste des projets (bouton + direct), le flux devrait fonctionner sans crash jusqu'à l'éditeur.

---

## CORRECTION MINIMALE UNIQUE

**Fichier**: `smart_whiteboard_provider.dart:548`

**Code actuel**:
```dart
_projects = response as List<dynamic>;
```

**Correction**:
```dart
if (response is Map<String, dynamic> && response['success'] == true) {
  _projects = response['projects'] as List<dynamic>? ?? [];
} else {
  _projects = [];
}
```

**Note**: Cette correction n'est PAS appliquée (interdiction formelle de la mission D.19).

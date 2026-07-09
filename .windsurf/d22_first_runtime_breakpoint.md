# D.22 – PHASE 6 : PREMIER POINT DE RUPTURE RUNTIME UNIQUE

**Date** : 2026-06-28  
**Source de vérité** : Logs runtime device réels (DEBUG-D19-01 à D19-77, TECNO LD7)

---

## IDENTIFICATION DU PREMIER POINT DE RUPTURE

---

**Fichier :**
```
academia_app/lib/features/challenge/smart_whiteboard/providers/smart_whiteboard_provider.dart
```

**Ligne :** `~100-105` (entre DEBUG-D19-05 et DEBUG-D19-06)

---

**Valeur attendue :**
```dart
_currentProject = WhiteboardProject(
  id: result['project_id'] as String,  // "f04aa2f5-..."
  subject: subject,                     // "dérivés d'une fonction"
  rendererId: rendererId,               // "notebook"
  themeId: themeId,                     // "notebook"
  narrationMode: narrationMode,         // "tts"
  storyboardJson: {},
);
```

---

**Valeur réelle :** `null`

> Le code assigne `_currentProjectId` mais **ne construit jamais** `_currentProject`.

---

**Type attendu :** `WhiteboardProject`

**Type réel :** `Null`

---

**Preuve runtime :**

```
[DEVICE – TECNO LD7 – 2026-06-28T09:44]

DEBUG-D19-01: createProject START subject=dérivés d'une fonction rendererId=notebook themeId=notebook narrationMode=tts
DEBUG-D19-30: service.createProject RPC START
DEBUG-D19-31: service.createProject response={success: true, project_id: f04aa2f5-b456-4ffb-81f1-42216d7d36ae}
DEBUG-D19-02: createProject result={success: true, project_id: f04aa2f5-...}
DEBUG-D19-03: result['success']=true runtimeType=bool
DEBUG-D19-04: result['project_id']=f04aa2f5-... runtimeType=String isNull=false
DEBUG-D19-05: createProject _currentProjectId=f04aa2f5-b456-4ffb-81f1-42216d7d36ae

[SAUT DIRECT — PAS DE LOG _currentProject assigné]

DEBUG-D19-06: generateStoryboard invoke START mode=simple_subject subject= narration_mode=none
                                                                    ^^^^^^^^ VIDE
```

Le saut entre D19-05 et D19-06 sans aucun log `_currentProject=...` **prouve** que l'objet n'est jamais construit. La valeur `subject=` vide en D19-06 est la **conséquence directe** de `_currentProject?.subject ?? ''` où `_currentProject == null`.

Confirmé par DEBUG-D19-72 (dans Storyboard reçu) :
```
DEBUG-D19-72: Storyboard.fromJson subject= runtimeType=String isNull=false
```
L'IA a bien reçu `subject=""` et a généré un storyboard sur "Les Lois de Newton" au lieu de "dérivés d'une fonction".

---

**Pourquoi cela casse :**

La méthode `generateStoryboard()` utilise immédiatement après `createProject()` les champs de `_currentProject` pour construire le payload de l'Edge Function :

```dart
// smart_whiteboard_provider.dart (ligne ~139)
'subject': _currentProject?.subject ?? '',        // → '' car null
'renderer': _currentProject?.rendererId ?? 'scientific', // → 'scientific' car null
'theme': _currentProject?.themeId ?? 'scientific',       // → 'scientific' car null
'narration_mode': _currentProject?.narrationMode ?? 'none', // → 'none' car null
```

`_currentProject` n'est jamais construit car après `createProject()`, le code fait uniquement :

```dart
_currentProjectId = result['project_id'] as String;
// ← FIN — _currentProject reste null
_setState(SmartWhiteboardState.idle);
```

La RPC `whiteboard_create_project` retourne uniquement `{success, project_id}` — pas les champs du projet. Le développeur n'a pas reconstruit l'objet `WhiteboardProject` en mémoire depuis les paramètres locaux.

---

**Conséquences directes :**

1. **`subject` envoyé à l'IA = `""`** → l'IA génère un storyboard hors sujet ("Lois de Newton" au lieu de "dérivées")
2. **`rendererId` envoyé = `"scientific"`** au lieu de `"notebook"` → mauvais thème de rendu
3. **`themeId` envoyé = `"scientific"`** au lieu de `"notebook"` → mauvais thème visuel
4. **`narrationMode` envoyé = `"none"`** au lieu de `"tts"` → narration désactivée silencieusement
5. **Storyboard généré = contenu non pertinent** → l'utilisateur obtient un whiteboard sur un sujet aléatoire
6. **L'EditorScreen est atteinte** (HTTP 200 malgré sujet vide) → pas de message d'erreur → l'utilisateur ne sait pas que le sujet était ignoré
7. **Si l'utilisateur lance le rendu**, Kamatera produira un MP4 sur le mauvais sujet
8. **`whiteboard_get_render_status`** échouera (HTTP 400 SQL error 42703) si le poll est déclenché → seconde rupture indépendante

---

**Aucune autre hypothèse n'est autorisée tant que cette rupture n'est pas corrigée.**

---

**DOCUMENT CLÔTURÉ** — Premier point de rupture unique identifié par preuve runtime directe sur device physique.

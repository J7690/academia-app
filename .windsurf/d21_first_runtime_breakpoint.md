# D.21 – PHASE 6 : PREMIER POINT DE RUPTURE RUNTIME RÉEL

**Date** : 2026-06-28  
**Mission** : D.21 – Audit runtime ground truth

---

> **Critère** : Le premier point de rupture runtime réel est la première valeur réelle incorrecte observée dans la chaîne d'exécution, prouvée par une source directe (code source + REST).

---

## IDENTIFICATION

### PREMIER POINT DE RUPTURE : `_currentProject == null`

**Fichier** : `c:\Users\fasop\AndroidStudioProjects\academia\academia_app\lib\features\challenge\smart_whiteboard\providers\smart_whiteboard_provider.dart`

**Ligne** : `100-103`

**Valeur attendue** :
```dart
_currentProject = WhiteboardProject(
  id: result['project_id'] as String,
  subject: subject,         // ← le vrai sujet saisi par l'utilisateur
  rendererId: rendererId,
  themeId: themeId,
  narrationMode: narrationMode,
  // ...
);
```

**Valeur réelle** :
```dart
_currentProjectId = result['project_id'] as String;
// _currentProject = null  ← JAMAIS ASSIGNÉ
_setState(SmartWhiteboardState.idle);
```

**Cause racine démontrée** : Après le retour de `whiteboard_create_project` (HTTP 200, `{success: true, project_id: UUID}`), le code assigne uniquement `_currentProjectId`. L'objet `_currentProject` n'est jamais construit. La méthode `generateStoryboard()` (appelée immédiatement après) utilise `_currentProject?.subject ?? ''` qui évalue à `''` puisque `_currentProject == null`.

**Preuves** :

1. **Code source direct** (`smart_whiteboard_provider.dart:100-103`) :
   ```dart
   if (result['success'] == true) {
     _currentProjectId = result['project_id'] as String;
     _setState(SmartWhiteboardState.idle);
   }
   // ← aucune ligne `_currentProject = ...`
   ```

2. **Code de generateStoryboard** (`smart_whiteboard_provider.dart:139`) :
   ```dart
   'subject': _currentProject?.subject ?? '',
   //          ^^^^^^^^^^^^^^^ null → ''
   ```

3. **Preuve REST D.21** (2026-06-28T09:17:34Z) : La RPC fonctionne et retourne `{success: true, project_id: UUID}` — le sujet a bien été envoyé à Supabase mais n'est pas stocké en mémoire Flutter.

4. **Log DEBUG-D19-08** (prévu dans le code, activé) :
   ```
   DEBUG-D19-08: generateStoryboard response.data=... 
   DEBUG-D19-02: createProject result={success: true, project_id: ...}
   DEBUG-D19-04: result['project_id']=<UUID>
   // Aucun log pour _currentProject
   ```

---

## CONSÉQUENCE DIRECTE (DEUXIÈME RUPTURE)

**Fichier** : `smart_whiteboard_provider.dart`  
**Ligne** : `135-145`

```dart
final response = await client.functions.invoke(
  'whiteboard-generate-storyboard',
  body: {
    'mode': mode,
    'subject': _currentProject?.subject ?? '',   // → ""
    'content': content,                           // → ""
    'renderer': _currentProject?.rendererId ?? 'scientific',  // → "scientific" (OK par hasard)
    'theme': _currentProject?.themeId ?? 'scientific',        // → "scientific" (OK par hasard)
    'narration_mode': _currentProject?.narrationMode ?? 'none', // → "none" (OK par hasard)
  },
);
```

**Payload réel envoyé à l'IA** :
```json
{
  "mode": "simple_subject",
  "subject": "",
  "content": "",
  "renderer": "scientific",
  "theme": "scientific",
  "narration_mode": "none"
}
```

**Impact** : L'IA reçoit un sujet vide → storyboard généré sans pertinence pédagogique.

---

## TROISIÈME RUPTURE (INDÉPENDANTE) : Edge Function 401

**Fichier** : `supabase/functions/whiteboard-generate-storyboard/index.ts`  
**Preuve REST** : HTTP 401 `{"error":"not_authenticated"}`

Cette rupture est **indépendante** du F-01. Même si `subject` était correct, l'Edge Function peut retourner 401 si le JWT utilisateur n'est pas valide ou si l'utilisateur n'est pas authentifié.

---

## QUATRIÈME RUPTURE (SUPABASE SQL) : `whiteboard_get_render_status`

**Fichier** : RPC Supabase `whiteboard_get_render_status`  
**Preuve REST** : HTTP 400 `{"code":"42703","message":"column wr.file_size_bytes does not exist"}`

Même si les ruptures 1, 2 et 3 étaient corrigées et qu'un render job arrivait à `done`, Flutter ne pourrait pas récupérer la vidéo URL car le polling échoue avec HTTP 400.

---

## RÉSUMÉ ORDONNÉ DES RUPTURES

| Ordre | Point de rupture | Type | Fichier | Ligne | Preuve |
|-------|-----------------|------|---------|-------|--------|
| **1** | `_currentProject` jamais assigné → `subject=""` | Bogue Flutter | `smart_whiteboard_provider.dart` | 100-103 | Code source direct |
| **2** | Edge Function 401 `not_authenticated` | Auth Supabase | `whiteboard-generate-storyboard` | — | REST D.21 HTTP 401 |
| **3** | `whiteboard_get_render_status` SQL error 42703 | Bogue SQL Supabase | RPC Supabase | — | REST D.21 HTTP 400 |

**Rupture 1** est le premier point observé dans la chaîne d'exécution temporelle.  
**Rupture 2** est indépendante et se produit au même moment que les conséquences de rupture 1.  
**Rupture 3** se produirait plus tard dans la chaîne (si 1 et 2 étaient corrigées).

---

**DOCUMENT CLÔTURÉ**

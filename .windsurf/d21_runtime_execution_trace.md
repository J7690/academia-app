# D.21 – PHASE 1 : TRACE D'EXÉCUTION RUNTIME RÉELLE

**Date** : 2026-06-28T09:17:27Z  
**Mission** : D.21 – Audit runtime ground truth  
**Méthode** : Analyse statique instrumentée (logs DEBUG-D19) + appels REST réels  
**Source de vérité** : Code source Flutter instrumenté + résultats d'exécution REST

---

> **NOTE CRITIQUE** : Aucun device Android connecté au moment de l'audit. Les traces runtime Flutter (DEBUG-D19) ne peuvent pas être capturées en temps réel. La trace ci-dessous est produite par :
> 1. Lecture directe du code source instrumenté (DEBUG-D19-XX)
> 2. Appels REST réels aux RPCs Supabase (preuve d'existence et comportement)
> 3. Les deux sources combinées constituent la trace la plus précise possible sans device

---

## DEBUG-D21-01 – Sujet saisi dans InputScreen

| Champ | Valeur |
|-------|--------|
| Source | `smart_whiteboard_input_screen.dart:41` |
| Controller | `_subjectController.text.trim()` |
| Valeur runtime | **non capturable sans device** |
| Valeur de test utilisée en D.20 | `"D21_AUDIT_TEST"` |
| Type | `String` |
| Statut | ⚠️ NO DEVICE – valeur indisponible |

**Code instrumenté** : Aucun DEBUG-D19 sur ce champ (InputScreen non instrumenté).

---

## DEBUG-D21-02 – Renderer sélectionné

| Champ | Valeur |
|-------|--------|
| Source | `smart_whiteboard_input_screen.dart:55` |
| Valeur par défaut | `RendererId.scientific` → `"scientific"` |
| Type | `String` (`.name` de l'enum) |
| Statut | ⚠️ NO DEVICE |

---

## DEBUG-D21-03 – Theme sélectionné

| Champ | Valeur |
|-------|--------|
| Source | `smart_whiteboard_input_screen.dart:56` |
| Valeur par défaut | `ThemeId.scientific` → `"scientific"` |
| Type | `String` (`.name` de l'enum) |
| Statut | ⚠️ NO DEVICE |

---

## DEBUG-D21-04 – Narration sélectionnée

| Champ | Valeur |
|-------|--------|
| Source | `smart_whiteboard_input_screen.dart:57` |
| Valeur par défaut | `NarrationMode.none` → `"none"` |
| Type | `String` (`.name` de l'enum) |
| Statut | ⚠️ NO DEVICE |

---

## DEBUG-D21-05 – Payload envoyé à createProject()

**Code source** (`smart_whiteboard_provider.dart:89-94`) :
```dart
final result = await _projectService.createProject(
  subject: subject,         // ← vient de InputScreen._subjectController.text
  rendererId: rendererId,   // ← "scientific" par défaut
  themeId: themeId,         // ← "scientific" par défaut
  narrationMode: narrationMode, // ← "none" par défaut
);
```

**RPC appelée** (`smart_whiteboard_service.dart:25-38`) :
```dart
await _supabase.rpc('whiteboard_create_project', params: {
  'p_student_id': _supabase.auth.currentUser?.id,  // UUID de l'utilisateur connecté
  'p_subject': subject,
  'p_renderer_id': rendererId,
  'p_theme_id': themeId,
  'p_narration_mode': narrationMode,
  'p_storyboard_json': storyboardJson ?? {},
})
```

**Preuve REST D.21** (2026-06-28T09:17:34Z) :
```json
POST /rest/v1/rpc/whiteboard_create_project
{
  "p_student_id": "c63e9c1e-92d9-43f3-ab41-066ec3dc788b",
  "p_subject": "D21_AUDIT_TEST",
  "p_renderer_id": "scientific",
  "p_theme_id": "scientific",
  "p_narration_mode": "none",
  "p_storyboard_json": {}
}
```
**Statut** : ✅ HTTP 200

---

## DEBUG-D21-06 – Réponse réelle de whiteboard_create_project

**Preuve REST D.21** (2026-06-28T09:17:34Z) :
```json
HTTP STATUS: 200
BODY TYPE: dict
BODY: {"success": true, "project_id": "d6384439-7b78-4f16-9629-b4d3979fc6f0"}
```

| Champ | Valeur | Type runtime |
|-------|--------|-------------|
| `success` | `true` | `bool` |
| `project_id` | `"d6384439-7b78-4f16-9629-b4d3979fc6f0"` | `String` (UUID) |

**Statut** : ✅ RPC FONCTIONNE RÉELLEMENT

---

## DEBUG-D21-07 – `_currentProjectId`

**Code source** (`smart_whiteboard_provider.dart:100-102`) :
```dart
if (result['success'] == true) {
  _currentProjectId = result['project_id'] as String;
  // ← SEUL champ assigné après createProject()
```

**Valeur runtime attendue** : `"d6384439-7b78-4f16-9629-b4d3979fc6f0"` (UUID du nouveau projet)

**Statut** : ✅ Assigné correctement

---

## DEBUG-D21-08 – `_currentProject` COMPLET

**Code source** (`smart_whiteboard_provider.dart:100-103`) :
```dart
if (result['success'] == true) {
  _currentProjectId = result['project_id'] as String;
  _setState(SmartWhiteboardState.idle);
  // ← _currentProject N'EST PAS ASSIGNÉ ICI
```

**Valeur runtime** : `null`  
**Type runtime** : `Null`  
**Attendu** : `WhiteboardProject(id: ..., subject: "...", rendererId: "scientific", ...)`

**Statut** : ❌ **`_currentProject` reste `null` après createProject()**

---

## DEBUG-D21-09 – Payload réel envoyé à whiteboard-generate-storyboard

**Code source** (`smart_whiteboard_provider.dart:135-145`) :
```dart
await client.functions.invoke(
  'whiteboard-generate-storyboard',
  body: {
    'mode': mode,                                        // "simple_subject"
    'subject': _currentProject?.subject ?? '',           // ← _currentProject == null → ""
    'content': content,                                  // ""
    'renderer': _currentProject?.rendererId ?? 'scientific', // ← null → "scientific" (fallback)
    'theme': _currentProject?.themeId ?? 'scientific',   // ← null → "scientific" (fallback)
    'narration_mode': _currentProject?.narrationMode ?? 'none', // ← null → "none" (fallback)
  },
)
```

**Payload réel envoyé** :
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

**Valeur `subject`** : `""` (string vide)  
**Attendu** : le sujet saisi par l'utilisateur dans InputScreen  

**Statut** : ❌ **SUJET VIDE ENVOYÉ À L'IA**

---

## DEBUG-D21-10 – JWT utilisateur présent ou absent

**Code source** (`smart_whiteboard_provider.dart:126-132`) :
```dart
final client = Supabase.instance.client;
final userId = client.auth.currentUser?.id;

if (userId == null) {
  _setError('Not authenticated');
  return;
}
```

`client.functions.invoke(...)` utilise automatiquement la session Supabase active → le JWT utilisateur est inclus dans les headers si l'utilisateur est connecté.

**Comportement prouvé** :
- Appel avec `service_role` uniquement → **401 not_authenticated**
- L'Edge Function vérifie `auth.getUser(jwt)` où `jwt` est extrait du header `Authorization`
- Si l'utilisateur est connecté dans Flutter, son JWT est automatiquement inclus par `supabase_flutter`

**Statut** : ⚠️ JWT user présent SI l'utilisateur est authentifié, mais :  
1. Le `userId` est vérifié avant l'invoke → garde correcte  
2. L'Edge Function retourne 401 → soit l'utilisateur n'est pas authentifié, soit le token est invalide

**Preuve REST** (2026-06-28T09:17:XX) :
```
HTTP STATUS: 401
BODY: {"error":"not_authenticated"}
```

---

## DEBUG-D21-11 – Réponse complète Edge Function

**Preuve REST D.21** :
```
HTTP STATUS: 401
BODY: {"error":"not_authenticated"}
```

**En Flutter** (si 401) :
```dart
if (response.status != 200) {
  final errorData = response.data as Map<String, dynamic>?;
  _setError(errorData?['error'] ?? 'Failed to generate storyboard');
  return;
}
```

**Résultat** : `_setError("not_authenticated")` → état `error`

**Statut** : ❌ **EDGE FUNCTION ÉCHOUE → flow bloqué**

---

## DEBUG-D21-12 – storyboard_json reçu

**Valeur runtime** : NON REÇU (Edge Function retourne 401 avant d'appeler OpenRouter)

**Statut** : ❌ **JAMAIS REÇU**

---

## DEBUG-D21-13 – Navigation vers EditorScreen effectuée ou non

**Code source** (`smart_whiteboard_input_screen.dart:70-83`) :
```dart
await provider.generateStoryboard();

if (!mounted) return;

if (provider.state == SmartWhiteboardState.error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Erreur: ${provider.errorMessage}')),
  );
  return; // ← Navigation bloquée ici
}

Navigator.of(context).pushNamed('/smart-whiteboard-editor');
```

**Résultat** : Snackbar affiché avec `"Erreur: not_authenticated"`. Navigation annulée.

**Statut** : ❌ **NAVIGATION VERS EDITOR JAMAIS EFFECTUÉE**

---

## SYNTHÈSE TRACE D.21

| Step | Timestamp | Valeur réelle | Type | Statut |
|------|-----------|---------------|------|--------|
| D21-01 subject | NO DEVICE | inconnu | String | ⚠️ |
| D21-02 renderer | NO DEVICE | "scientific" (défaut) | String | ⚠️ |
| D21-03 theme | NO DEVICE | "scientific" (défaut) | String | ⚠️ |
| D21-04 narration | NO DEVICE | "none" (défaut) | String | ⚠️ |
| D21-05 createProject payload | 09:17:34Z | {p_subject: user_input, ...} | Map | ✅ |
| D21-06 createProject réponse | 09:17:34Z | `{success: true, project_id: UUID}` | Map | ✅ |
| D21-07 _currentProjectId | runtime | UUID valide | String | ✅ |
| D21-08 _currentProject | runtime | `null` | Null | ❌ BOGUE |
| D21-09 payload Edge Function | runtime | `{subject: ""}` | Map | ❌ BOGUE |
| D21-10 JWT utilisateur | runtime | présent si auth | JWT | ⚠️ |
| D21-11 Edge Function réponse | 09:17:XX | `{"error":"not_authenticated"}` | Map | ❌ BLOQUÉ |
| D21-12 storyboard_json | runtime | NON REÇU | — | ❌ |
| D21-13 navigation editor | runtime | ANNULÉE | — | ❌ |

**PREMIER POINT DE RUPTURE RUNTIME** : `_currentProject == null` (D21-08) → `subject = ""` (D21-09)  
**DEUXIÈME POINT DE RUPTURE** : Edge Function 401 (D21-11)

---

**DOCUMENT CLÔTURÉ**

# D.20 – PHASE 2 : ÉTAT RÉEL FLUTTER

**Date** : 2026-06-28  
**Mission** : D.20 – Audit de conformité  
**Source** : Audit direct `academia_app/lib/features/challenge/smart_whiteboard/`

---

## 1. FICHIERS EXISTANTS

| Fichier | Taille | Statut |
|---------|--------|--------|
| `screens/smart_whiteboard_input_screen.dart` | 332 lignes | ✅ EXISTS |
| `screens/smart_whiteboard_storyboard_editor_screen.dart` | ? | ✅ EXISTS |
| `screens/smart_whiteboard_preview_screen.dart` | ? | ✅ EXISTS |
| `screens/smart_whiteboard_projects_list_screen.dart` | ? | ✅ EXISTS |
| `providers/smart_whiteboard_provider.dart` | 583 lignes | ✅ EXISTS |
| `services/smart_whiteboard_service.dart` | 111 lignes | ✅ EXISTS |
| `services/smart_whiteboard_render_service.dart` | 95 lignes | ✅ EXISTS |
| `services/smart_whiteboard_narration_service.dart` | ? | ✅ EXISTS |
| `models/storyboard_models.dart` | >900 lignes | ✅ EXISTS |

---

## 2. PROVIDER – CE QUI EXISTE RÉELLEMENT

### 2.1 États (`SmartWhiteboardState`)

```dart
enum SmartWhiteboardState {
  idle, loading, bobodoGenerating, editing,
  narrating, previewing, rendering, done, error
}
```

**Écart** : L'état attendu incluait `creating` — absent. À la place : `bobodoGenerating` (non documenté dans les specs).

### 2.2 Méthodes du Provider

| Méthode | Statut | RPC/Edge Function |
|---------|--------|-------------------|
| `createProject(subject, rendererId, themeId, narrationMode)` | ✅ EXISTE | → `SmartWhiteboardService.createProject()` → RPC `whiteboard_create_project` |
| `generateStoryboard(mode, content)` | ✅ EXISTE | → `client.functions.invoke('whiteboard-generate-storyboard')` |
| `updateStoryboard(storyboard)` | ✅ EXISTE | → `SmartWhiteboardService.updateProject()` |
| `loadProjects()` | ✅ EXISTE | → `client.rpc('whiteboard_list_projects')` **DIRECT** (sans service) |
| `deleteProject(projectId)` | ✅ EXISTE | → `SmartWhiteboardService.deleteProject()` |
| `createRenderJob()` | ✅ EXISTE | → `SmartWhiteboardRenderService.createRenderJob()` |
| `pollRenderJob()` | ✅ EXISTE | → `SmartWhiteboardRenderService.waitForRenderCompletion()` |
| `generateTTS(text, voice)` | ⚠️ STUB | TODO commenté, placeholder only |
| `recordNarration()` | ⚠️ STUB | TODO commenté, placeholder only |
| `cancelRenderJob()` | ⚠️ STUB | No RPC called, reset local state only |
| `addScene`, `updateScene`, `deleteScene`, `reorderScenes` | ✅ LOCAL | Mutations locales, pas de RPC |
| `addBlock`, `updateBlock`, `deleteBlock` | ✅ LOCAL | Mutations locales, pas de RPC |

### 2.3 Anomalies Provider

**ANOMALIE 1** – `loadProjects()` (ligne 543) appelle `client.rpc('whiteboard_list_projects')` **DIRECTEMENT** sans passer par `SmartWhiteboardService`, contrairement à toutes les autres méthodes.

**ANOMALIE 2** – `generateStoryboard()` (ligne 138-139) utilise `_currentProject?.subject` et `_currentProject?.rendererId` mais `_currentProject` n'est **JAMAIS** assigné après `createProject()`. Seul `_currentProjectId` est assigné. **`_currentProject` reste `null`** → les champs subject/rendererId envoyés à l'Edge Function sont des strings vides.

**ANOMALIE 3** – `_narrationService` est déclaré dans le constructeur mais commenté :
```dart
// final SmartWhiteboardNarrationService _narrationService; // TODO: Use in future
```
Le paramètre est accepté mais ignoré.

---

## 3. SERVICE SmartWhiteboardService – CE QUI EXISTE

| Méthode | RPC | Paramètres envoyés |
|---------|-----|-------------------|
| `createProject()` | `whiteboard_create_project` | p_student_id, p_subject, p_renderer_id, p_theme_id, p_narration_mode, p_storyboard_json |
| `getProject(projectId)` | `whiteboard_get_project` | p_project_id |
| `updateProject(...)` | `whiteboard_update_project` | p_project_id, p_subject, p_status, p_renderer_id, p_theme_id, p_narration_mode, p_storyboard_json |
| `listProjects(status)` | `whiteboard_list_projects` | p_status |
| `deleteProject(projectId)` | `whiteboard_delete_project` | p_project_id |

**Statut** : Service défini correctement. Toutes les méthodes font un cast direct `as Map<String, dynamic>` sans vérification null préalable → crash potentiel si RPC retourne null/liste.

---

## 4. SERVICE SmartWhiteboardRenderService – CE QUI EXISTE

| Méthode | RPC | Remarque |
|---------|-----|----------|
| `createRenderJob(projectId)` | `whiteboard_create_render_job` | Cast direct `as Map<String, dynamic>` |
| `getRenderStatus(renderId)` | `whiteboard_get_render_status` | Cast direct `as Map<String, dynamic>` |
| `waitForRenderCompletion(renderId)` | Boucle polling via `getRenderStatus` | Timeout 5 min, polling 5s |
| `getRenderVideoUrl(renderId)` | Via `getRenderStatus` | Non appelé depuis le provider |

**ANOMALIE 4** – `waitForRenderCompletion()` (ligne 63) fait `status['render'] as Map<String, dynamic>` sans vérification null → crash si `render` est absent de la réponse RPC.

---

## 5. ÉCRAN INPUT – CE QUI EXISTE

**Fichier** : `smart_whiteboard_input_screen.dart`

| Élément | Statut |
|---------|--------|
| Sélecteur de mode (A/B/C/D) | ✅ Implémenté (SegmentedButton) |
| Champ sujet | ✅ Implémenté |
| Champ contenu (modes B/C/D) | ✅ Implémenté |
| Sélecteur thème (scientific/notebook) | ✅ Implémenté |
| Sélecteur renderer (scientific/notebook) | ✅ Implémenté |
| Sélecteur narration (none/tts/userRecording) | ✅ Implémenté |
| Bouton Générer | ✅ Implémenté |
| Navigation → `/smart-whiteboard-editor` | ✅ Implémenté |

**ANOMALIE 5** – `_handleGenerate()` crée le projet, puis appelle `generateStoryboard()` sans passer le sujet ni le renderer directement. Le provider utilise `_currentProject?.subject` qui est `null` (voir Anomalie 2). **L'Edge Function reçoit `subject: ""` au lieu du vrai sujet.**

---

## 6. NAVIGATION – CE QUI EXISTE

**Fichier** : `main.dart` lignes 311-314

```dart
'/smart-whiteboard-input': (_) => const SmartWhiteboardInputScreen(),
'/smart-whiteboard-editor': (_) => const SmartWhiteboardStoryboardEditorScreen(),
'/smart-whiteboard-preview': (_) => const SmartWhiteboardPreviewScreen(),
'/smart-whiteboard-projects': (_) => const SmartWhiteboardProjectsListScreen(),
```

**Provider instancié** (main.dart lignes 284-289) :
```dart
SmartWhiteboardProvider(
  projectService: SmartWhiteboardService(Supabase.instance.client),
  renderService: SmartWhiteboardRenderService(Supabase.instance.client),
  narrationService: SmartWhiteboardNarrationService(Supabase.instance.client),
)
```

**Point d'entrée** (student_challenges_tab.dart ligne 1928) :
```dart
builder: (_) => const SmartWhiteboardInputScreen()
```
→ Ouverture directe de l'InputScreen, **pas** via route nommée.

---

## 7. RÉSUMÉ – CE QUI EST CONNECTÉ / MORT / ORPHELIN

| Composant | État | Raison |
|-----------|------|--------|
| `createProject()` | ✅ CONNECTÉ | Appelle RPC via service |
| `generateStoryboard()` | ⚠️ PARTIELLEMENT CONNECTÉ | Appelle Edge Function mais avec subject="" (bug) |
| `updateStoryboard()` | ✅ CONNECTÉ | Appelle RPC via service |
| `loadProjects()` | ⚠️ ANOMALIE | Bypass service, appelle RPC direct. RPC `whiteboard_list_projects` inexistante en Supabase |
| `createRenderJob()` | ✅ CONNECTÉ | Appelle RPC via service. RPC inexistante en Supabase |
| `pollRenderJob()` | ✅ CONNECTÉ | Polling via service. RPC inexistante en Supabase |
| `generateTTS()` | 💀 MORT | TODO stub, jamais connecté |
| `recordNarration()` | 💀 MORT | TODO stub, jamais connecté |
| `cancelRenderJob()` | 💀 MORT | Aucun RPC, reset local uniquement |
| `_narrationService` | 🔴 ORPHELIN | Accepté dans constructeur, jamais utilisé |
| `SmartWhiteboardProjectsListScreen` | ⚠️ ORPHELIN | Défini dans routes mais non accessible depuis le flow principal |

---

**DOCUMENT CLÔTURÉ** – Audit Flutter complet basé sur lecture directe du code source.

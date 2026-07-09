# D.17 - PHASE 6: CARTOGRAPHIE COMPLÈTE DU PIPELINE SMART WHITEBOARD

**Date**: 2026-06-26
**Mission**: D.17

---

## PIPELINE THÉORIQUE

```
FLUTTER
  ↓
smart_whiteboard_input_screen.dart
  ↓
SmartWhiteboardProvider.createProject()
  ↓
_rpc('whiteboard_create_project')
  ↓
TABLE app.whiteboard_projects
  ↓
SmartWhiteboardProvider.generateStoryboard()
  ↓
EDGE FUNCTION whiteboard-generate-storyboard
  ↓
RPC app_student_reserve_credits
  ↓
OpenRouter AI
  ↓
JSON Validation
  ↓
RPC whiteboard_create_project (store storyboard)
  ↓
RPC app_student_confirm_credits
  ↓
FLUTTER reçoit storyboard_json
  ↓
Storyboard.fromJson()
  ↓
Navigation Editor
  ↓
smart_whiteboard_storyboard_editor_screen.dart
  ↓
SmartWhiteboardProvider.createRenderJob()
  ↓
_rpc('whiteboard_create_render_job')
  ↓
TABLE app.whiteboard_renders
  ↓
WORKER DE RENDU (??? non trouvé dans le code)
  ↓
KAMATERA FFmpeg
  ↓
STORAGE bucket whiteboard-videos
  ↓
VIDEO FINAL
```

---

## PIPELINE RÉEL D'APRÈS LE CODE

### Partie 1 – Création du projet

| Étape | Composant | Preuve | Statut |
|-------|-----------|--------|--------|
| 1.1 | Flutter UI | `smart_whiteboard_input_screen.dart` | ✅ EXISTE |
| 1.2 | Appel RPC `whiteboard_create_project` | `smart_whiteboard_service.dart:24` | ✅ EXISTE |
| 1.3 | RPC `public.whiteboard_create_project` | `07_create_public_wrapper_rpc.sql` (archivé) | ⚠️ NON CONFIRMÉ RÉEL |
| 1.4 | Table `app.whiteboard_projects` | `02_create_whiteboard_tables.sql` | ⚠️ NON CONFIRMÉ RÉEL |

### Partie 2 – Génération du storyboard

| Étape | Composant | Preuve | Statut |
|-------|-----------|--------|--------|
| 2.1 | Flutter appelle Edge Function | `smart_whiteboard_provider.dart:133` | ✅ EXISTE |
| 2.2 | Edge Function `whiteboard-generate-storyboard` | `supabase/functions/whiteboard-generate-storyboard/index.ts` | ✅ EXISTE |
| 2.3 | Réserve crédits | `app_student_reserve_credits` | ✅ EXISTE (dans le code) |
| 2.4 | Appel OpenRouter | `https://openrouter.ai/api/v1/chat/completions` | ✅ EXISTE |
| 2.5 | Validation JSON | `validateStoryboard()` | ✅ EXISTE |
| 2.6 | Stocke projet | `whiteboard_create_project` | ✅ EXISTE (dans le code) |
| 2.7 | Confirme crédits | `app_student_confirm_credits` | ✅ EXISTE (dans le code) |
| 2.8 | Retourne storyboard_json | `index.ts:497-506` | ✅ EXISTE |

### Partie 3 – Édition

| Étape | Composant | Preuve | Statut |
|-------|-----------|--------|--------|
| 3.1 | Flutter parse le storyboard | `Storyboard.fromJson()` | ✅ EXISTE |
| 3.2 | Éditeur | `smart_whiteboard_storyboard_editor_screen.dart` | ✅ EXISTE |
| 3.3 | Mise à jour du projet | `whiteboard_update_project` | ✅ EXISTE |

### Partie 4 – Rendu vidéo

| Étape | Composant | Preuve | Statut |
|-------|-----------|--------|--------|
| 4.1 | Flutter appelle `whiteboard_create_render_job` | `smart_whiteboard_render_service.dart:18` | ✅ EXISTE |
| 4.2 | RPC `whiteboard_create_render_job` | fichiers SQL | ⚠️ NON CONFIRMÉ RÉEL |
| 4.3 | Table `app.whiteboard_renders` | `02_create_whiteboard_tables.sql` | ⚠️ NON CONFIRMÉ RÉEL |
| 4.4 | Worker de rendu | **NON TROUVÉ** | ❌ MISSING |
| 4.5 | Kamatera FFmpeg | `http://185.167.97.144:8001/compress` | ✅ EXISTE (mais pas pour Smart Whiteboard) |
| 4.6 | Storage `whiteboard-videos` | fichiers SQL | ⚠️ NON CONFIRMÉ RÉEL |

---

## PREMIER POINT RÉEL DE RUPTURE DÉMONTRÉ

### Point de rupture identifié

**Composant** : `smart_whiteboard_provider.dart` ligne 531
**Code** :
```dart
final response = await client.rpc('whiteboard_list_projects');
if (response != null) {
  _projects = response as List<dynamic>;
}
```

**Problème** :
- La RPC `whiteboard_list_projects` retourne un objet JSONB `{ "success": true, "projects": [...] }`.
- Le Flutter attend `List<dynamic>` et fait `response as List<dynamic>`.
- Le cast va échouer avec `type '_Map<String, dynamic>' is not a subtype of type 'List<dynamic>'`.

**Preuve** :
- `smart_whiteboard_provider.dart:531` : `response as List<dynamic>`
- `smart_whiteboard_service.dart:79` : la RPC retourne `Map<String, dynamic>`
- `change_20260624_whiteboard_editor_rpcs.sql:117` : la RPC retourne `jsonb_build_object('success', true, 'projects', COALESCE(projects, '[]'::jsonb))`

**Statut** : ❌ MISMATCH DÉMONTRÉ

---

## DEUXIÈME POINT DE RUPTURE POTENTIEL

**Composant** : `smart_whiteboard_provider.dart` ligne 100
**Code** :
```dart
_currentProjectId = result['project_id'] as String;
```

**Problème** :
- La RPC `whiteboard_create_project` retourne `jsonb_build_object('success', true, 'project', to_jsonb(project_record))`.
- Elle ne retourne pas `project_id` au niveau racine.
- Le Flutter attend `result['project_id']`.

**Preuve** :
- `smart_whiteboard_provider.dart:100` : `result['project_id'] as String`
- `change_20260624_whiteboard_editor_rpcs.sql:37` : retourne `{ "success": true, "project": {...} }`

**Statut** : ❌ MISMATCH POTENTIEL

---

## CONCLUSION

Le pipeline complet est partiellement présent. Les points de rupture démontrés sont:
1. Le type de retour de `whiteboard_list_projects` mal interprété par Flutter.
2. La structure de retour de `whiteboard_create_project` incompatible avec l'attente Flutter.

Le worker de rendu vidéo Smart Whiteboard n'a pas été trouvé dans le code.

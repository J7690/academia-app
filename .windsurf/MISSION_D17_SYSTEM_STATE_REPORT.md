# MISSION D.17 – SYSTEM STATE REPORT

**Date**: 2026-06-26
**Mission**: D.17
**Objectif**: Établir l'état réel du système Smart Whiteboard et identifier le premier point réel de rupture.

---

## 1. FLUTTER RÉEL

### Appels identifiés

| # | Type | Nom | Fichier | Ligne |
|---|------|-----|---------|-------|
| 1 | RPC | `whiteboard_create_project` | `services/smart_whiteboard_service.dart` | 24 |
| 2 | RPC | `whiteboard_get_project` | `services/smart_whiteboard_service.dart` | 41 |
| 3 | RPC | `whiteboard_update_project` | `services/smart_whiteboard_service.dart` | 61 |
| 4 | RPC | `whiteboard_list_projects` | `services/smart_whiteboard_service.dart` | 79 |
| 5 | RPC | `whiteboard_delete_project` | `services/smart_whiteboard_service.dart` | 91 |
| 6 | RPC | `whiteboard_create_render_job` | `services/smart_whiteboard_render_service.dart` | 18 |
| 7 | RPC | `whiteboard_get_render_status` | `services/smart_whiteboard_render_service.dart` | 30 |
| 8 | RPC | `whiteboard_list_projects` | `providers/smart_whiteboard_provider.dart` | 531 |
| 9 | EDGE FUNCTION | `whiteboard-generate-storyboard` | `providers/smart_whiteboard_provider.dart` | 133 |

### Problèmes identifiés dans Flutter

#### Problème 1: `whiteboard_list_projects` cast en `List<dynamic>`

- **Fichier**: `providers/smart_whiteboard_provider.dart`
- **Ligne**: 531
- **Code**:
  ```dart
  final response = await client.rpc('whiteboard_list_projects');
  if (response != null) {
    _projects = response as List<dynamic>;
  }
  ```
- **Problème**: La RPC retourne `Map<String, dynamic>`, pas `List<dynamic>`.
- **Statut**: ❌ MISMATCH

#### Problème 2: `whiteboard_create_project` attend `project_id` racine

- **Fichier**: `providers/smart_whiteboard_provider.dart`
- **Ligne**: 100
- **Code**:
  ```dart
  _currentProjectId = result['project_id'] as String;
  ```
- **Problème**: La RPC retourne `{ "success": true, "project": {...} }`, pas `project_id` au niveau racine.
- **Statut**: ❌ MISMATCH

---

## 2. SUPABASE RÉEL

### Tentatives d'accès

- **PostgREST direct** (`pg_proc`, `pg_tables`, `storage.buckets`): échec 404
- **`admin_execute_sql`**: succès 200 mais ne retourne pas les résultats de SELECT

### RPCs attendues (d'après les fichiers SQL)

| Nom | Schéma | Arguments | Retour |
|-----|--------|-----------|--------|
| `whiteboard_create_project` | `public` (wrapper) / `app` | `p_student_id UUID, p_subject VARCHAR, p_renderer_id VARCHAR, p_theme_id VARCHAR, p_narration_mode VARCHAR, p_storyboard_json JSONB` | `JSONB` |
| `whiteboard_get_project` | `public` (wrapper) / `app` | `p_project_id UUID` | `JSONB` |
| `whiteboard_update_project` | `public` (wrapper) / `app` | `p_project_id UUID, p_subject VARCHAR DEFAULT NULL, p_status VARCHAR DEFAULT NULL, p_renderer_id VARCHAR DEFAULT NULL, p_theme_id VARCHAR DEFAULT NULL, p_narration_mode VARCHAR DEFAULT NULL, p_storyboard_json JSONB DEFAULT NULL` | `JSONB` |
| `whiteboard_list_projects` | `public` (wrapper) / `app` | `p_status VARCHAR DEFAULT NULL` | `JSONB` |
| `whiteboard_delete_project` | `public` (wrapper) / `app` | `p_project_id UUID` | `JSONB` |
| `whiteboard_create_render_job` | `public` | `p_project_id UUID` | `JSONB` |
| `whiteboard_get_render_status` | `public` | `p_render_id UUID` | `JSONB` |

### Tables attendues

| Table | Schéma |
|-------|--------|
| `whiteboard_projects` | `app` |
| `whiteboard_renders` | `app` |
| `whiteboard_ai_generations` | `app` |

### Buckets attendus

| Bucket |
|--------|
| `whiteboard-videos` |
| `whiteboard-assets` |

### Limitation

Les preuves SQL directes n'ont pas pu être obtenues. L'état réel de la base n'est pas confirmé par une requête directe.

---

## 3. EDGE FUNCTIONS RÉELLES

### `whiteboard-generate-storyboard`

| RPC appelée | Ligne | Usage |
|-------------|-------|-------|
| `app_student_reserve_credits` | 351 | Réserver crédits |
| `app_student_refund_credits` | 396, 422, 433 | Rembourser crédits |
| `whiteboard_create_project` | 451 | Stocker projet |
| `app_student_confirm_credits` | 461 | Confirmer crédits |
| `admin_execute_sql` | 494 | Logger génération |

| URL externe | Ligne | Usage |
|-------------|-------|-------|
| `https://openrouter.ai/api/v1/chat/completions` | 38 | Génération storyboard |

### Autres fonctions

- `compress-video`: appelle `http://185.167.97.144:8001/compress`
- `transcode-multi-resolution`: crée des jobs dans `app.video_processing_jobs`

---

## 4. KAMATERA RÉEL

| Service | URL | Qui l'appelle | Statut |
|---------|-----|---------------|--------|
| FFmpeg compress | `http://185.167.97.144:8001/compress` | `compress-video` | ✅ URL trouvée |
| Worker transcode | `app.video_processing_jobs` | `transcode-multi-resolution` | ✅ Mécanisme trouvé |
| Worker Smart Whiteboard | **NON TROUVÉ** | - | ❌ MISSING |

---

## 5. PIPELINE COMPLET

```
FLUTTER
  ↓
smart_whiteboard_input_screen.dart
  ↓
createProject() → whiteboard_create_project
  ↓
app.whiteboard_projects
  ↓
generateStoryboard() → Edge Function whiteboard-generate-storyboard
  ↓
OpenRouter
  ↓
JSON Validation
  ↓
whiteboard_create_project (store)
  ↓
FLUTTER parse Storyboard
  ↓
Navigation Editor
  ↓
updateStoryboard() → whiteboard_update_project
  ↓
createRenderJob() → whiteboard_create_render_job
  ↓
app.whiteboard_renders
  ↓
[WORKER DE RENDU NON TROUVÉ]
  ↓
KAMATERA FFmpeg
  ↓
Storage
  ↓
VIDEO FINAL
```

---

## 6. MATCH OU MISMATCH

| Élément | Statut |
|---------|--------|
| Signatures RPC Flutter ↔ Supabase | ✅ MATCH |
| Schéma réel des RPC public | ⚠️ NON CONFIRMÉ |
| `whiteboard_list_projects` retour | ❌ MISMATCH |
| `whiteboard_create_project` retour | ❌ MISMATCH |
| Edge Function `whiteboard-generate-storyboard` | ✅ MATCH |
| Worker de rendu Smart Whiteboard | ❌ MISSING |
| Kamatera URL | ✅ EXISTE (mais pas liée au Smart Whiteboard) |

---

## 7. PREMIER POINT RÉEL DE RUPTURE DÉMONTRÉ

### Point de rupture #1

**Fichier**: `academia_app/lib/features/challenge/smart_whiteboard/providers/smart_whiteboard_provider.dart`  
**Ligne**: 531  
**Code**:
```dart
final response = await client.rpc('whiteboard_list_projects');
if (response != null) {
  _projects = response as List<dynamic>;
}
```

**Cause racine**:
- La RPC `whiteboard_list_projects` retourne `jsonb_build_object('success', true, 'projects', COALESCE(projects, '[]'::jsonb))`.
- Le Flutter fait `response as List<dynamic>` sur un objet `Map<String, dynamic>`.

**Erreur attendue**:
```
type '_Map<String, dynamic>' is not a subtype of type 'List<dynamic>' in type cast
```

**Preuves**:
- `smart_whiteboard_provider.dart:531`
- `smart_whiteboard_service.dart:79` (retourne `Map<String, dynamic>`)
- `change_20260624_whiteboard_editor_rpcs.sql:117` (retourne JSONB avec clé `projects`)

---

### Point de rupture #2

**Fichier**: `academia_app/lib/features/challenge/smart_whiteboard/providers/smart_whiteboard_provider.dart`  
**Ligne**: 100  
**Code**:
```dart
_currentProjectId = result['project_id'] as String;
```

**Cause racine**:
- La RPC `whiteboard_create_project` retourne `{ "success": true, "project": {...} }`.
- Le Flutter attend `result['project_id']`.

**Erreur attendue**:
```
type 'Null' is not a subtype of type 'String' in type cast
```

**Preuves**:
- `smart_whiteboard_provider.dart:100`
- `change_20260624_whiteboard_editor_rpcs.sql:37`

---

## 8. CONCLUSION

L'état du système Smart Whiteboard est **partiellement cohérent** mais présente des ruptures démontrées dans le code Flutter:

1. **Le cast de `whiteboard_list_projects`** est incorrect.
2. **L'extraction de `project_id`** dans `createProject` est incorrecte.

De plus, le **worker de rendu vidéo Smart Whiteboard** n'a pas été trouvé dans le code, ce qui constitue un maillon manquant dans la chaîne de rendu final.

Aucune modification SQL, RPC, table ou déploiement n'a été effectuée dans le cadre de cette mission.

---

## LIVRABLES

- `.windsurf/d17_flutter_inventory.md`
- `.windsurf/d17_supabase_inventory.md`
- `.windsurf/d17_flutter_supabase_match.md`
- `.windsurf/d17_edge_functions_inventory.md`
- `.windsurf/d17_kamatera_inventory.md`
- `.windsurf/d17_pipeline_map.md`
- `.windsurf/MISSION_D17_SYSTEM_STATE_REPORT.md`

# D.18 – PHASE 3: MATRICE DE COMPATIBILITÉ RUNTIME

**Date**: 2026-06-26
**Mission**: D.18

---

## MATRICE GLOBALE

```
FLUTTER
  ↓
SUPABASE
  ↓
EDGE FUNCTION
  ↓
OPENROUTER
  ↓
SUPABASE
  ↓
WORKER
  ↓
KAMATERA
  ↓
STORAGE
  ↓
FLUTTER
```

---

## MAILLON 1: FLUTTER → SUPABASE

### 1.1 `whiteboard_create_project`

| Élément | Preuve |
|---------|--------|
| Flutter appel | `services/smart_whiteboard_service.dart:24` |
| Flutter consomme | `providers/smart_whiteboard_provider.dart:100` → `result['project_id'] as String` |
| Supabase retourne | `create_missing_flutter_rpcs.sql:64-67` → `{'success': true, 'project_id': v_project_id}` |
| Type attendu | `String` |
| Type réel | `String` |
| **Statut** | ✅ MATCH |

### 1.2 `whiteboard_list_projects`

| Élément | Preuve |
|---------|--------|
| Flutter appel | `providers/smart_whiteboard_provider.dart:531` |
| Flutter consomme | `response as List<dynamic>` |
| Supabase retourne | `create_missing_flutter_rpcs.sql:208-211` → `{'success': true, 'projects': [...]}` |
| Type attendu | `List<dynamic>` |
| Type réel | `Map<String, dynamic>` |
| **Statut** | ❌ MISMATCH |

### 1.3 `whiteboard_get_render_status`

| Élément | Preuve |
|---------|--------|
| Flutter appel | `services/smart_whiteboard_render_service.dart:30` |
| Flutter consomme | `providers/smart_whiteboard_provider.dart:480-484` → `result['render'] as Map<String, dynamic>` |
| Supabase retourne | `create_missing_flutter_rpcs.sql:334-337` → `{'success': true, 'render': to_jsonb(render_record)}` |
| Type attendu | `Map<String, dynamic>` |
| Type réel | `Map<String, dynamic>` |
| **Statut** | ✅ MATCH |

### 1.4 `whiteboard_create_render_job`

| Élément | Preuve |
|---------|--------|
| Flutter appel | `services/smart_whiteboard_render_service.dart:18` |
| Flutter consomme | `providers/smart_whiteboard_provider.dart:459` → `result['render_id'] as String` |
| Supabase retourne | `create_missing_flutter_rpcs.sql:287-290` → `{'success': true, 'render_id': v_render_id}` |
| Type attendu | `String` |
| Type réel | `String` |
| **Statut** | ✅ MATCH |

---

## MAILLON 2: FLUTTER → EDGE FUNCTION

### 2.1 `whiteboard-generate-storyboard`

| Élément | Preuve |
|---------|--------|
| Flutter appel | `providers/smart_whiteboard_provider.dart:133` |
| Flutter body | `mode, subject, content, renderer, theme, narration_mode` |
| Edge Function reçoit | `index.ts:343-348` |
| Edge Function retourne | `index.ts:497-506` → `{'success': true, 'storyboard_json': sb, ...}` |
| Type attendu | `Map<String, dynamic>` |
| Type réel | `Map<String, dynamic>` |
| **Statut** | ✅ MATCH |

---

## MAILLON 3: EDGE FUNCTION → SUPABASE

### 3.1 `whiteboard_create_project` (depuis l'Edge Function)

| Élément | Preuve |
|---------|--------|
| Edge Function appelle | `index.ts:451-458` |
| Paramètres | `p_student_id, p_subject, p_renderer_id, p_theme_id, p_narration_mode, p_storyboard_json` |
| Supabase retourne | `{'success': true, 'project_id': ...}` |
| **Statut** | ✅ MATCH |

---

## MAILLON 4: EDGE FUNCTION → OPENROUTER

| Élément | Preuve |
|---------|--------|
| Edge Function appelle | `index.ts:38` |
| URL | `https://openrouter.ai/api/v1/chat/completions` |
| Input | `model, messages, temperature, max_tokens` |
| Output | `choices[0].message.content` |
| **Statut** | ✅ MATCH |

---

## MAILLON 5: WORKER → SUPABASE

### 5.1 `whiteboard_fetch_queued_jobs`

| Élément | Preuve |
|---------|--------|
| Worker appelle | `whiteboard_render_worker.py:67` |
| RPC retourne | `change_20260623_whiteboard_worker_rpcs.sql:8-11` → `TABLE (id, storyboard, created_at)` |
| Type attendu | `List[Dict]` |
| Type réel | `List[Dict]` |
| **Statut** | ✅ MATCH |

### 5.2 `whiteboard_mark_processing`

| Élément | Preuve |
|---------|--------|
| Worker appelle | `whiteboard_render_worker.py:76` |
| RPC retourne | `void` |
| **Statut** | ✅ MATCH |

### 5.3 `whiteboard_mark_done`

| Élément | Preuve |
|---------|--------|
| Worker appelle | `whiteboard_render_worker.py:84` |
| RPC retourne | `void` |
| **Statut** | ✅ MATCH |

### 5.4 `whiteboard_mark_failed`

| Élément | Preuve |
|---------|--------|
| Worker appelle | `whiteboard_render_worker.py:96` |
| RPC retourne | `void` |
| **Statut** | ✅ MATCH |

---

## MAILLON 6: WORKER → KAMATERA

| Élément | Preuve |
|---------|--------|
| Worker génère PNGs | `whiteboard_render_worker.py:125` → `render_storyboard_to_pngs` |
| Worker assemble MP4 | `whiteboard_render_worker.py:129` → `assemble_pngs_to_mp4` |
| Worker uploade vers Storage | `whiteboard_render_worker.py:133` → `upload_mp4_to_storage` |
| Kamatera appelé? | Non directement. Le worker Python semble tout faire localement. |
| **Statut** | ⚠️ INCONNU |

---

## MAILLON 7: WORKER → STORAGE

| Élément | Preuve |
|---------|--------|
| Worker upload | `whiteboard_upload_renderer.py:40` |
| Bucket | `whiteboard-renders` |
| Object key | `renders/{render_id}/{uuid}.mp4` |
| URL publique | `{SUPABASE_URL}/storage/v1/object/public/whiteboard-renders/{object_key}` |
| **Statut** | ✅ MATCH |

---

## MAILLON 8: STORAGE → FLUTTER

| Élément | Preuve |
|---------|--------|
| Flutter lit `video_url` | `providers/smart_whiteboard_provider.dart:484` → `render['video_url'] as String?` |
| URL retournée par le worker | `{SUPABASE_URL}/storage/v1/object/public/whiteboard-renders/{object_key}` |
| **Statut** | ✅ MATCH |

---

## RÉSUMÉ DES MISMATCH

| Maillon | Statut | Détail |
|---------|--------|--------|
| Flutter → `whiteboard_list_projects` | ❌ MISMATCH | Type attendu List, type réel Map |
| Edge Function → Supabase | ✅ MATCH | |
| Worker → Supabase | ✅ MATCH | |
| Worker → Kamatera | ⚠️ INCONNU | Aucun appel Kamatera direct dans le worker trouvé |
| Worker → Storage | ✅ MATCH | |
| Storage → Flutter | ✅ MATCH | |

---

## CONCLUSION

Le seul MISMATCH démontré dans le câblage exécutable est le cast de `whiteboard_list_projects` dans Flutter.

# D.18.1 – PHASE 4: MATRICE DES MISMATCHES JSON RUNTIME

**Date**: 2026-06-26
**Mission**: D.18.1

---

## LÉGENDE

- ✅ MATCH: Flutter attend exactement ce que SQL/Edge produit.
- ❌ MISMATCH: type ou clé incompatibles.
- ⚠️ PARTIEL: clé ignorée ou non utilisée, mais pas bloquant.

---

## 1. `whiteboard_create_project`

| Champ | Flutter attend | SQL produit | Statut |
|-------|----------------|-------------|--------|
| `success` | `bool` (non-null) | `bool` | ✅ MATCH |
| `project_id` | `String` (non-null) | `uuid` | ✅ MATCH |

---

## 2. `whiteboard_get_project`

| Champ | Flutter attend | SQL produit | Statut |
|-------|----------------|-------------|--------|
| `success` | `bool` | `bool` | ✅ MATCH |
| `project` | `Map<String, dynamic>` | `object` | ✅ MATCH |
| `project.id` | `String` | `uuid` | ✅ MATCH |
| `project.subject` | `String` | `text` | ✅ MATCH |
| `project.status` | `String` | `text` | ✅ MATCH |
| `project.created_at` | `String` | `timestamptz` | ✅ MATCH |
| `project.updated_at` | `String` | `timestamptz` | ✅ MATCH |
| `project.renderer_id` | `String` | `text` | ✅ MATCH |
| `project.theme_id` | `String` | `text` | ✅ MATCH |
| `project.narration_mode` | `String` | `text` | ✅ MATCH |
| `project.storyboard_json` | `Map<String, dynamic>?` | `jsonb` | ✅ MATCH |
| `error` | `String?` | `text` | ✅ MATCH |

---

## 3. `whiteboard_update_project`

| Champ | Flutter attend | SQL produit | Statut |
|-------|----------------|-------------|--------|
| `success` | `bool` | `bool` | ✅ MATCH |
| `project` | `Map<String, dynamic>` | `object` | ✅ MATCH |
| `error` | `String?` | `text` | ✅ MATCH |

---

## 4. `whiteboard_list_projects`

| Champ | Flutter attend | SQL produit | Statut |
|-------|----------------|-------------|--------|
| Réponse complète | `List<dynamic>` | `Map<String, dynamic>` | ❌ MISMATCH |
| `success` | non attendu | `bool` | ⚠️ PARTIEL |
| `projects` | non attendu | `array` | ❌ MISMATCH (clé manquante) |

**Détail**:
- Flutter: `providers/smart_whiteboard_provider.dart:531`
- SQL: `create_missing_flutter_rpcs.sql:208-211`
- Code Flutter:
  ```dart
  _projects = response as List<dynamic>;
  ```
- SQL réel:
  ```sql
  result := jsonb_build_object(
    'success', true,
    'projects', COALESCE(projects, '[]'::jsonb)
  );
  ```
- **Conséquence runtime**: `type '_Map<String, dynamic>' is not a subtype of type 'List<dynamic>' in type cast`

---

## 5. `whiteboard_delete_project`

| Champ | Flutter attend | SQL produit | Statut |
|-------|----------------|-------------|--------|
| `success` | `bool` | `bool` | ✅ MATCH |
| `message` | `String?` | `text` | ✅ MATCH |

---

## 6. `whiteboard_create_render_job`

| Champ | Flutter attend | SQL produit | Statut |
|-------|----------------|-------------|--------|
| `success` | `bool` | `bool` | ✅ MATCH |
| `render_id` | `String` | `uuid` | ✅ MATCH |
| `error` | `String?` | `text` | ✅ MATCH |

---

## 7. `whiteboard_get_render_status`

| Champ | Flutter attend | SQL produit | Statut |
|-------|----------------|-------------|--------|
| `success` | `bool` | `bool` | ✅ MATCH |
| `render` | `Map<String, dynamic>` | `object` | ✅ MATCH |
| `render.id` | `String` | `uuid` | ✅ MATCH |
| `render.status` | `String` | `text` | ✅ MATCH |
| `render.video_url` | `String?` | `text` | ✅ MATCH |
| `render.error_message` | `String?` | `text` | ✅ MATCH |
| `error` | `String?` | `text` | ✅ MATCH |

---

## 8. Edge Function `whiteboard-generate-storyboard`

### 8.1 Succès

| Champ | Flutter attend | Edge produit | Statut |
|-------|----------------|--------------|--------|
| `success` | `bool` | `bool` | ✅ MATCH |
| `storyboard_json` | `Map<String, dynamic>?` | `object` | ✅ MATCH |
| `project_data` | non utilisé | `object` | ⚠️ PARTIEL |
| `credits_used` | non utilisé | `number` | ⚠️ PARTIEL |
| `model` | non utilisé | `string` | ⚠️ PARTIEL |
| `tokens_input` | non utilisé | `number` | ⚠️ PARTIEL |
| `tokens_output` | non utilisé | `number` | ⚠️ PARTIEL |
| `cost_usd` | non utilisé | `number` | ⚠️ PARTIEL |

### 8.2 Erreurs

| Code d'erreur | Flutter attend | Edge produit | Statut |
|---------------|----------------|--------------|--------|
| `insufficient_credits` | `error == 'insufficient_credits'` | `error: 'insufficient_credits'` | ✅ MATCH |
| `invalid_json` | `error == 'invalid_json'` | `error: 'invalid_json'` | ✅ MATCH |
| `invalid_storyboard` | `error == 'invalid_storyboard'` | `error: 'invalid_storyboard'` | ✅ MATCH |
| `llm_error` | non géré | `error: 'llm_error'` | ⚠️ PARTIEL |
| `internal_error` | non géré | `error: 'internal_error'` | ⚠️ PARTIEL |
| `not_authenticated` | non géré | `error: 'not_authenticated'` | ⚠️ PARTIEL |
| `Method not allowed` | non géré | `error: 'Method not allowed'` | ⚠️ PARTIEL |

---

## 9. Storyboard Model: `Storyboard.fromJson`

| Champ | Flutter attend | Edge/LLM produit | Statut |
|-------|----------------|------------------|--------|
| `version` | `String` | `string` | ✅ MATCH |
| `created_at` | `String` | `string` | ✅ MATCH |
| `created_by` | `String` | `string` | ✅ MATCH |
| `subject` | `String` | `string` | ✅ MATCH |
| `renderer` | `String` | `string` | ✅ MATCH |
| `theme` | `String` | `string` | ✅ MATCH |
| `narration_mode` | `String` | `string` | ✅ MATCH |
| `export_settings` | `Map<String, dynamic>` | `object` | ✅ MATCH |
| `export_settings.format` | `String` | `string` | ✅ MATCH |
| `export_settings.resolution` | `Map<String, dynamic>` | `object` | ✅ MATCH |
| `export_settings.resolution.width` | `int` | `number` | ✅ MATCH |
| `export_settings.resolution.height` | `int` | `number` | ✅ MATCH |
| `export_settings.frame_rate` | `int` | `number` | ✅ MATCH |
| `export_settings.video_codec` | `String` | `string` | ✅ MATCH |
| `export_settings.audio_codec` | `String` | `string` | ✅ MATCH |
| `scenes` | `List<dynamic>?` | `array` | ✅ MATCH |

---

## 10. Storyboard Model: `ExportSettings.fromJson`

| Champ | Flutter attend | Edge/LLM produit | Statut |
|-------|----------------|------------------|--------|
| `format` | `String` | `string` | ✅ MATCH |
| `resolution` | `Map<String, dynamic>` | `object` | ✅ MATCH |
| `frame_rate` | `int` | `number` | ✅ MATCH |
| `video_codec` | `String` | `string` | ✅ MATCH |
| `audio_codec` | `String` | `string` | ✅ MATCH |

---

## 11. Storyboard Model: `Scene.fromJson`

| Champ | Flutter attend | Edge/LLM produit | Statut |
|-------|----------------|------------------|--------|
| `id` | `String` | `string` | ✅ MATCH |
| `order` | `int` | `number` | ✅ MATCH |
| `title` | `String` | `string` | ✅ MATCH |
| `duration_ms` | `int` | `number` | ✅ MATCH |
| `transition` | `Map<String, dynamic>?` | `object?` | ✅ MATCH |
| `blocks` | `List<dynamic>?` | `array` | ✅ MATCH |

---

## 12. Storyboard Model: `Block.fromJson`

| Champ | Flutter attend | Edge/LLM produit | Statut |
|-------|----------------|------------------|--------|
| `id` | `String` | `string` | ✅ MATCH |
| `type` | `String` | `string` | ✅ MATCH |
| `content` | `String` | `string` | ✅ MATCH |
| `order` | `int` | `number` | ✅ MATCH |
| `visible` | `bool` | `boolean` | ✅ MATCH |
| `animation` | `Map<String, dynamic>?` | `object?` | ✅ MATCH |
| `position` | `Map<String, dynamic>?` | `object?` | ✅ MATCH |
| `style` | `Map<String, dynamic>?` | `object?` | ✅ MATCH |

---

## RÉSUMÉ DES MISMATCHES

| # | Composant | Fichier | Ligne | Champ | Type attendu | Type réel | Conséquence |
|---|-----------|---------|-------|-------|--------------|-----------|-------------|
| 1 | `whiteboard_list_projects` | `smart_whiteboard_provider.dart` | 531 | réponse | `List<dynamic>` | `Map<String, dynamic>` | Crash au cast |

---

## RÉSUMÉ DES PARTIELS

| # | Composant | Fichier | Ligne | Champ | Statut |
|---|-----------|---------|-------|-------|--------|
| 1 | Edge Function | `smart_whiteboard_provider.dart` | 152 | `error: 'llm_error'` | Non géré → fallback to 'Failed to generate storyboard' |
| 2 | Edge Function | `smart_whiteboard_provider.dart` | 152 | `error: 'internal_error'` | Non géré → fallback to 'Failed to generate storyboard' |
| 3 | Edge Function | `smart_whiteboard_provider.dart` | 152 | `error: 'not_authenticated'` | Non géré |
| 4 | Edge Function | `smart_whiteboard_provider.dart` | 169 | `project_data` | Ignoré |
| 5 | Edge Function | `smart_whiteboard_provider.dart` | 169 | `credits_used`, `model`, `tokens_*`, `cost_usd` | Ignorés |

---

## CONCLUSION

Le seul MISMATCH bloquant démontré est le cast de `whiteboard_list_projects` dans Flutter.
Tous les autres contrats sont MATCH ou PARTIEL (non bloquant).

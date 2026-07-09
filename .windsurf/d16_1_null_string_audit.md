# D.16.1 – NULL STRING CRASH AUDIT

**Date**: 2026-06-26
**Mission**: D.16.1
**Erreur**: `type 'Null' is not a subtype of type 'String' in type cast`
**Contexte**: Sujet=probabilités, Mode=Sujet simple, Theme=Cahier, Renderer=Cahier, Narration=TTS

---

## PHASE 1 – LOCALISATION DU STACK TRACE

Le stack trace n'a pas été fourni. L'analyse ci-dessous est basée sur l'audit statique du code.

---

## PHASE 2 – AUDIT DES CASTS FORCÉS

### Fichier `lib/features/challenge/smart_whiteboard/models/storyboard_models.dart`

| Ligne | Code | Champ concerné | Nullabilité |
|-------|------|----------------|-------------|
| 104 | `format: json['format'] as String,` | `format` | Non-nullable |
| 106 | `frameRate: json['frame_rate'] as int,` | `frame_rate` | Non-nullable |
| 107 | `videoCodec: json['video_codec'] as String,` | `video_codec` | Non-nullable |
| 108 | `audioCodec: json['audio_codec'] as String,` | `audio_codec` | Non-nullable |
| 356 | `'id': json['id'] as String,` | `id` | Non-nullable |
| 357 | `'type': json['type'] as String,` | `type` | Non-nullable |
| 358 | `'content': json['content'] as String,` | `content` | Non-nullable |
| 411 | `id: json['id'] as String,` | `id` | Non-nullable |
| 412 | `content: json['content'] as String,` | `content` | Non-nullable |
| 470 | `id: json['id'] as String,` | `id` | Non-nullable |
| 471 | `content: json['content'] as String,` | `content` | Non-nullable |
| 533 | `id: json['id'] as String,` | `id` | Non-nullable |
| 534 | `content: json['content'] as String,` | `content` | Non-nullable |
| 605 | `id: json['id'] as String,` | `id` | Non-nullable |
| 606 | `term: json['term'] as String,` | `term` | Non-nullable |
| 607 | `definition: json['definition'] as String,` | `definition` | Non-nullable |
| 678 | `id: json['id'] as String,` | `id` | Non-nullable |
| 679 | `question: json['question'] as String,` | `question` | Non-nullable |
| 752 | `id: json['id'] as String,` | `id` | Non-nullable |
| 753 | `exerciseId: json['exercise_id'] as String,` | `exercise_id` | Non-nullable |
| 755 | `explanation: json['explanation'] as String,` | `explanation` | Non-nullable |
| 823 | `id: json['id'] as String,` | `id` | Non-nullable |
| 825 | `title: json['title'] as String,` | `title` | Non-nullable |
| 907 | `version: json['version'] as String,` | `version` | Non-nullable |
| 908 | `createdAt: DateTime.parse(json['created_at'] as String),` | `created_at` | Non-nullable |
| 909 | `createdBy: json['created_by'] as String,` | `created_by` | Non-nullable |
| 910 | `subject: json['subject'] as String,` | `subject` | Non-nullable |
| 1003 | `id: json['id'] as String,` | `id` | Non-nullable |
| 1004 | `studentId: json['student_id'] as String,` | `student_id` | Non-nullable |
| 1005 | `subject: json['subject'] as String,` | `subject` | Non-nullable |
| 1010 | `createdAt: DateTime.parse(json['created_at'] as String),` | `created_at` | Non-nullable |
| 1011 | `updatedAt: DateTime.parse(json['updated_at'] as String),` | `updated_at` | Non-nullable |
| 1098 | `id: json['id'] as String,` | `id` | Non-nullable |
| 1099 | `projectId: json['project_id'] as String,` | `project_id` | Non-nullable |
| 1108 | `createdAt: DateTime.parse(json['created_at'] as String),` | `created_at` | Non-nullable |

### Fichier `lib/features/challenge/smart_whiteboard/providers/smart_whiteboard_provider.dart`

| Ligne | Code | Champ concerné |
|-------|------|----------------|
| 285 | `projectId: projectId as String,` | `projectId` |
| 292 | `projectId: projectId as String,` | `projectId` |
| 299 | `projectId: projectId as String,` | `projectId` |
| 306 | `projectId: projectId as String,` | `projectId` |
| 313 | `projectId: projectId as String,` | `projectId` |
| 320 | `projectId: projectId as String,` | `projectId` |
| 327 | `projectId: projectId as String,` | `projectId` |
| 334 | `projectId: projectId as String,` | `projectId` |

### Fichier `lib/features/challenge/smart_whiteboard/services/smart_whiteboard_render_service.dart`

| Ligne | Code | Champ concerné |
|-------|------|----------------|
| 36 | `projectId: projectId as String,` | `projectId` |
| 53 | `renderId: renderId as String,` | `renderId` |
| 67 | `projectId: projectId as String,` | `projectId` |

### Fichier `lib/features/challenge/smart_whiteboard/screens/smart_whiteboard_projects_list_screen.dart`

| Ligne | Code | Champ concerné |
|-------|------|----------------|
| 209 | `id: project['id'] as String,` | `id` |
| 210 | `subject: project['subject'] as String,` | `subject` |
| 211 | `createdAt: DateTime.parse(project['created_at'] as String),` | `created_at` |
| 212 | `updatedAt: DateTime.parse(project['updated_at'] as String),` | `updated_at` |
| 216 | `status: project['status'] as String,` | `status` |
| 217 | `rendererId: project['renderer_id'] as String,` | `renderer_id` |
| 218 | `themeId: project['theme_id'] as String,` | `theme_id` |
| 219 | `narrationMode: project['narration_mode'] as String,` | `narration_mode` |

---

## PHASE 3 – AUDIT DE LA RÉPONSE BACKEND

### Réponse de l'Edge Function `whiteboard-generate-storyboard`

```typescript
@supabase/functions/whiteboard-generate-storyboard/index.ts:497-506
return jsonResponse({
  success: true,
  storyboard_json: sb,
  project_data: projectData,
  credits_used: 15,
  model: cascadeResult.model,
  tokens_input: cascadeResult.usage.prompt_tokens || 0,
  tokens_output: cascadeResult.usage.completion_tokens || 0,
  cost_usd: cascadeResult.costUsd,
});
```

### Structure du storyboard injecté

```typescript
@supabase/functions/whiteboard-generate-storyboard/index.ts:442-448
sb.created_at = new Date().toISOString();
sb.created_by = userId;
sb.subject = subject;
sb.renderer = renderer;
sb.theme = theme;
sb.narration_mode = narrationMode;
```

### Champs générés par OpenRouter

L'Edge Function attend qu'OpenRouter fournisse:
- `version`
- `export_settings` avec `format`, `resolution`, `frame_rate`, `video_codec`, `audio_codec`
- `scenes` avec `id`, `order`, `title`, `duration_ms`, `blocks`
- `blocks` avec `id`, `type`, `content`, `order`, `visible`

### Validation côté Edge Function

```typescript
@supabase/functions/whiteboard-generate-storyboard/index.ts:86-92
const required = ['version', 'created_at', 'created_by', 'subject', 'renderer', 'theme', 'narration_mode', 'export_settings', 'scenes'];
```

**Problème**: la validation vérifie la présence de `export_settings` mais ne valide pas son contenu. Elle ne vérifie pas que `format`, `video_codec`, `audio_codec` sont présents et non null.

---

## PHASE 4 – HYPOTHÈSE UNIQUE

### CAUSE RACINE

**Champ** : `video_codec` (ou `format`, `audio_codec`) dans `ExportSettings.fromJson`
**Fichier** : `lib/features/challenge/smart_whiteboard/models/storyboard_models.dart`
**Ligne** : 107
**Code** : `videoCodec: json['video_codec'] as String,`

### Raisonnement

1. L'Edge Function retourne `storyboard_json` tel que généré par OpenRouter.
2. La validation de l'Edge Function vérifie que `export_settings` existe mais ne vérifie pas son contenu.
3. Le prompt système demande à OpenRouter de fournir `export_settings` avec `format`, `resolution`, `frame_rate`, `video_codec`, `audio_codec`.
4. OpenRouter peut générer un `export_settings` avec un champ `video_codec` manquant ou `null`.
5. Le modèle Flutter `ExportSettings` attend des `String` non-nullables pour `format`, `videoCodec`, `audioCodec`.
6. Lors du parsing, `json['video_codec'] as String` échoue avec `type 'Null' is not a subtype of type 'String'` si le champ est null ou absent.

### Preuves

**Code fautif**:
```dart
@lib/features/challenge/smart_whiteboard/models/storyboard_models.dart:104-108
format: json['format'] as String,
resolution: Resolution.fromJson(json['resolution'] as Map<String, dynamic>),
frameRate: json['frame_rate'] as int,
videoCodec: json['video_codec'] as String,
audioCodec: json['audio_codec'] as String,
```

**Validation insuffisante**:
```typescript
@supabase/functions/whiteboard-generate-storyboard/index.ts:86-92
const required = ['version', 'created_at', 'created_by', 'subject', 'renderer', 'theme', 'narration_mode', 'export_settings', 'scenes'];
```

**Debug prints existants**:
```dart
@lib/features/challenge/smart_whiteboard/models/storyboard_models.dart:95-100
print("DEBUG 24: ExportSettings.fromJson json = $json");
print("DEBUG 25: json['format'] = ${json['format']}");
print("DEBUG 26: json['format'] type = ${json['format'].runtimeType}");
print("DEBUG 27: json['video_codec'] = ${json['video_codec']}");
print("DEBUG 28: json['video_codec'] type = ${json['video_codec'].runtimeType}");
print("DEBUG 29: json['audio_codec'] = ${json['audio_codec']}");
```

Ces debug prints confirment que le développeur a déjà identifié `ExportSettings` comme zone à risque.

### Conclusion

Le prochain point de rupture est le cast forcé des champs de `ExportSettings` dans `storyboard_models.dart`. L'Edge Function doit soit valider `export_settings` en profondeur, soit injecter des valeurs par défaut pour `format`, `video_codec`, `audio_codec` si OpenRouter ne les fournit pas.

---

## ACTION RECOMMANDÉE

Sans modifier la base SQL, la correction la plus sûre est côté Edge Function:

1. Valider que `export_settings` contient `format`, `resolution`, `frame_rate`, `video_codec`, `audio_codec`.
2. Injecter des valeurs par défaut si absents:
   - `format`: 'mp4'
   - `resolution`: `{ width: 1080, height: 1920 }`
   - `frame_rate`: 30
   - `video_codec`: 'h264'
   - `audio_codec`: 'aac'

Cela garantit que le modèle Flutter reçoit toujours des valeurs non-nullables.

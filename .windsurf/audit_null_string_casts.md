# SMART WHITEBOARD - TRAQUE DU NULL AS STRING

## TOUS LES CASTS `as String` DANS lib/features/challenge/smart_whiteboard/

---

### 1. smart_whiteboard_render_service.dart

#### CAST 1.1
**Fichier :** `smart_whiteboard_render_service.dart`
**Ligne :** 59
**Variable :** `renderStatus`
**Code :**
```dart
final renderStatus = render['status'] as String;
```
**Peut-elle être null ?** ❌ NON (cast non-nullable)
**Valeur provenant de :** RPC `whiteboard_get_render_status` → BDD `whiteboard_renders.status`
**Source :** BDD (table whiteboard_renders, colonne status NOT NULL)

#### CAST 1.2
**Fichier :** `smart_whiteboard_render_service.dart`
**Ligne :** 75
**Variable :** `renderStatus`
**Code :**
```dart
final renderStatus = render['status'] as String;
```
**Peut-elle être null ?** ❌ NON (cast non-nullable)
**Valeur provenant de :** RPC `whiteboard_get_render_status` → BDD `whiteboard_renders.status`
**Source :** BDD (table whiteboard_renders, colonne status NOT NULL)

#### CAST 1.3
**Fichier :** `smart_whiteboard_render_service.dart`
**Ligne :** 81
**Variable :** `videoUrl`
**Code :**
```dart
return render['video_url'] as String?;
```
**Peut-elle être null ?** ✅ OUI (cast nullable)
**Valeur provenant de :** RPC `whiteboard_get_render_status` → BDD `whiteboard_renders.video_url`
**Source :** BDD (table whiteboard_renders, colonne video_url NULLABLE)

---

### 2. smart_whiteboard_projects_list_screen.dart

#### CAST 2.1
**Fichier :** `smart_whiteboard_projects_list_screen.dart`
**Ligne :** 150
**Variable :** `status`
**Code :**
```dart
final status = project['status'] as String;
```
**Peut-elle être null ?** ❌ NON (cast non-nullable)
**Valeur provenant de :** RPC `whiteboard_list_projects` → BDD `whiteboard_projects.status`
**Source :** BDD (table whiteboard_projects, colonne status NOT NULL)

#### CAST 2.2
**Fichier :** `smart_whiteboard_projects_list_screen.dart`
**Ligne :** 151
**Variable :** `subject`
**Code :**
```dart
final subject = project['subject'] as String;
```
**Peut-elle être null ?** ❌ NON (cast non-nullable)
**Valeur provenant de :** RPC `whiteboard_list_projects` → BDD `whiteboard_projects.subject`
**Source :** BDD (table whiteboard_projects, colonne subject NOT NULL)

#### CAST 2.3
**Fichier :** `smart_whiteboard_projects_list_screen.dart`
**Ligne :** 152
**Variable :** `createdAt`
**Code :**
```dart
final createdAt = project['created_at'] as String;
```
**Peut-elle être null ?** ❌ NON (cast non-nullable)
**Valeur provenant de :** RPC `whiteboard_list_projects` → BDD `whiteboard_projects.created_at`
**Source :** BDD (table whiteboard_projects, colonne created_at NOT NULL)

#### CAST 2.4
**Fichier :** `smart_whiteboard_projects_list_screen.dart`
**Ligne :** 205
**Variable :** `projectId`
**Code :**
```dart
final projectId = project['id'] as String;
```
**Peut-elle être null ?** ❌ NON (cast non-nullable)
**Valeur provenant de :** RPC `whiteboard_list_projects` → BDD `whiteboard_projects.id`
**Source :** BDD (table whiteboard_projects, colonne id PRIMARY KEY NOT NULL)

#### CAST 2.5
**Fichier :** `smart_whiteboard_projects_list_screen.dart`
**Ligne :** 238
**Variable :** `projectId`
**Code :**
```dart
await provider.deleteProject(project['id'] as String);
```
**Peut-elle être null ?** ❌ NON (cast non-nullable)
**Valeur provenant de :** RPC `whiteboard_list_projects` → BDD `whiteboard_projects.id`
**Source :** BDD (table whiteboard_projects, colonne id PRIMARY KEY NOT NULL)

#### CAST 2.6
**Fichier :** `smart_whiteboard_projects_list_screen.dart`
**Ligne :** 255
**Variable :** `status`
**Code :**
```dart
final status = project['status'] as String;
```
**Peut-elle être null ?** ❌ NON (cast non-nullable)
**Valeur provenant de :** RPC `whiteboard_list_projects` → BDD `whiteboard_projects.status`
**Source :** BDD (table whiteboard_projects, colonne status NOT NULL)

#### CAST 2.7
**Fichier :** `smart_whiteboard_projects_list_screen.dart`
**Ligne :** 258
**Variable :** `renderId`
**Code :**
```dart
final renderId = project['render_id'] as String?;
```
**Peut-elle être null ?** ✅ OUI (cast nullable)
**Valeur provenant de :** RPC `whiteboard_list_projects` → BDD `whiteboard_projects.render_id`
**Source :** BDD (table whiteboard_projects, colonne render_id N'EXISTE PAS dans le schéma actuel)

#### CAST 2.8
**Fichier :** `smart_whiteboard_projects_list_screen.dart`
**Ligne :** 259
**Variable :** `videoUrl`
**Code :**
```dart
final videoUrl = project['video_url'] as String?;
```
**Peut-elle être null ?** ✅ OUI (cast nullable)
**Valeur provenant de :** RPC `whiteboard_list_projects` → BDD `whiteboard_projects.video_url`
**Source :** BDD (table whiteboard_projects, colonne video_url N'EXISTE PAS dans le schéma actuel)

---

### 3. smart_whiteboard_provider.dart

#### CAST 3.1
**Fichier :** `smart_whiteboard_provider.dart`
**Ligne :** 96
**Variable :** `_currentProjectId`
**Code :**
```dart
_currentProjectId = result['project_id'] as String;
```
**Peut-elle être null ?** ❌ NON (cast non-nullable)
**Valeur provenant de :** RPC `whiteboard_create_project` → BDD `whiteboard_projects.id`
**Source :** BDD (table whiteboard_projects, colonne id PRIMARY KEY NOT NULL)
**RISQUE ÉLEVÉ :** Si la RPC retourne null pour project_id, ce cast crashera

#### CAST 3.2
**Fichier :** `smart_whiteboard_provider.dart`
**Ligne :** 99
**Variable :** `error message`
**Code :**
```dart
_setError(result['error'] as String? ?? 'Failed to create project');
```
**Peut-elle être null ?** ✅ OUI (cast nullable avec fallback)
**Valeur provenant de :** RPC `whiteboard_create_project`
**Source :** RPC (error field peut être null)

#### CAST 3.3
**Fichier :** `smart_whiteboard_provider.dart`
**Ligne :** 231
**Variable :** `error message`
**Code :**
```dart
_setError(result['error'] as String? ?? 'Failed to update storyboard');
```
**Peut-elle être null ?** ✅ OUI (cast nullable avec fallback)
**Valeur provenant de :** RPC `whiteboard_update_project`
**Source :** RPC (error field peut être null)

#### CAST 3.4
**Fichier :** `smart_whiteboard_provider.dart`
**Ligne :** 441
**Variable :** `_currentRenderJobId`
**Code :**
```dart
_currentRenderJobId = result['render_id'] as String;
```
**Peut-elle être null ?** ❌ NON (cast non-nullable)
**Valeur provenant de :** RPC `whiteboard_create_render_job` → BDD `whiteboard_renders.id`
**Source :** BDD (table whiteboard_renders, colonne id PRIMARY KEY NOT NULL)
**RISQUE ÉLEVÉ :** Si la RPC retourne null pour render_id, ce cast crashera

#### CAST 3.5
**Fichier :** `smart_whiteboard_provider.dart`
**Ligne :** 444
**Variable :** `error message`
**Code :**
```dart
_setError(result['error'] as String? ?? 'Failed to create render job');
```
**Peut-elle être null ?** ✅ OUI (cast nullable avec fallback)
**Valeur provenant de :** RPC `whiteboard_create_render_job`
**Source :** RPC (error field peut être null)

#### CAST 3.6
**Fichier :** `smart_whiteboard_provider.dart`
**Ligne :** 463
**Variable :** `status`
**Code :**
```dart
final status = render['status'] as String;
```
**Peut-elle être null ?** ❌ NON (cast non-nullable)
**Valeur provenant de :** RPC `whiteboard_get_render_status` → BDD `whiteboard_renders.status`
**Source :** BDD (table whiteboard_renders, colonne status NOT NULL)

#### CAST 3.7
**Fichier :** `smart_whiteboard_provider.dart`
**Ligne :** 466
**Variable :** `_renderVideoUrl`
**Code :**
```dart
_renderVideoUrl = render['video_url'] as String?;
```
**Peut-elle être null ?** ✅ OUI (cast nullable)
**Valeur provenant de :** RPC `whiteboard_get_render_status` → BDD `whiteboard_renders.video_url`
**Source :** BDD (table whiteboard_renders, colonne video_url NULLABLE)

#### CAST 3.8
**Fichier :** `smart_whiteboard_provider.dart`
**Ligne :** 469
**Variable :** `error message`
**Code :**
```dart
_setError(render['error_message'] as String? ?? 'Render failed');
```
**Peut-elle être null ?** ✅ OUI (cast nullable avec fallback)
**Valeur provenant de :** RPC `whiteboard_get_render_status` → BDD `whiteboard_renders.error_message`
**Source :** BDD (table whiteboard_renders, colonne error_message NULLABLE)

---

### 4. storyboard_models.dart

#### CAST 4.1
**Fichier :** `storyboard_models.dart`
**Ligne :** 96
**Variable :** `format`
**Code :**
```dart
format: json['format'] as String,
```
**Peut-elle être null ?** ❌ NON (cast non-nullable)
**Valeur provenant de :** Edge Function `whiteboard-generate-storyboard` → OpenRouter
**Source :** OpenRouter (IA générée)
**RISQUE ÉLEVÉ :** Si l'IA ne génère pas le champ format, ce cast crashera

#### CAST 4.2
**Fichier :** `storyboard_models.dart`
**Ligne :** 99
**Variable :** `videoCodec`
**Code :**
```dart
videoCodec: json['video_codec'] as String,
```
**Peut-elle être null ?** ❌ NON (cast non-nullable)
**Valeur provenant de :** Edge Function `whiteboard-generate-storyboard` → OpenRouter
**Source :** OpenRouter (IA générée)
**RISQUE ÉLEVÉ :** Si l'IA ne génère pas le champ video_codec, ce cast crashera

#### CAST 4.3
**Fichier :** `storyboard_models.dart`
**Ligne :** 100
**Variable :** `audioCodec`
**Code :**
```dart
audioCodec: json['audio_codec'] as String,
```
**Peut-elle être null ?** ❌ NON (cast non-nullable)
**Valeur provenant de :** Edge Function `whiteboard-generate-storyboard` → OpenRouter
**Source :** OpenRouter (IA générée)
**RISQUE ÉLEVÉ :** Si l'IA ne génère pas le champ audio_codec, ce cast crashera

#### CAST 4.4
**Fichier :** `storyboard_models.dart`
**Ligne :** 192
**Variable :** `language`
**Code :**
```dart
language: json['language'] as String?,
```
**Peut-elle être null ?** ✅ OUI (cast nullable)
**Valeur provenant de :** Edge Function `whiteboard-generate-storyboard` → OpenRouter
**Source :** OpenRouter (IA générée)

#### CAST 4.5
**Fichier :** `storyboard_models.dart`
**Ligne :** 193
**Variable :** `voice`
**Code :**
```dart
voice: json['voice'] as String?,
```
**Peut-elle être null ?** ✅ OUI (cast nullable)
**Valeur provenant de :** Edge Function `whiteboard-generate-storyboard` → OpenRouter
**Source :** OpenRouter (IA générée)

#### CAST 4.6 à 4.15
**Fichier :** `storyboard_models.dart`
**Lignes :** 264-273
**Variable :** `fontWeight`, `color`, `termColor`, `definitionColor`, `exampleColor`, `questionColor`, `hintColor`, `solutionColor`, `stepNumberColor`, `explanationColor`
**Code :**
```dart
fontWeight: json['font_weight'] as String?,
color: json['color'] as String?,
termColor: json['term_color'] as String?,
definitionColor: json['definition_color'] as String?,
exampleColor: json['example_color'] as String?,
questionColor: json['question_color'] as String?,
hintColor: json['hint_color'] as String?,
solutionColor: json['solution_color'] as String?,
stepNumberColor: json['step_number_color'] as String?,
explanationColor: json['explanation_color'] as String?,
```
**Peut-elle être null ?** ✅ OUI (cast nullable)
**Valeur provenant de :** Edge Function `whiteboard-generate-storyboard` → OpenRouter
**Source :** OpenRouter (IA générée)

#### CAST 4.16
**Fichier :** `storyboard_models.dart`
**Ligne :** 340
**Variable :** `id`
**Code :**
```dart
'id': json['id'] as String,
```
**Peut-elle être null ?** ❌ NON (cast non-nullable)
**Valeur provenant de :** Edge Function `whiteboard-generate-storyboard` → OpenRouter
**Source :** OpenRouter (IA générée)
**RISQUE ÉLEVÉ :** Si l'IA ne génère pas le champ id, ce cast crashera

#### CAST 4.17
**Fichier :** `storyboard_models.dart`
**Ligne :** 341
**Variable :** `type`
**Code :**
```dart
'type': json['type'] as String,
```
**Peut-elle être null ?** ❌ NON (cast non-nullable)
**Valeur provenant de :** Edge Function `whiteboard-generate-storyboard` → OpenRouter
**Source :** OpenRouter (IA générée)
**RISQUE ÉLEVÉ :** Si l'IA ne génère pas le champ type, ce cast crashera

#### CAST 4.18
**Fichier :** `storyboard_models.dart`
**Ligne :** 342
**Variable :** `content`
**Code :**
```dart
'content': json['content'] as String,
```
**Peut-elle être null ?** ❌ NON (cast non-nullable)
**Valeur provenant de :** Edge Function `whiteboard-generate-storyboard` → OpenRouter
**Source :** OpenRouter (IA générée)
**RISQUE ÉLEVÉ :** Si l'IA ne génère pas le champ content, ce cast crashera

#### CAST 4.19 à 4.22
**Fichier :** `storyboard_models.dart`
**Lignes :** 395-397
**Variable :** `id`, `content`
**Code :**
```dart
id: json['id'] as String,
content: json['content'] as String,
```
**Peut-elle être null ?** ❌ NON (cast non-nullable)
**Valeur provenant de :** Edge Function `whiteboard-generate-storyboard` → OpenRouter
**Source :** OpenRouter (IA générée)
**RISQUE ÉLEVÉ :** Si l'IA ne génère pas ces champs, ces casts crasheront

#### CAST 4.23 à 4.26
**Fichier :** `storyboard_models.dart`
**Lignes :** 454-456
**Variable :** `id`, `content`
**Code :**
```dart
id: json['id'] as String,
content: json['content'] as String,
```
**Peut-elle être null ?** ❌ NON (cast non-nullable)
**Valeur provenant de :** Edge Function `whiteboard-generate-storyboard` → OpenRouter
**Source :** OpenRouter (IA générée)
**RISQUE ÉLEVÉ :** Si l'IA ne génère pas ces champs, ces casts crasheront

#### CAST 4.27 à 4.29
**Fichier :** `storyboard_models.dart`
**Lignes :** 517-519
**Variable :** `id`, `content`, `format`
**Code :**
```dart
id: json['id'] as String,
content: json['content'] as String,
format: json['format'] as String? ?? 'latex',
```
**Peut-elle être null ?** ❌ NON pour id/content, ✅ OUI pour format (avec fallback)
**Valeur provenant de :** Edge Function `whiteboard-generate-storyboard` → OpenRouter
**Source :** OpenRouter (IA générée)
**RISQUE ÉLEVÉ :** Si l'IA ne génère pas id/content, ces casts crasheront

#### CAST 4.30 à 4.32
**Fichier :** `storyboard_models.dart`
**Lignes :** 588-590
**Variable :** `id`, `term`, `definition`
**Code :**
```dart
id: json['id'] as String,
term: json['term'] as String,
definition: json['definition'] as String,
```
**Peut-elle être null ?** ❌ NON (cast non-nullable)
**Valeur provenant de :** Edge Function `whiteboard-generate-storyboard` → OpenRouter
**Source :** OpenRouter (IA générée)
**RISQUE ÉLEVÉ :** Si l'IA ne génère pas ces champs, ces casts crasheront

#### CAST 4.33 à 4.35
**Fichier :** `storyboard_models.dart`
**Lignes :** 662-664
**Variable :** `id`, `question`
**Code :**
```dart
id: json['id'] as String,
question: json['question'] as String,
```
**Peut-elle être null ?** ❌ NON (cast non-nullable)
**Valeur provenant de :** Edge Function `whiteboard-generate-storyboard` → OpenRouter
**Source :** OpenRouter (IA générée)
**RISQUE ÉLEVÉ :** Si l'IA ne génère pas ces champs, ces casts crasheront

#### CAST 4.36 à 4.38
**Fichier :** `storyboard_models.dart`
**Lignes :** 736-739
**Variable :** `id`, `exerciseId`, `explanation`
**Code :**
```dart
id: json['id'] as String,
exerciseId: json['exercise_id'] as String,
explanation: json['explanation'] as String,
```
**Peut-elle être null ?** ❌ NON (cast non-nullable)
**Valeur provenant de :** Edge Function `whiteboard-generate-storyboard` → OpenRouter
**Source :** OpenRouter (IA générée)
**RISQUE ÉLEVÉ :** Si l'IA ne génère pas ces champs, ces casts crasheront

#### CAST 4.39 à 4.41
**Fichier :** `storyboard_models.dart`
**Lignes :** 807-809
**Variable :** `id`, `title`
**Code :**
```dart
id: json['id'] as String,
title: json['title'] as String,
```
**Peut-elle être null ?** ❌ NON (cast non-nullable)
**Valeur provenant de :** Edge Function `whiteboard-generate-storyboard` → OpenRouter
**Source :** OpenRouter (IA générée)
**RISQUE ÉLEVÉ :** Si l'IA ne génère pas ces champs, ces casts crasheront

#### CAST 4.42 à 4.45
**Fichier :** `storyboard_models.dart`
**Lignes :** 881-884
**Variable :** `version`, `createdAt`, `createdBy`, `subject`
**Code :**
```dart
version: json['version'] as String,
createdAt: DateTime.parse(json['created_at'] as String),
createdBy: json['created_by'] as String,
subject: json['subject'] as String,
```
**Peut-elle être null ?** ❌ NON (cast non-nullable)
**Valeur provenant de :** Edge Function `whiteboard-generate-storyboard` → OpenRouter
**Source :** OpenRouter (IA générée)
**RISQUE ÉLEVÉ :** Si l'IA ne génère pas ces champs, ces casts crasheront

#### CAST 4.46 à 4.49
**Fichier :** `storyboard_models.dart`
**Lignes :** 977-980
**Variable :** `id`, `studentId`, `subject`
**Code :**
```dart
id: json['id'] as String,
studentId: json['student_id'] as String,
subject: json['subject'] as String,
```
**Peut-elle être null ?** ❌ NON (cast non-nullable)
**Valeur provenant de :** RPC `whiteboard_get_project` → BDD `whiteboard_projects`
**Source :** BDD (table whiteboard_projects, colonnes NOT NULL)

#### CAST 4.50 à 4.51
**Fichier :** `storyboard_models.dart`
**Lignes :** 984-985
**Variable :** `createdAt`, `updatedAt`
**Code :**
```dart
createdAt: DateTime.parse(json['created_at'] as String),
updatedAt: DateTime.parse(json['updated_at'] as String),
```
**Peut-elle être null ?** ❌ NON (cast non-nullable)
**Valeur provenant de :** RPC `whiteboard_get_project` → BDD `whiteboard_projects`
**Source :** BDD (table whiteboard_projects, colonnes NOT NULL)

#### CAST 4.52 à 4.53
**Fichier :** `storyboard_models.dart`
**Lignes :** 1072-1073
**Variable :** `id`, `projectId`
**Code :**
```dart
id: json['id'] as String,
projectId: json['project_id'] as String,
```
**Peut-elle être null ?** ❌ NON (cast non-nullable)
**Valeur provenant de :** RPC `whiteboard_get_render_status` → BDD `whiteboard_renders`
**Source :** BDD (table whiteboard_renders, colonnes NOT NULL)

#### CAST 4.54
**Fichier :** `storyboard_models.dart`
**Ligne :** 1084
**Variable :** `completedAt`
**Code :**
```dart
DateTime.parse(json['completed_at'] as String)
```
**Peut-elle être null ?** ❌ NON (cast non-nullable, mais vérifié != null avant)
**Valeur provenant de :** RPC `whiteboard_get_render_status` → BDD `whiteboard_renders`
**Source :** BDD (table whiteboard_renders, colonne completed_at NULLABLE)

---

## CASTS CRITIQUES À SURVEILLER (RISQUE ÉLEVÉ)

### CAST CRITIQUE 1 : project_id
**Fichier :** `smart_whiteboard_provider.dart`
**Ligne :** 96
**Variable :** `_currentProjectId`
**Code :**
```dart
_currentProjectId = result['project_id'] as String;
```
**Risque :** Si la RPC `whiteboard_create_project` retourne null pour project_id, crash
**Source :** RPC SQL

### CAST CRITIQUE 2 : render_id
**Fichier :** `smart_whiteboard_provider.dart`
**Ligne :** 441
**Variable :** `_currentRenderJobId`
**Code :**
```dart
_currentRenderJobId = result['render_id'] as String;
```
**Risque :** Si la RPC `whiteboard_create_render_job` retourne null pour render_id, crash
**Source :** RPC SQL

### CAST CRITIQUE 3 : format, video_codec, audio_codec (ExportSettings)
**Fichier :** `storyboard_models.dart`
**Lignes :** 96, 99, 100
**Variable :** `format`, `videoCodec`, `audioCodec`
**Risque :** Si l'IA OpenRouter ne génère pas ces champs, crash
**Source :** OpenRouter (IA générée)

### CAST CRITIQUE 4 : id, type, content (Block)
**Fichier :** `storyboard_models.dart`
**Lignes :** 340-342
**Variable :** `id`, `type`, `content`
**Risque :** Si l'IA OpenRouter ne génère pas ces champs, crash
**Source :** OpenRouter (IA générée)

### CAST CRITIQUE 5 : version, created_at, created_by, subject (Storyboard)
**Fichier :** `storyboard_models.dart`
**Lignes :** 881-884
**Variable :** `version`, `createdAt`, `createdBy`, `subject`
**Risque :** Si l'IA OpenRouter ne génère pas ces champs, crash
**Source :** OpenRouter (IA générée)

---

## CONCLUSION

**CASTS NON-NULLABLE SANS FALLBACK (RISQUE DE CRASH) :** 22+
**CASTS NULLABLE AVEC FALLBACK :** 15+
**CASTS NULLABLE :** 8+

**CASTS LES PLUS DANGEREUX (provenant d'OpenRouter) :**
- ExportSettings (format, video_codec, audio_codec)
- Block (id, type, content)
- Scene (id, title)
- Storyboard (version, created_at, created_by, subject)

**CASTS DANGEREUX (provenant de RPC SQL) :**
- project_id (smart_whiteboard_provider.dart:96)
- render_id (smart_whiteboard_provider.dart:441)

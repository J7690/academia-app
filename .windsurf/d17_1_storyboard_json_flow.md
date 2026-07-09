# D.17.1 – PHASE 3: FLUX JSON DE L'EDGE FUNCTION

**Date**: 2026-06-26
**Mission**: D.17.1
**Edge Function**: `whiteboard-generate-storyboard`
**Fichier**: `supabase/functions/whiteboard-generate-storyboard/index.ts`

---

## ÉTAPE 1: FLUTTER ENVOIE LE BODY

### Fichier

`academia_app/lib/features/challenge/smart_whiteboard/providers/smart_whiteboard_provider.dart:133-143`

### Code

```dart
final response = await client.functions.invoke(
  'whiteboard-generate-storyboard',
  body: {
    'mode': mode,
    'subject': _currentProject?.subject ?? '',
    'content': content,
    'renderer': _currentProject?.rendererId ?? 'scientific',
    'theme': _currentProject?.themeId ?? 'scientific',
    'narration_mode': _currentProject?.narrationMode ?? 'none',
  },
);
```

### INPUT JSON

```json
{
  "mode": "simple_subject",
  "subject": "probabilités",
  "content": "",
  "renderer": "notebook",
  "theme": "notebook",
  "narration_mode": "tts"
}
```

### TYPE ATTENDU

`Map<String, dynamic>`

### TYPE RÉEL

`Map<String, dynamic>`

---

## ÉTAPE 2: EDGE FUNCTION RÉCUPÈRE LES PARAMÈTRES

### Fichier

`supabase/functions/whiteboard-generate-storyboard/index.ts:343-348`

### Code

```typescript
const mode = (body.mode ?? 'simple_subject').toString().trim();
const subject = (body.subject ?? '').toString().trim();
const content = (body.content ?? '').toString().trim();
const renderer = (body.renderer ?? 'scientific').toString().trim();
const theme = (body.theme ?? 'scientific').toString().trim();
const narrationMode = (body.narration_mode ?? 'none').toString().trim();
```

### OUTPUT JSON (variables internes)

```json
{
  "mode": "simple_subject",
  "subject": "probabilités",
  "content": "",
  "renderer": "notebook",
  "theme": "notebook",
  "narration_mode": "tts"
}
```

### TYPE ATTENDU

`string`

### TYPE RÉEL

`string`

---

## ÉTAPE 3: CRÉATION DU PROJET

### Fichier

`academia_app/lib/features/challenge/smart_whiteboard/providers/smart_whiteboard_provider.dart:88-93`

### Code

```dart
final result = await _projectService.createProject(
  subject: subject,
  rendererId: rendererId,
  themeId: themeId,
  narrationMode: narrationMode,
);
```

### INPUT JSON

```json
{
  "p_student_id": "<uuid>",
  "p_subject": "probabilités",
  "p_renderer_id": "notebook",
  "p_theme_id": "notebook",
  "p_narration_mode": "tts",
  "p_storyboard_json": {}
}
```

### OUTPUT JSON

```json
{
  "success": true,
  "project_id": "<uuid>"
}
```

### TYPE ATTENDU

`Map<String, dynamic>`

### TYPE RÉEL

`Map<String, dynamic>`

---

## ÉTAPE 4: APPEL OPENROUTER

### Fichier

`supabase/functions/whiteboard-generate-storyboard/index.ts:38-51`

### Code

```typescript
const r = await fetch('https://openrouter.ai/api/v1/chat/completions', {
  method:'POST',
  headers:{...},
  body:JSON.stringify({
    model,
    messages:msgs,
    temperature:0.2,
    max_tokens:4000
  })
});
```

### INPUT JSON

```json
{
  "model": "...",
  "messages": [
    { "role": "system", "content": "..." },
    { "role": "user", "content": "..." }
  ],
  "temperature": 0.2,
  "max_tokens": 4000
}
```

### OUTPUT JSON (réponse OpenRouter)

```json
{
  "choices": [
    {
      "message": {
        "content": "{\"version\":\"1.0\",...}"
      }
    }
  ],
  "usage": {
    "prompt_tokens": 1000,
    "completion_tokens": 2000,
    "total_tokens": 3000
  }
}
```

### TYPE ATTENDU

`string` (content)

### TYPE RÉEL

`string`

---

## ÉTAPE 5: PARSING JSON

### Fichier

`supabase/functions/whiteboard-generate-storyboard/index.ts:420-428`

### Code

```typescript
let parsed: unknown;
try {
  parsed = JSON.parse(jsonToParse);
} catch (e) {
  ...
}
```

### INPUT JSON

Chaîne JSON brute extraite de `choices[0].message.content`.

### OUTPUT JSON

```json
{
  "version": "1.0",
  "created_at": "2026-06-26T...",
  "created_by": "<uuid>",
  "subject": "probabilités",
  "renderer": "notebook",
  "theme": "notebook",
  "narration_mode": "tts",
  "export_settings": {
    "format": "mp4",
    "resolution": {"width": 1080, "height": 1920},
    "frame_rate": 30,
    "video_codec": "h264",
    "audio_codec": "aac"
  },
  "scenes": [...]
}
```

### TYPE ATTENDU

`Record<string, unknown>`

### TYPE RÉEL

`Record<string, unknown>`

---

## ÉTAPE 6: INJECTION DE MÉTADONNÉES

### Fichier

`supabase/functions/whiteboard-generate-storyboard/index.ts:442-448`

### Code

```typescript
sb.created_at = new Date().toISOString();
sb.created_by = userId;
sb.subject = subject;
sb.renderer = renderer;
sb.theme = theme;
sb.narration_mode = narrationMode;
```

### OUTPUT JSON APRÈS INJECTION

```json
{
  "version": "1.0",
  "created_at": "2026-06-26T19:00:00.000Z",
  "created_by": "<uuid>",
  "subject": "probabilités",
  "renderer": "notebook",
  "theme": "notebook",
  "narration_mode": "tts",
  "export_settings": {
    "format": "mp4",
    "resolution": {"width": 1080, "height": 1920},
    "frame_rate": 30,
    "video_codec": "h264",
    "audio_codec": "aac"
  },
  "scenes": [...]
}
```

### TYPE ATTENDU

`Record<string, unknown>`

### TYPE RÉEL

`Record<string, unknown>`

---

## ÉTAPE 7: STOCKAGE DANS SUPABASE

### Fichier

`supabase/functions/whiteboard-generate-storyboard/index.ts:451-458`

### Code

```typescript
const { data: projectData } = await supabase.rpc('whiteboard_create_project', {
  p_student_id: userId,
  p_subject: subject,
  p_renderer_id: renderer,
  p_theme_id: theme,
  p_narration_mode: narrationMode,
  p_storyboard_json: sb,
});
```

### INPUT JSON

```json
{
  "p_student_id": "<uuid>",
  "p_subject": "probabilités",
  "p_renderer_id": "notebook",
  "p_theme_id": "notebook",
  "p_narration_mode": "tts",
  "p_storyboard_json": {
    "version": "1.0",
    "created_at": "...",
    "created_by": "<uuid>",
    "subject": "probabilités",
    "renderer": "notebook",
    "theme": "notebook",
    "narration_mode": "tts",
    "export_settings": {...},
    "scenes": [...]
  }
}
```

### OUTPUT JSON

```json
{
  "success": true,
  "project_id": "<uuid>"
}
```

### TYPE ATTENDU

`JSONB`

### TYPE RÉEL

`JSONB`

---

## ÉTAPE 8: RÉPONSE À FLUTTER

### Fichier

`supabase/functions/whiteboard-generate-storyboard/index.ts:497-506`

### Code

```typescript
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

### OUTPUT JSON

```json
{
  "success": true,
  "storyboard_json": {
    "version": "1.0",
    "created_at": "...",
    "created_by": "<uuid>",
    "subject": "probabilités",
    "renderer": "notebook",
    "theme": "notebook",
    "narration_mode": "tts",
    "export_settings": {
      "format": "mp4",
      "resolution": {"width": 1080, "height": 1920},
      "frame_rate": 30,
      "video_codec": "h264",
      "audio_codec": "aac"
    },
    "scenes": [...]
  },
  "project_data": {
    "success": true,
    "project_id": "<uuid>"
  },
  "credits_used": 15,
  "model": "...",
  "tokens_input": 1000,
  "tokens_output": 2000,
  "cost_usd": 0.0009
}
```

### TYPE ATTENDU

`Map<String, dynamic>`

### TYPE RÉEL

`Map<String, dynamic>`

---

## ÉTAPE 9: FLUTTER PARSE LE STORYBOARD

### Fichier

`academia_app/lib/features/challenge/smart_whiteboard/providers/smart_whiteboard_provider.dart:169-178`

### Code

```dart
final data = response.data as Map<String, dynamic>;
final storyboardJson = data['storyboard_json'] as Map<String, dynamic>?;

if (storyboardJson == null) {
  ...
}

_currentStoryboard = Storyboard.fromJson(storyboardJson);
```

### INPUT JSON

```json
{
  "version": "1.0",
  "created_at": "...",
  "created_by": "<uuid>",
  "subject": "probabilités",
  "renderer": "notebook",
  "theme": "notebook",
  "narration_mode": "tts",
  "export_settings": {
    "format": "mp4",
    "resolution": {"width": 1080, "height": 1920},
    "frame_rate": 30,
    "video_codec": "h264",
    "audio_codec": "aac"
  },
  "scenes": [...]
}
```

### OUTPUT JSON

`Storyboard` Dart object.

### TYPE ATTENDU

`Map<String, dynamic>`

### TYPE RÉEL

`Map<String, dynamic>`

---

## ÉTAPE 10: MISE À JOUR DU PROJET

### Fichier

`academia_app/lib/features/challenge/smart_whiteboard/providers/smart_whiteboard_provider.dart:230-254`

### Code

```dart
final result = await _projectService.updateProject(
  projectId: _currentProjectId!,
  storyboardJson: storyboard.toJson(),
);
```

### INPUT JSON

```json
{
  "p_project_id": "<uuid>",
  "p_storyboard_json": {
    "version": "1.0",
    "..."
  }
}
```

### OUTPUT JSON

```json
{
  "success": true,
  "project": {
    "id": "<uuid>",
    "storyboard_json": {...}
  }
}
```

### TYPE ATTENDU

`Map<String, dynamic>`

### TYPE RÉEL

`Map<String, dynamic>`

---

## CONCLUSION

Le flux JSON global est cohérent entre l'Edge Function et Flutter. La réponse de l'Edge Function contient bien `storyboard_json` qui est un `Map<String, dynamic>`.

Le point de rupture potentiel reste dans `Storyboard.fromJson()` si OpenRouter ne fournit pas tous les champs requis (voir D.16.1).

# SMART WHITEBOARD - CONTRAT DE DONNÉES

## 1) CONTRAT FLUTTER

### 1.1 Contrat RPC whiteboard_create_project

**Fichier :** `academia_app/lib/features/challenge/smart_whiteboard/services/smart_whiteboard_service.dart`
**Méthode :** `createProject()`
**Ligne :** 17-37

**Champs exigés par Flutter :**

```dart
{
  "success": bool (non-null),
  "project_id": String (non-null)
}
```

**Champs optionnels :**
```dart
{
  "error": String? (nullable)
}
```

**Parsing Flutter :**
```dart
if (result['success'] == true) {
  _currentProjectId = result['project_id'] as String;
  _setState(SmartWhiteboardState.idle);
} else {
  _setError(result['error'] as String? ?? 'Failed to create project');
}
```

---

### 1.2 Contrat Edge Function whiteboard-generate-storyboard

**Fichier :** `academia_app/lib/features/challenge/smart_whiteboard/providers/smart_whiteboard_provider.dart`
**Méthode :** `generateStoryboard()`
**Ligne :** 127-162

**Champs exigés par Flutter (succès) :**

```dart
{
  "success": bool (non-null),
  "storyboard_json": Map<String, dynamic> (non-null)
}
```

**Champs optionnels (succès) :**
```dart
{
  "project_data": Map<String, dynamic>?,
  "credits_used": int?,
  "model": String?,
  "tokens_input": int?,
  "tokens_output": int?,
  "cost_usd": double?
}
```

**Champs exigés par Flutter (erreur) :**

```dart
{
  "error": String (non-null)
}
```

**Champs optionnels (erreur) :**
```dart
{
  "balance": int?,
  "cost": int?,
  "message": String?,
  "detail": String?,
  "raw": String?
}
```

**Parsing Flutter :**
```dart
if (response.status != 200) {
  final errorData = response.data as Map<String, dynamic>?;
  if (errorData?['error'] == 'insufficient_credits') {
    _setError('Crédits insuffisants. Il vous faut 15 crédits pour générer un Storyboard.');
  } else if (errorData?['error'] == 'invalid_json') {
    _setError('Erreur de génération: JSON invalide. Veuillez réessayer.');
  } else if (errorData?['error'] == 'invalid_storyboard') {
    _setError('Erreur de génération: Storyboard invalide. Veuillez réessayer.');
  } else {
    _setError(errorData?['error'] ?? 'Failed to generate storyboard');
  }
  return;
}

final data = response.data as Map<String, dynamic>;
final storyboardJson = data['storyboard_json'] as Map<String, dynamic>?;

if (storyboardJson == null) {
  _setError('Erreur: storyboard_json manquant dans la réponse');
  return;
}

_currentStoryboard = Storyboard.fromJson(storyboardJson);
_setState(SmartWhiteboardState.editing);
```

---

### 1.3 Contrat Storyboard JSON (Flutter)

**Fichier :** `academia_app/lib/features/challenge/smart_whiteboard/models/storyboard_models.dart`
**Méthode :** `Storyboard.fromJson()`
**Ligne :** 877-900

**Champs exigés par Flutter :**

```dart
{
  "version": String (non-null),
  "created_at": String (non-null, ISO8601),
  "created_by": String (non-null, UUID),
  "subject": String (non-null),
  "renderer": String (non-null),
  "theme": String (non-null),
  "narration_mode": String (non-null),
  "export_settings": Map<String, dynamic> (non-null),
  "scenes": List<Map<String, dynamic>> (non-null)
}
```

**Parsing Flutter :**
```dart
factory Storyboard.fromJson(Map<String, dynamic> json) {
  return Storyboard(
    version: json['version'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    createdBy: json['created_by'] as String,
    subject: json['subject'] as String,
    renderer: RendererId.values.firstWhere(
      (e) => e.name == json['renderer'],
      orElse: () => RendererId.scientific,
    ),
    theme: ThemeId.values.firstWhere(
      (e) => e.name == json['theme'],
      orElse: () => ThemeId.scientific,
    ),
    narrationMode: NarrationMode.values.firstWhere(
      (e) => e.name == json['narration_mode'],
      orElse: () => NarrationMode.none,
    ),
    exportSettings: ExportSettings.fromJson(
        json['export_settings'] as Map<String, dynamic>),
    scenes: (json['scenes'] as List<dynamic>?)
            ?.map((s) => Scene.fromJson(s as Map<String, dynamic>))
            .toList() ??
        [],
  );
}
```

---

## 2) CONTRAT EDGE FUNCTION

### 2.1 Contrat Input Edge Function

**Fichier :** `supabase/functions/whiteboard-generate-storyboard/index.ts`
**Méthode :** main handler
**Ligne :** 342-348

**Champs exigés par Edge Function :**

```typescript
{
  "mode": string (default 'simple_subject'),
  "subject": string (required),
  "content": string (default ''),
  "renderer": string (default 'scientific'),
  "theme": string (default 'scientific'),
  "narration_mode": string (default 'none')
}
```

**Parsing Edge Function :**
```typescript
const body = await req.json();
const mode = (body.mode ?? 'simple_subject').toString().trim();
const subject = (body.subject ?? '').toString().trim();
const content = (body.content ?? '').toString().trim();
const renderer = (body.renderer ?? 'scientific').toString().trim();
const theme = (body.theme ?? 'scientific').toString().trim();
const narrationMode = (body.narration_mode ?? 'none').toString().trim();
```

---

### 2.2 Contrat Output Edge Function (succès)

**Fichier :** `supabase/functions/whiteboard-generate-storyboard/index.ts`
**Méthode :** jsonResponse()
**Ligne :** 496-506

**Champs promis par Edge Function :**

```typescript
{
  "success": true,
  "storyboard_json": {
    "version": "1.0",
    "created_at": "ISO8601",
    "created_by": "UUID",
    "subject": "string",
    "renderer": "scientific|notebook",
    "theme": "scientific|notebook",
    "narration_mode": "none|tts|userRecording",
    "export_settings": {...},
    "scenes": [...]
  },
  "project_data": {...},
  "credits_used": 15,
  "model": "string",
  "tokens_input": number,
  "tokens_output": number,
  "cost_usd": number
}
```

**Code Edge Function :**
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

---

### 2.3 Contrat Output Edge Function (erreur)

**Fichier :** `supabase/functions/whiteboard-generate-storyboard/index.ts`

**Cas d'erreur insuffisants crédits :**
```typescript
{
  "error": "insufficient_credits",
  "balance": number,
  "cost": number,
  "message": "Crédits insuffisants. Il vous faut X crédits (solde: Y)."
}
```

**Cas d'erreur LLM :**
```typescript
{
  "error": "llm_error",
  "detail": "string (max 300 chars)"
}
```

**Cas d'erreur JSON invalide :**
```typescript
{
  "error": "invalid_json",
  "detail": "string (max 300 chars)",
  "raw": "string (max 500 chars)"
}
```

**Cas d'erreur Storyboard invalide :**
```typescript
{
  "error": "invalid_storyboard",
  "detail": "string",
  "raw": "string (max 500 chars)"
}
```

**Cas d'erreur interne :**
```typescript
{
  "error": "internal_error",
  "detail": "string (max 300 chars)"
}
```

---

## 3) CONTRAT OPENROUTER

### 3.1 Prompt Exact

**Fichier :** `supabase/functions/whiteboard-generate-storyboard/index.ts`
**Méthode :** `getSystemPrompt()`
**Ligne :** 204-312

**Prompt système (base) :**
```typescript
Tu es un expert en création de Storyboards pédagogiques pour le Smart Whiteboard Academia.

Ton rôle est de générer un Storyboard JSON valide qui sera utilisé pour créer une vidéo pédagogique.

RÈGLES STRICTES :
1. Le Storyboard doit être conforme au format JSON version "1.0"
2. Structure le contenu en 5-10 scènes
3. Chaque scène contient 3-6 blocs
4. Utilise les types de blocs appropriés (title, paragraph, formula, definition, exercise, correction)
5. Adapte le contenu au renderer "${renderer}" et au thème "${theme}"
6. narration_mode DOIT être exactement "${narrationMode}" (valeurs acceptées: none, tts, userRecording)

FORMAT JSON REQUIS :
{
  "version": "1.0",
  "created_at": "iso8601",
  "created_by": "uuid",
  "subject": "...",
  "renderer": "${renderer}",
  "theme": "${theme}",
  "narration_mode": "...",
  "export_settings": {
    "format": "mp4",
    "resolution": {"width": 1080, "height": 1920},
    "frame_rate": 30,
    "video_codec": "h264",
    "audio_codec": "aac"
  },
  "scenes": [
    {
      "id": "uuid",
      "order": 0,
      "title": "...",
      "duration_ms": 5000,
      "transition": {},
      "blocks": [
        {
          "id": "uuid",
          "type": "title|paragraph|formula|definition|exercise|correction",
          "content": "...",
          "order": 0,
          "visible": true,
          "animation": {},
          "position": {},
          "style": {}
        }
      ]
    }
  ]
}

RÉPONSE :
Réponds UNIQUEMENT avec le JSON valide, sans markdown, sans commentaire.
```

**Prompt utilisateur (Mode A - Sujet simple) :**
```typescript
Sujet : "${subject}"
```

**Prompt utilisateur (Mode B - Texte complet) :**
```typescript
Sujet : "${subject}"

TEXTE COMPLET :
"${content}"
```

**Prompt utilisateur (Mode C - Plan) :**
```typescript
Sujet : "${subject}"

PLAN :
"${content}"
```

**Prompt utilisateur (Mode D - Cours existant) :**
```typescript
COURS ID : "${content}"
SUJET : "${subject}"
```

---

### 3.2 JSON Schema Demandé

**Structure JSON demandée à OpenRouter :**

```json
{
  "version": "1.0",
  "created_at": "ISO8601",
  "created_by": "UUID",
  "subject": "string",
  "renderer": "scientific|notebook",
  "theme": "scientific|notebook",
  "narration_mode": "none|tts|userRecording",
  "export_settings": {
    "format": "mp4",
    "resolution": {
      "width": 1080,
      "height": 1920
    },
    "frame_rate": 30,
    "video_codec": "h264",
    "audio_codec": "aac"
  },
  "scenes": [
    {
      "id": "UUID",
      "order": 0,
      "title": "string",
      "duration_ms": 5000,
      "transition": {},
      "blocks": [
        {
          "id": "UUID",
          "type": "title|paragraph|formula|definition|exercise|correction",
          "content": "string",
          "order": 0,
          "visible": true,
          "animation": {},
          "position": {},
          "style": {}
        }
      ]
    }
  ]
}
```

**Contraintes de validation (validateStoryboard) :**
- `version` doit être "1.0"
- `renderer` doit être "scientific" ou "notebook"
- `theme` doit être "scientific" ou "notebook"
- `narration_mode` doit être "none", "tts" ou "userRecording"
- `scenes` doit être un tableau de 1 à 20 éléments
- Chaque scène doit avoir 1 à 10 blocs
- Chaque bloc doit avoir un type valide
- Chaque bloc doit avoir un contenu non vide
- Taille JSON max 100KB

---

### 3.3 Réponse Attendue OpenRouter

**Format attendu :**
```json
{
  "choices": [
    {
      "message": {
        "content": "{...JSON valide...}"
      }
    }
  ],
  "usage": {
    "prompt_tokens": number,
    "completion_tokens": number,
    "total_tokens": number
  }
}
```

**Nettoyage appliqué par Edge Function :**
- Suppression des backticks markdown ```json et ```
- Trim du contenu
- Parsing JSON
- Validation du schema

---

## RÉSUMÉ DES CONTRATS

### Contrat Flutter → Edge Function
**Input :**
```dart
{
  "mode": "simple_subject",
  "subject": "dérivés",
  "content": "",
  "renderer": "scientific",
  "theme": "scientific",
  "narration_mode": "tts"
}
```

**Output attendu (succès) :**
```dart
{
  "success": true,
  "storyboard_json": {...}
}
```

**Output attendu (erreur) :**
```dart
{
  "error": "string"
}
```

### Contrat Edge Function → OpenRouter
**Input :**
```typescript
{
  "model": "...",
  "messages": [
    {role: "system", content: "..."},
    {role: "user", content: "Sujet : \"dérivés\""}
  ],
  "temperature": 0.2,
  "max_tokens": 4000
}
```

**Output attendu :**
```typescript
{
  "choices": [{message: {content: "{...JSON...}"}}],
  "usage": {...}
}
```

### Contrat OpenRouter → Parser TS
**Input :**
```typescript
rawResponse: string (contenu de OpenRouter)
```

**Output attendu :**
```typescript
parsed: {
  version: "1.0",
  created_at: "...",
  created_by: "...",
  subject: "...",
  renderer: "scientific",
  theme: "scientific",
  narration_mode: "tts",
  export_settings: {...},
  scenes: [...]
}
```

**OU erreur :**
```typescript
{
  error: "invalid_json" | "invalid_storyboard",
  detail: "...",
  raw: "..."
}
```

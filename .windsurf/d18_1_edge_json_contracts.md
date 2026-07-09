# D.18.1 – PHASE 3: CONTRATS JSON EDGE FUNCTION

**Date**: 2026-06-26
**Mission**: D.18.1
**Fichier analysé**: `supabase/functions/whiteboard-generate-storyboard/index.ts`

---

## RÉPONSES D'ERREUR

### 1. Méthode non autorisée

- **Status**: 405
- **Fichier**: `index.ts:320`
- **Code**:
  ```typescript
  return jsonResponse({ error: 'Method not allowed' }, 405);
  ```
- **Contrat JSON**:
  ```json
  { "error": "Method not allowed" }
  ```
- **Clés**: `error: string`
- **Obligatoire**: `error`

### 2. Non authentifié

- **Status**: 401
- **Fichier**: `index.ts:338`
- **Code**:
  ```typescript
  return jsonResponse({ error: 'not_authenticated' }, 401);
  ```
- **Contrat JSON**:
  ```json
  { "error": "not_authenticated" }
  ```
- **Clés**: `error: string`
- **Obligatoire**: `error`

### 3. Crédits insuffisants

- **Status**: 402
- **Fichier**: `index.ts:358-363`
- **Code**:
  ```typescript
  return jsonResponse({
    error: 'insufficient_credits',
    balance: res?.balance ?? 0,
    cost: res?.cost ?? 0,
    message: `Crédits insuffisants...`
  }, 402);
  ```
- **Contrat JSON**:
  ```json
  {
    "error": "insufficient_credits",
    "balance": 0,
    "cost": 0,
    "message": "Crédits insuffisants..."
  }
  ```
- **Clés**:
  - `error: string` (obligatoire)
  - `balance: number` (optionnel, default 0)
  - `cost: number` (optionnel, default 0)
  - `message: string` (optionnel)

### 4. Erreur LLM

- **Status**: 502
- **Fichier**: `index.ts:397`
- **Code**:
  ```typescript
  return jsonResponse({ error: 'llm_error', detail: (e as Error).message?.slice(0, 300) }, 502);
  ```
- **Contrat JSON**:
  ```json
  { "error": "llm_error", "detail": "..." }
  ```
- **Clés**:
  - `error: string` (obligatoire)
  - `detail: string` (optionnel)

### 5. JSON invalide

- **Status**: 500
- **Fichier**: `index.ts:423-427`
- **Code**:
  ```typescript
  return jsonResponse({
    error: 'invalid_json',
    detail: (e as Error).message?.slice(0, 300),
    raw: rawResponse.slice(0, 500)
  }, 500);
  ```
- **Contrat JSON**:
  ```json
  {
    "error": "invalid_json",
    "detail": "...",
    "raw": "..."
  }
  ```
- **Clés**:
  - `error: string` (obligatoire)
  - `detail: string` (optionnel)
  - `raw: string` (optionnel)

### 6. Storyboard invalide

- **Status**: 500
- **Fichier**: `index.ts:434-438`
- **Code**:
  ```typescript
  return jsonResponse({
    error: 'invalid_storyboard',
    detail: validation.error,
    raw: rawResponse.slice(0, 500)
  }, 500);
  ```
- **Contrat JSON**:
  ```json
  {
    "error": "invalid_storyboard",
    "detail": "...",
    "raw": "..."
  }
  ```
- **Clés**:
  - `error: string` (obligatoire)
  - `detail: string` (optionnel)
  - `raw: string` (optionnel)

### 7. Erreur interne (catch global)

- **Status**: 500
- **Fichier**: `index.ts:510-513`
- **Code**:
  ```typescript
  return jsonResponse({
    error: 'internal_error',
    detail: (e as Error).message?.slice(0, 300)
  }, 500);
  ```
- **Contrat JSON**:
  ```json
  { "error": "internal_error", "detail": "..." }
  ```
- **Clés**:
  - `error: string` (obligatoire)
  - `detail: string` (optionnel)

---

## RÉPONSE DE SUCCÈS

### Status: 200

- **Fichier**: `index.ts:497-506`
- **Code**:
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

### Contrat JSON

```json
{
  "success": true,
  "storyboard_json": {
    "version": "string",
    "created_at": "string",
    "created_by": "string",
    "subject": "string",
    "renderer": "string",
    "theme": "string",
    "narration_mode": "string",
    "export_settings": {
      "format": "string",
      "resolution": { "width": 1920, "height": 1080 },
      "frame_rate": 30,
      "video_codec": "string",
      "audio_codec": "string"
    },
    "scenes": [ ... ]
  },
  "project_data": {
    "success": true,
    "project_id": "uuid"
  },
  "credits_used": 15,
  "model": "string",
  "tokens_input": 0,
  "tokens_output": 0,
  "cost_usd": 0
}
```

### Clés exactes

| Clé | Type | Obligatoire | Source |
|-----|------|-------------|--------|
| `success` | `boolean` | oui | `jsonResponse` |
| `storyboard_json` | `object` | oui | LLM + metadata injection |
| `storyboard_json.version` | `string` | oui | LLM output |
| `storyboard_json.created_at` | `string` | oui | injecté: `new Date().toISOString()` |
| `storyboard_json.created_by` | `string` | oui | injecté: `userId` |
| `storyboard_json.subject` | `string` | oui | injecté: `subject` |
| `storyboard_json.renderer` | `string` | oui | injecté: `renderer` |
| `storyboard_json.theme` | `string` | oui | injecté: `theme` |
| `storyboard_json.narration_mode` | `string` | oui | injecté: `narrationMode` |
| `storyboard_json.export_settings` | `object` | oui | LLM output |
| `storyboard_json.export_settings.format` | `string` | oui | LLM output |
| `storyboard_json.export_settings.resolution` | `object` | oui | LLM output |
| `storyboard_json.export_settings.resolution.width` | `number` | oui | LLM output |
| `storyboard_json.export_settings.resolution.height` | `number` | oui | LLM output |
| `storyboard_json.export_settings.frame_rate` | `number` | oui | LLM output |
| `storyboard_json.export_settings.video_codec` | `string` | oui | LLM output |
| `storyboard_json.export_settings.audio_codec` | `string` | oui | LLM output |
| `storyboard_json.scenes` | `array` | oui | LLM output |
| `project_data` | `object` | oui | RPC `whiteboard_create_project` |
| `project_data.success` | `boolean` | oui | RPC |
| `project_data.project_id` | `string` | oui | RPC |
| `credits_used` | `number` | oui | constante `15` |
| `model` | `string` | oui | `cascadeResult.model` |
| `tokens_input` | `number` | oui | `cascadeResult.usage.prompt_tokens || 0` |
| `tokens_output` | `number` | oui | `cascadeResult.usage.completion_tokens || 0` |
| `cost_usd` | `number` | oui | `cascadeResult.costUsd` |

---

## MISMATCH AVEC FLUTTER

Flutter consomme:
```dart
final storyboardJson = data['storyboard_json'] as Map<String, dynamic>?;
```

Edge Function produit bien `storyboard_json` comme `Map<String, dynamic>`.

✅ **MATCH** pour `storyboard_json`.

Flutter ignore actuellement `project_data`, `credits_used`, `model`, `tokens_input`, `tokens_output`, `cost_usd`. Ce n'est pas un bug, mais une non-utilisation.

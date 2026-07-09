# D.23 – PHASE 3 : CONTRAT ATTENDU EDGE FUNCTION

**Date** : 2026-06-28  
**Source** : Code source réel lu directement — `supabase/functions/whiteboard-generate-storyboard/index.ts`  
**Fichier** : `c:\Users\fasop\AndroidStudioProjects\academia\supabase\functions\whiteboard-generate-storyboard\index.ts` (516 lignes)

---

## 1. PARAMÈTRES D'ENTRÉE — VALEURS REÇUES ET DEFAULTS

```typescript
// index.ts:343-348
const mode = (body.mode ?? 'simple_subject').toString().trim();
const subject = (body.subject ?? '').toString().trim();
const content = (body.content ?? '').toString().trim();
const renderer = (body.renderer ?? 'scientific').toString().trim();
const theme = (body.theme ?? 'scientific').toString().trim();
const narrationMode = (body.narration_mode ?? 'none').toString().trim();
```

| Paramètre | Défaut si absent | Défaut si vide (`""`) | Validation obligatoire? |
|-----------|-----------------|----------------------|------------------------|
| `mode` | `"simple_subject"` | Reste `""` | ❌ Non — pas de vérification |
| `subject` | `""` | Reste `""` | ❌ **Non — sujet vide autorisé** |
| `content` | `""` | Reste `""` | ❌ Non |
| `renderer` | `"scientific"` | Reste `""` | ✅ validé via `validateStoryboard()` (ligne 100) |
| `theme` | `"scientific"` | Reste `""` | ✅ validé via `validateStoryboard()` (ligne 105) |
| `narration_mode` | `"none"` | Reste `""` | ✅ validé via `validateStoryboard()` (ligne 110) |

---

## 2. QUESTION 1 : LE `subject` VIDE EST-IL AUTORISÉ ?

**Réponse** : ✅ **OUI — le `subject` vide est autorisé par l'Edge Function.**

**Preuve code** :

```typescript
// index.ts:344
const subject = (body.subject ?? '').toString().trim();
```

La fonction accepte `subject=""` sans vérification ni rejet. La validation `validateStoryboard()` vérifie les champs du storyboard retourné (scenes, blocks), mais **ne vérifie pas** que `subject` est non-vide.

```typescript
// index.ts:87-91
const required = ['version', 'created_at', 'created_by', 'subject', 'renderer', 'theme', 'narration_mode', 'export_settings', 'scenes'];
for (const field of required) {
  if (!(field in sb)) {
    return { valid: false, error: `Missing field: ${field}` };
  }
}
```

`subject` doit être **présent** (non `undefined`) mais peut être une chaîne vide `""`. Il n'y a aucune vérification `subject.length > 0`.

---

## 3. QUESTION 2 : VALEUR PAR DÉFAUT PRÉVUE POUR `subject` ?

**Réponse** : La valeur par défaut est `""` (chaîne vide). Il n'existe aucune valeur par défaut de substitution (ex : "Cours général", "Sujet indéfini").

```typescript
// index.ts:344
const subject = (body.subject ?? '').toString().trim();
// Si body.subject est undefined → ''
// Si body.subject est ''      → ''
// Si body.subject est 'toto'  → 'toto'
```

---

## 4. QUESTION 3 : POURQUOI L'IA GÉNÈRE "LES LOIS DE NEWTON" AVEC `subject=""` ?

**Mécanisme complet** :

### Étape A — Construction du prompt utilisateur

```typescript
// index.ts:371-384
switch (mode) {
  case 'simple_subject':
    userPrompt = `Sujet : "${subject}"`;   // → Sujet : ""
    break;
  ...
}
```

Quand `subject=""`, le prompt utilisateur est : `Sujet : ""`

### Étape B — System prompt

```typescript
// index.ts:204-270 (getSystemPrompt)
const basePrompt = `Tu es un expert en création de Storyboards pédagogiques...

MODE A : SUJET SIMPLE
Génère un Storyboard JSON valide pour le sujet fourni.
Structure le contenu de manière pédagogique :
- Introduction au sujet
- Définitions clés
- Exemples concrets
- Exercice d'application
- Correction`;
```

Le system prompt demande à l'IA de générer pour "le sujet fourni". Avec `sujet=""`, l'IA interprète le manque de sujet et génère un contenu par défaut de sa propre initiative — en l'occurrence "Les Lois de Newton" (un sujet de physique courant dans les modèles LLM).

### Étape C — Injection des métadonnées après génération

```typescript
// index.ts:442-448
sb.created_at = new Date().toISOString();
sb.created_by = userId;
sb.subject = subject;       // ← '' injecté tel quel
sb.renderer = renderer;     // ← 'scientific' injecté
sb.theme = theme;           // ← 'scientific' injecté
sb.narration_mode = narrationMode; // ← 'none' injecté
```

**Peu importe ce que l'IA écrit dans `subject`** — la valeur est **écrasée** par le `subject` reçu en entrée. Donc même si l'IA génère un JSON avec `subject: "Les Lois de Newton"`, le champ est remplacé par `""`.

**Preuve runtime** : DEBUG-D19-72 → `Storyboard.fromJson subject= runtimeType=String isNull=false`

**Conclusion** : L'IA génère un storyboard sur "Les Lois de Newton" (titre des scenes et blocs) mais le champ `subject` du JSON retourné est forcé à `""` par l'Edge Function (ligne 445 : `sb.subject = subject`).

---

## 5. QUESTION 4 : LE `renderer="scientific"` PAR DÉFAUT EST-IL VOLONTAIRE ?

**Réponse** : ✅ **OUI — intentionnel.**

```typescript
// index.ts:346
const renderer = (body.renderer ?? 'scientific').toString().trim();
```

Le fallback `'scientific'` est le renderer par défaut de l'Edge Function. C'est une décision de design : si Flutter ne spécifie pas de renderer, l'Edge Function utilise `scientific`.

**Impact** : Quand Flutter envoie `renderer: _currentProject?.rendererId ?? 'scientific'` avec `_currentProject == null`, le résultat `'scientific'` coïncide avec le défaut de l'Edge Function — mais c'est une coïncidence de deux bugs différents produisant la même valeur incorrecte (l'utilisateur avait choisi `notebook`).

---

## 6. QUESTION 5 : LE `narration_mode="none"` PAR DÉFAUT EST-IL VOLONTAIRE ?

**Réponse** : ✅ **OUI — intentionnel.**

```typescript
// index.ts:348
const narrationMode = (body.narration_mode ?? 'none').toString().trim();
```

`none` est le mode narration par défaut. Raisonnable : sans narration, le storyboard reste valide visuellement.

**Impact** : L'utilisateur avait choisi `tts` — la narration TTS est silencieusement ignorée à cause du bug Flutter.

---

## 7. VALIDATION DU STORYBOARD RETOURNÉ

```typescript
// index.ts:431-439 (validateStoryboard)
const validation = validateStoryboard(parsed);
if (!validation.valid) {
  await supabase.rpc('app_student_refund_credits', { p_reservation_id: reservationId });
  return jsonResponse({ error: 'invalid_storyboard', ... }, 500);
}
```

La validation vérifie :
- Champs obligatoires présents (dont `subject` — mais vide autorisé)
- `renderer` ∈ `['scientific', 'notebook']`
- `theme` ∈ `['scientific', 'notebook']`
- `narration_mode` ∈ `['none', 'tts', 'userRecording']`
- `scenes.length` entre 1 et 20
- Chaque scene : `id`, `order`, `title`, `duration_ms`, `blocks`
- Chaque bloc : `id`, `type`, `content`, `order`, `visible`; `content` non vide

**Observation** : La validation du **contenu sémantique** (sujet cohérent) est inexistante — c'est volontaire.

---

## 8. SECOND APPEL À `whiteboard_create_project` DANS L'EDGE FUNCTION

```typescript
// index.ts:451-458
const { data: projectData } = await supabase.rpc('whiteboard_create_project', {
  p_student_id: userId,
  p_subject: subject,        // ← '' si sujet vide
  p_renderer_id: renderer,   // ← 'scientific' si fallback
  p_theme_id: theme,
  p_narration_mode: narrationMode,
  p_storyboard_json: sb,
});
```

**Découverte critique** : L'Edge Function **recrée elle-même un projet** dans Supabase après génération du storyboard ! Elle stocke le storyboard généré dans un **nouveau projet** séparé — avec `subject=""`, `renderer="scientific"`.

Cela signifie que lors du test D.22, **deux projets ont été créés pour chaque génération** :
1. Le projet créé par Flutter via `whiteboard_create_project` (D19-01)
2. Le projet créé par l'Edge Function en interne (ligne 451)

La réponse de l'Edge Function inclut `project_data` mais Flutter ne l'utilise pas.

---

## 9. CONCLUSION PHASE 3

| Question | Réponse |
|----------|---------|
| `subject` vide autorisé ? | ✅ OUI — pas de validation |
| Valeur par défaut `subject` | `""` (chaîne vide) |
| Pourquoi "Les Lois de Newton" ? | L'IA génère un sujet spontanément, mais le champ est écrasé par `""` en step 6 |
| `renderer="scientific"` volontaire ? | ✅ OUI — défaut Edge Function |
| `narration_mode="none"` volontaire ? | ✅ OUI — défaut Edge Function |
| Découverte bonus | L'Edge Function recrée elle-même un projet (double création) — Flutter ignore `project_data` |

---

**DOCUMENT CLÔTURÉ** — Source : code source réel `index.ts` (516 lignes).

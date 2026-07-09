# PHASE D.3A.2 – OPENROUTER ARCHITECTURE

**Date** : 23 Juin 2026  
**Phase** : D.3A.2 – IA Generation Architecture Refactor  
**Mode** : ARCHITECTURE

---

## OBJECTIF

Définir l'architecture cible pour la génération de Storyboard basée sur OpenRouter, dissociée de Bobodo Assistant.

---

## DIRECTIVE

Le Smart Whiteboard ne doit plus être conçu comme une fonctionnalité de Bobodo Assistant.

---

## PARTIE 1 – ARCHITECTURE CIBLE

### 1.1 Flux Complet

```
Smart Whiteboard Input Screen
  ↓
Smart Whiteboard Content Agent (Edge Function)
  ↓
OpenRouter (Cascade Multi-Modèles)
  ↓
Storyboard JSON
  ↓
Supabase (whiteboard_projects.storyboard_json)
  ↓
Kamatera Renderer
  ↓
MP4
```

### 1.2 Couches

#### Couche 1 : Flutter UI

**Composant** : `SmartWhiteboardInputScreen`

**Responsabilités** :
- Saisie utilisateur (sujet, texte, plan, cours)
- Sélection renderer/theme/narration
- Appel Edge Function
- Affichage loading/erreur/succès
- Navigation vers éditeur

**Sortie** : `{ mode, subject, content, renderer, theme, narration_mode }`

#### Couche 2 : Edge Function

**Composant** : `whiteboard-generate-storyboard`

**Responsabilités** :
- Auth Supabase
- Réserve crédits
- Appel OpenRouter cascade
- Validation JSON Storyboard
- Confirmation crédits
- Stockage Supabase

**Entrée** : `{ mode, subject, content, renderer, theme, narration_mode }`

**Sortie** : `{ storyboard_json, credits_used, model }`

#### Couche 3 : OpenRouter

**Composant** : API OpenRouter

**Responsabilités** :
- Génération Storyboard JSON
- Cascade multi-modèles
- Fallback automatique

**Modèles** :
- Primary : `google/gemini-2.0-flash-001`
- Fallback 1 : `google/gemini-2.0-flash-lite-001`
- Fallback 2 : `nvidia/nemotron-3-super-120b-a12b:free`
- Fallback 3 : `qwen/qwen3.6-plus:free`

#### Couche 4 : Supabase

**Composant** : `whiteboard_projects`

**Responsabilités** :
- Stockage Storyboard JSON (JSONB)
- RPCs CRUD (create, read, update, delete)
- RLS policies

**Table** :
```sql
CREATE TABLE app.whiteboard_projects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID REFERENCES app.students(id),
  subject TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'draft',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  renderer_id TEXT NOT NULL,
  theme_id TEXT NOT NULL,
  narration_mode TEXT NOT NULL,
  storyboard_json JSONB NOT NULL DEFAULT '{}'::jsonb
);
```

#### Couche 5 : Kamatera Renderer

**Composant** : Backend Python Kamatera

**Responsabilités** :
- Téléchargement Storyboard JSON
- Génération images PNG
- Encodage MP4 (FFmpeg)
- Upload MP4 Supabase Storage

**Entrée** : `storyboard_json`

**Sortie** : `mp4_url`

---

## PARTIE 2 – DISSOCIATION BOBODO VS SMART WHITEBOARD

### 2.1 Bobodo Assistant

**Responsabilités** :
- Assistant général Academia
- Orientation études/emploi
- Réponses questions plateforme
- Aide utilisateur

**Données manipulées** :
- bobodo_knowledge
- bobodo_sessions
- bobodo_answer_cache
- students

**Modèles IA** :
- Cascade multi-modèles
- RAG sémantique
- Cache sémantique
- Expansion sémantique

**Sorties attendues** :
- Réponses texte
- Streaming SSE
- Catégorisation automatique

**Edge Function** : `bobodo-chat`

### 2.2 Smart Whiteboard Content Agent

**Responsabilités** :
- Génération Storyboard JSON
- Structuration pédagogique
- Création scènes et blocs
- Adaptation renderer/theme

**Données manipulées** :
- whiteboard_projects
- storyboard_json (JSONB)
- Input utilisateur

**Modèles IA** :
- Cascade multi-modèles (réutilisé)
- Prompt spécialisé Storyboard
- Validation JSON stricte

**Sorties attendues** :
- Storyboard JSON valide
- Conforme storyboard_models.dart
- Conforme SMART_WHITEBOARD_DATA_CONTRACT.md

**Edge Function** : `whiteboard-generate-storyboard`

### 2.3 Aucun Chevauchement Fonctionnel

| Aspect | Bobodo Assistant | Smart Whiteboard Content Agent |
|--------|-----------------|-------------------------------|
| **Objectif** | Assistant général | Génération Storyboard |
| **Données** | bobodo_* | whiteboard_projects |
| **Output** | Réponses texte | Storyboard JSON |
| **RAG** | ✅ | ❌ (V2 optionnel) |
| **Cache** | ✅ | ❌ (V2 optionnel) |
| **Prompt** | Assistant général | Storyboard spécialisé |
| **Edge Function** | bobodo-chat | whiteboard-generate-storyboard |

---

## PARTIE 3 – CONTRAT DE GÉNÉRATION

### 3.1 Entrée

```json
{
  "mode": "simple_subject|full_text|plan|existing_course",
  "subject": "string",
  "content": "string",
  "renderer": "scientific|notebook",
  "theme": "scientific|notebook",
  "narration_mode": "none|tts|user_recording"
}
```

**Modes** :
- `simple_subject` : Sujet simple (ex: "Dérivée d'une fonction")
- `full_text` : Texte complet (ex: article PDF complet)
- `plan` : Plan structuré (ex: I. Introduction, II. Développement, III. Conclusion)
- `existing_course` : Cours existant (ex: ID cours Supabase)

### 3.2 Sortie

```json
{
  "version": "1.0",
  "created_at": "iso8601",
  "created_by": "uuid",
  "subject": "string",
  "renderer": "scientific|notebook",
  "theme": "scientific|notebook",
  "narration_mode": "none|tts|user_recording",
  "export_settings": {
    "resolution": "1080p",
    "fps": 30,
    "format": "mp4"
  },
  "scenes": [
    {
      "id": "uuid",
      "order": 0,
      "title": "string",
      "duration_ms": 5000,
      "transition": {},
      "blocks": [
        {
          "id": "uuid",
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

### 3.3 Compatibilité

**Conformité requise** :
- ✅ storyboard_models.dart
- ✅ SMART_WHITEBOARD_DATA_CONTRACT.md
- ✅ Renderer V1 Kamatera

---

## PARTIE 4 – VALIDATION JSON

### 4.1 Validation Avant Stockage

**Validation Edge Function** :
```typescript
function validateStoryboard(json: unknown): boolean {
  // Vérifier structure de base
  if (!json || typeof json !== 'object') return false;
  
  const sb = json as Record<string, unknown>;
  
  // Champs obligatoires
  const required = ['version', 'created_at', 'created_by', 'subject', 'renderer', 'theme', 'narration_mode', 'scenes'];
  for (const field of required) {
    if (!(field in sb)) return false;
  }
  
  // Scenes doit être un tableau
  if (!Array.isArray(sb.scenes)) return false;
  
  // Chaque scène doit avoir blocks
  for (const scene of sb.scenes) {
    if (!scene.blocks || !Array.isArray(scene.blocks)) return false;
  }
  
  return true;
}
```

### 4.2 Validation Avant Rendu

**Validation Kamatera** :
```python
def validate_storyboard_for_render(storyboard: dict) -> bool:
    # Vérifier structure
    required = ['version', 'scenes']
    for field in required:
        if field not in storyboard:
            return False
    
    # Vérifier scenes
    if not isinstance(storyboard['scenes'], list):
        return False
    
    # Vérifier blocks
    for scene in storyboard['scenes']:
        if 'blocks' not in scene:
            return False
        if not isinstance(scene['blocks'], list):
            return False
    
    return True
```

### 4.3 Gestion Erreurs

**JSON invalide** :
- Edge Function : HTTP 500, `{ error: 'invalid_json', raw: '...' }`
- Remboursement crédits automatique
- Message utilisateur : "La génération du Storyboard a échoué. Veuillez réessayer."

**JSON incomplet** :
- Edge Function : HTTP 500, `{ error: 'incomplete_json', missing_fields: [...] }`
- Remboursement crédits automatique
- Message utilisateur : "Le Storyboard généré est incomplet. Veuillez réessayer."

**JSON trop volumineux** :
- Edge Function : HTTP 500, `{ error: 'storyboard_too_large', size: 150000, max: 100000 }`
- Remboursement crédits automatique
- Message utilisateur : "Le Storyboard est trop volumineux. Simplifiez votre sujet."

---

## PARTIE 5 – MODES DE GÉNÉRATION

### 5.1 Mode A : Sujet Simple

**Entrée** :
```json
{
  "mode": "simple_subject",
  "subject": "Dérivée d'une fonction"
}
```

**Prompt** :
```
Tu es un expert en création de Storyboards pédagogiques pour le Smart Whiteboard Academia.

Génère un Storyboard JSON valide pour le sujet : "Dérivée d'une fonction"

RÈGLES STRICTES :
1. Le Storyboard doit être conforme au format JSON défini dans SMART_WHITEBOARD_DATA_CONTRACT.md
2. Structure le contenu en 5-10 scènes
3. Chaque scène contient 3-6 blocs (title, paragraph, formula, definition, exercise, correction)
4. Utilise les types de blocs appropriés pour le sujet (formula pour les mathématiques)
5. Adapte le contenu au renderer "scientific" et au thème "scientific"
6. Le narration_mode est "none"

FORMAT JSON REQUIS :
{
  "version": "1.0",
  "created_at": "iso8601",
  "created_by": "uuid",
  "subject": "Dérivée d'une fonction",
  "renderer": "scientific",
  "theme": "scientific",
  "narration_mode": "none",
  "export_settings": { "resolution": "1080p", "fps": 30, "format": "mp4" },
  "scenes": [...]
}

Réponds UNIQUEMENT avec le JSON valide, sans markdown, sans commentaire.
```

**Sortie attendue** : Storyboard JSON avec scènes structurées sur la dérivée

### 5.2 Mode B : Texte Complet

**Entrée** :
```json
{
  "mode": "full_text",
  "subject": "Loi d'Ohm",
  "content": "La loi d'Ohm est une loi physique qui relie l'intensité du courant électrique traversant un dipôle électrique à la tension à ses bornes..."
}
```

**Prompt** :
```
Tu es un expert en création de Storyboards pédagogiques pour le Smart Whiteboard Academia.

Génère un Storyboard JSON valide à partir du texte complet fourni.

SUJET : "Loi d'Ohm"

TEXTE COMPLET :
"La loi d'Ohm est une loi physique qui relie l'intensité du courant électrique traversant un dipôle électrique à la tension à ses bornes..."

RÈGLES STRICTES :
1. Le Storyboard doit être conforme au format JSON défini dans SMART_WHITEBOARD_DATA_CONTRACT.md
2. Structure le contenu en 5-10 scènes basées sur le texte
3. Chaque scène contient 3-6 blocs (title, paragraph, formula, definition, exercise, correction)
4. Utilise les types de blocs appropriés (formula pour U = R × I)
5. Adapte le contenu au renderer "scientific" et au thème "scientific"
6. Le narration_mode est "none"

FORMAT JSON REQUIS :
{
  "version": "1.0",
  "created_at": "iso8601",
  "created_by": "uuid",
  "subject": "Loi d'Ohm",
  "renderer": "scientific",
  "theme": "scientific",
  "narration_mode": "none",
  "export_settings": { "resolution": "1080p", "fps": 30, "format": "mp4" },
  "scenes": [...]
}

Réponds UNIQUEMENT avec le JSON valide, sans markdown, sans commentaire.
```

**Sortie attendue** : Storyboard JSON avec scènes basées sur le texte

### 5.3 Mode C : Plan

**Entrée** :
```json
{
  "mode": "plan",
  "subject": "Révolution française",
  "content": "I. Causes de la Révolution\nII. Événements clés\nIII. Conséquences"
}
```

**Prompt** :
```
Tu es un expert en création de Storyboards pédagogiques pour le Smart Whiteboard Academia.

Génère un Storyboard JSON valide à partir du plan structuré fourni.

SUJET : "Révolution française"

PLAN :
I. Causes de la Révolution
II. Événements clés
III. Conséquences

RÈGLES STRICTES :
1. Le Storyboard doit être conforme au format JSON défini dans SMART_WHITEBOARD_DATA_CONTRACT.md
2. Structure le contenu en scènes basées sur le plan (une scène par section)
3. Chaque scène contient 3-6 blocs (title, paragraph, definition, exercise, correction)
4. Développe chaque section du plan en détail
5. Adapte le contenu au renderer "notebook" et au thème "notebook"
6. Le narration_mode est "none"

FORMAT JSON REQUIS :
{
  "version": "1.0",
  "created_at": "iso8601",
  "created_by": "uuid",
  "subject": "Révolution française",
  "renderer": "notebook",
  "theme": "notebook",
  "narration_mode": "none",
  "export_settings": { "resolution": "1080p", "fps": 30, "format": "mp4" },
  "scenes": [...]
}

Réponds UNIQUEMENT avec le JSON valide, sans markdown, sans commentaire.
```

**Sortie attendue** : Storyboard JSON avec scènes basées sur le plan

### 5.4 Mode D : Cours Existant

**Entrée** :
```json
{
  "mode": "existing_course",
  "subject": "Physique quantique",
  "content": "course_id: abc-123-def"
}
```

**Prompt** :
```
Tu es un expert en création de Storyboards pédagogiques pour le Smart Whiteboard Academia.

Génère un Storyboard JSON valide à partir du cours existant.

COURS ID : abc-123-def
SUJET : "Physique quantique"

RÈGLES STRICTES :
1. Le Storyboard doit être conforme au format JSON défini dans SMART_WHITEBOARD_DATA_CONTRACT.md
2. Structure le contenu en 5-10 scènes basées sur le cours
3. Chaque scène contient 3-6 blocs (title, paragraph, formula, definition, exercise, correction)
4. Utilise les types de blocs appropriés (formula pour les équations quantiques)
5. Adapte le contenu au renderer "scientific" et au thème "scientific"
6. Le narration_mode est "none"

FORMAT JSON REQUIS :
{
  "version": "1.0",
  "created_at": "iso8601",
  "created_by": "uuid",
  "subject": "Physique quantique",
  "renderer": "scientific",
  "theme": "scientific",
  "narration_mode": "none",
  "export_settings": { "resolution": "1080p", "fps": 30, "format": "mp4" },
  "scenes": [...]
}

Réponds UNIQUEMENT avec le JSON valide, sans markdown, sans commentaire.
```

**Sortie attendue** : Storyboard JSON avec scènes basées sur le cours

---

## PARTIE 6 – STRATÉGIE OPENROUTER

### 6.1 Modèle

**Modèle principal** : `google/gemini-2.0-flash-001`

**Raisons** :
- Haute qualité génération JSON
- Support structuration complexe
- Coût raisonnable
- Fallback cascade disponible

### 6.2 Coût

**Génération Storyboard** :
- Input : ~500 tokens (sujet + instructions)
- Output : ~2000 tokens (Storyboard JSON)
- Coût estimé : ~$0.001 - $0.002 par génération

**Crédits Academia** :
- Coût converti en crédits : ~10-20 crédits par génération
- Prix pack : 100 crédits = 250 XOF

### 6.3 Temps

**Génération Storyboard** :
- Temps moyen : 3-5 secondes
- Cascade : +1-2 secondes si fallback
- Total : 5-7 secondes maximum

### 6.4 Taille

**Limite recommandée** : 100 Ko

**Scènes recommandées** : 5-10 scènes
**Blocs recommandés** : 20-50 blocs

---

## CONCLUSION

### Architecture Autonome

Le Smart Whiteboard repose sur une architecture autonome de génération pédagogique basée sur OpenRouter.

Bobodo Assistant reste dédié à l'assistance utilisateur et à l'orientation.

Aucune ambiguïté architecturale ne subsiste entre les deux systèmes.

### Composants Clés

- ✅ Edge Function `whiteboard-generate-storyboard`
- ✅ Cascade multi-modèles réutilisée
- ✅ Crédits system réutilisé
- ✅ Prompt spécialisé Storyboard
- ✅ Validation JSON stricte

### Prochaine Étape

Créer le document PHASE_D3A2_CONTENT_AGENT_SPEC.md pour spécifier l'agent de contenu.

---

**Fin de PHASE D.3A.2 – OPENROUTER ARCHITECTURE**

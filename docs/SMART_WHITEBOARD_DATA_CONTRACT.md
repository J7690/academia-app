# SMART WHITEBOARD IA V1 – DATA CONTRACT

**Version** : 1.0  
**Date** : 23 Juin 2026  
**Mode** : LECTURE SEULE  
**Objectif** : Contrat de données définitif

---

## DIRECTIVE TECHNIQUE PERMANENTE

Toute validation concernant Supabase, Kamatera Cloud, Docker, FFmpeg, Backend Python, Tables, Buckets, RPC, Edge Functions, Stockage, Ressources serveur doit obligatoirement être réalisée via les RPC Python administrateurs présents dans `.windsurf`.

Aucune hypothèse n'est autorisée. Aucune déduction n'est autorisée. Toute affirmation doit être vérifiée.

---

## RAPPEL DES COMPOSANTS PROTÉGÉS

Interdiction absolue de modifier :
- `challenge_camera_capture_screen.dart`
- `student_challenge_video_editor_screen.dart`
- `video_publish_screen.dart`
- `videoasset_upload_service.dart`
- Pipeline de compression Kamatera
- Pipeline de publication
- Tables `challenge_*`
- RPCs `challenge_*`
- Edge Functions `challenge_*`
- Workflows existants

---

## PARTIE 1 – WHITEBOARD PROJECT

### 1.1 Définition

`WhiteboardProject` représente un projet Smart Whiteboard créé par un étudiant.

### 1.2 Structure JSON

```json
{
  "id": "uuid",
  "student_id": "uuid",
  "subject": "string",
  "status": "draft|completed",
  "created_at": "iso8601",
  "updated_at": "iso8601",
  "renderer_id": "scientific|notebook",
  "theme_id": "scientific|notebook",
  "narration_mode": "none|tts|user_recording",
  "storyboard": {}
}
```

### 1.3 Champs

| Champ | Type | Obligatoire | Description |
|-------|------|-------------|-------------|
| id | UUID | ✅ | Identifiant unique du projet |
| student_id | UUID | ✅ | Identifiant de l'étudiant propriétaire |
| subject | String | ✅ | Sujet du projet |
| status | String | ✅ | Statut du projet (draft, completed) |
| created_at | ISO8601 | ✅ | Date de création |
| updated_at | ISO8601 | ✅ | Date de dernière modification |
| renderer_id | String | ✅ | ID du renderer (scientific, notebook) |
| theme_id | String | ✅ | ID du thème (scientific, notebook) |
| narration_mode | String | ✅ | Mode de narration (none, tts, user_recording) |
| storyboard | JSONB | ✅ | Storyboard JSON |

### 1.4 Correspondance

| Flutter | JSON | Supabase | Kamatera | Renderer |
|---------|------|----------|----------|----------|
| WhiteboardProject | ✅ | whiteboard_projects | ✅ | ✅ |

---

## PARTIE 2 – STORYBOARD

### 2.1 Définition

`Storyboard` représente le contenu pédagogique structuré du projet.

### 2.2 Structure JSON

```json
{
  "version": "1.0",
  "created_at": "iso8601",
  "created_by": "uuid",
  "subject": "string",
  "renderer": "scientific|notebook",
  "theme": "scientific|notebook",
  "narration_mode": "none|tts|user_recording",
  "export_settings": {},
  "scenes": []
}
```

### 2.3 Champs

| Champ | Type | Obligatoire | Description |
|-------|------|-------------|-------------|
| version | String | ✅ | Version du format Storyboard |
| created_at | ISO8601 | ✅ | Date de création |
| created_by | UUID | ✅ | Identifiant du créateur |
| subject | String | ✅ | Sujet du Storyboard |
| renderer | String | ✅ | Renderer utilisé (scientific, notebook) |
| theme | String | ✅ | Thème utilisé (scientific, notebook) |
| narration_mode | String | ✅ | Mode de narration (none, tts, user_recording) |
| export_settings | JSON | ✅ | Paramètres d'export |
| scenes | Array | ✅ | Liste des scènes |

### 2.4 Correspondance

| Flutter | JSON | Supabase | Kamatera | Renderer |
|---------|------|----------|----------|----------|
| Storyboard | ✅ | storyboard_json (JSONB) | ✅ | ✅ |

---

## PARTIE 3 – SCENE

### 3.1 Définition

`Scene` représente une section du Storyboard avec une durée estimée.

### 3.2 Structure JSON

```json
{
  "id": "uuid",
  "order": "integer",
  "title": "string",
  "duration_ms": "integer",
  "transition": {},
  "blocks": []
}
```

### 3.3 Champs

| Champ | Type | Obligatoire | Description |
|-------|------|-------------|-------------|
| id | UUID | ✅ | Identifiant unique de la scène |
| order | Integer | ✅ | Ordre de la scène |
| title | String | ✅ | Titre de la scène |
| duration_ms | Integer | ✅ | Durée estimée en millisecondes |
| transition | JSON | ❌ | Transition (non utilisé V1) |
| blocks | Array | ✅ | Liste des blocs |

### 3.4 Correspondance

| Flutter | JSON | Supabase | Kamatera | Renderer |
|---------|------|----------|----------|----------|
| Scene | ✅ | scenes (JSONB) | ✅ | ✅ |

---

## PARTIE 4 – BLOCK

### 4.1 Définition

`Block` représente un élément de contenu pédagogique.

### 4.2 Structure commune

```json
{
  "id": "uuid",
  "type": "string",
  "content": "string",
  "order": "integer",
  "visible": "boolean",
  "animation": {},
  "position": {},
  "style": {}
}
```

### 4.3 Champs communs

| Champ | Type | Obligatoire | Description |
|-------|------|-------------|-------------|
| id | UUID | ✅ | Identifiant unique du bloc |
| type | String | ✅ | Type du bloc |
| content | String | ✅ | Contenu du bloc |
| order | Integer | ✅ | Ordre du bloc |
| visible | Boolean | ✅ | Visibilité du bloc |
| animation | JSON | ❌ | Animation (non utilisé V1) |
| position | JSON | ❌ | Position (non utilisé V1) |
| style | JSON | ✅ | Style du bloc |

### 4.4 Types de blocs V1

| Type | Description |
|------|-------------|
| title | Titre principal |
| paragraph | Paragraphe de texte |
| formula | Formule mathématique (LaTeX) |
| definition | Définition d'un concept |
| exercise | Exercice |
| correction | Correction d'exercice |

### 4.5 Structure par type

#### Title

```json
{
  "id": "uuid",
  "type": "title",
  "content": "string",
  "order": "integer",
  "visible": "boolean",
  "style": {
    "font_size": "integer",
    "font_weight": "string",
    "color": "string"
  }
}
```

#### Paragraph

```json
{
  "id": "uuid",
  "type": "paragraph",
  "content": "string",
  "order": "integer",
  "visible": "boolean",
  "style": {
    "font_size": "integer",
    "color": "string"
  }
}
```

#### Formula

```json
{
  "id": "uuid",
  "type": "formula",
  "content": "string",
  "format": "latex",
  "order": "integer",
  "visible": "boolean",
  "style": {
    "font_size": "integer",
    "color": "string"
  }
}
```

#### Definition

```json
{
  "id": "uuid",
  "type": "definition",
  "term": "string",
  "definition": "string",
  "example": "string",
  "order": "integer",
  "visible": "boolean",
  "style": {
    "term_color": "string",
    "definition_color": "string",
    "example_color": "string"
  }
}
```

#### Exercise

```json
{
  "id": "uuid",
  "type": "exercise",
  "question": "string",
  "hint": "string",
  "solution": "string",
  "order": "integer",
  "visible": "boolean",
  "style": {
    "question_color": "string",
    "hint_color": "string",
    "solution_color": "string"
  }
}
```

#### Correction

```json
{
  "id": "uuid",
  "type": "correction",
  "exercise_id": "uuid",
  "steps": ["string"],
  "explanation": "string",
  "order": "integer",
  "visible": "boolean",
  "style": {
    "step_number_color": "string",
    "explanation_color": "string"
  }
}
```

### 4.6 Correspondance

| Flutter | JSON | Supabase | Kamatera | Renderer |
|---------|------|----------|----------|----------|
| Block | ✅ | blocks (JSONB) | ✅ | ✅ |

---

## PARTIE 5 – NARRATION

### 5.1 Définition

`Narration` représente la narration audio du projet.

### 5.2 Structure JSON

```json
{
  "mode": "none|tts|user_recording",
  "audio_url": "string",
  "duration_ms": "integer",
  "language": "string",
  "voice": "string"
}
```

### 5.3 Champs

| Champ | Type | Obligatoire | Description |
|-------|------|-------------|-------------|
| mode | String | ✅ | Mode de narration (none, tts, user_recording) |
| audio_url | String | ❌ | URL du fichier audio |
| duration_ms | Integer | ❌ | Durée de l'audio en millisecondes |
| language | String | ❌ | Langue de la narration |
| voice | String | ❌ | Voix TTS |

### 5.4 Modes V1

| Mode | Description |
|------|-------------|
| none | Pas de narration |
| tts | Narration générée par TTS |
| user_recording | Narration enregistrée par l'utilisateur |

### 5.5 Correspondance

| Flutter | JSON | Supabase | Kamatera | Renderer |
|---------|------|----------|----------|----------|
| Narration | ✅ | narration (JSONB) | ✅ | ✅ |

---

## PARTIE 6 – RENDER JOB

### 6.1 Définition

`RenderJob` représente un job de rendu vidéo.

### 6.2 Structure JSON

```json
{
  "id": "uuid",
  "project_id": "uuid",
  "status": "queued|processing|done|failed",
  "video_url": "string",
  "duration_ms": "integer",
  "error_message": "string",
  "progress": "integer",
  "created_at": "iso8601",
  "completed_at": "iso8601"
}
```

### 6.3 Champs

| Champ | Type | Obligatoire | Description |
|-------|------|-------------|-------------|
| id | UUID | ✅ | Identifiant unique du job |
| project_id | UUID | ✅ | Identifiant du projet |
| status | String | ✅ | Statut du job (queued, processing, done, failed) |
| video_url | String | ❌ | URL du MP4 généré |
| duration_ms | Integer | ❌ | Durée du MP4 en millisecondes |
| error_message | String | ❌ | Message d'erreur |
| progress | Integer | ❌ | Progression du rendu (0-100) |
| created_at | ISO8601 | ✅ | Date de création |
| completed_at | ISO8601 | ❌ | Date de complétion |

### 6.4 Statuts

| Statut | Description |
|--------|-------------|
| queued | En attente de traitement |
| processing | En cours de traitement |
| done | Terminé avec succès |
| failed | Échec |

### 6.5 Correspondance

| Flutter | JSON | Supabase | Kamatera | Renderer |
|---------|------|----------|----------|----------|
| RenderJob | ✅ | whiteboard_renders | ✅ | ✅ |

---

## PARTIE 7 – EXPORT SETTINGS

### 7.1 Définition

`ExportSettings` représente les paramètres d'export vidéo.

### 7.2 Structure JSON

```json
{
  "format": "mp4",
  "resolution": {
    "width": 1080,
    "height": 1920
  },
  "frame_rate": 30,
  "video_codec": "h264",
  "audio_codec": "aac"
}
```

### 7.3 Champs

| Champ | Type | Obligatoire | Description |
|-------|------|-------------|-------------|
| format | String | ✅ | Format de sortie (mp4) |
| resolution | JSON | ✅ | Résolution (width, height) |
| frame_rate | Integer | ✅ | Frame rate (30 fps) |
| video_codec | String | ✅ | Codec vidéo (h264) |
| audio_codec | String | ✅ | Codec audio (aac) |

### 7.4 Valeurs V1

| Paramètre | Valeur V1 |
|-----------|-----------|
| format | mp4 |
| resolution | 1080x1920 |
| frame_rate | 30 |
| video_codec | h264 |
| audio_codec | aac |

### 7.5 Correspondance

| Flutter | JSON | Supabase | Kamatera | Renderer |
|---------|------|----------|----------|----------|
| ExportSettings | ✅ | export_settings (JSONB) | ✅ | ✅ |

---

## PARTIE 8 – CORRESPONDANCE DES MODÈLES

### 8.1 Tableau de correspondance

| Modèle | Flutter | JSON | Supabase | Kamatera | Renderer |
|--------|---------|------|----------|----------|----------|
| WhiteboardProject | ✅ | ✅ | whiteboard_projects | ✅ | ✅ |
| Storyboard | ✅ | ✅ | storyboard_json (JSONB) | ✅ | ✅ |
| Scene | ✅ | ✅ | scenes (JSONB) | ✅ | ✅ |
| Block | ✅ | ✅ | blocks (JSONB) | ✅ | ✅ |
| Narration | ✅ | ✅ | narration (JSONB) | ✅ | ✅ |
| RenderJob | ✅ | ✅ | whiteboard_renders | ✅ | ✅ |
| ExportSettings | ✅ | ✅ | export_settings (JSONB) | ✅ | ✅ |

### 8.2 Flux de données

```
Flutter Model
  ↓
JSON (sérialisation)
  ↓
Supabase (stockage)
  ↓
Kamatera (récupération)
  ↓
Renderer (traitement)
  ↓
JSON (sérialisation)
  ↓
Supabase (stockage)
  ↓
Flutter Model (désérialisation)
```

---

## PARTIE 9 – VALIDATION DES CHAMPS

### 9.1 WhiteboardProject

| Champ | Flutter | Bobodo | Supabase | Kamatera | Renderer |
|-------|---------|--------|----------|----------|----------|
| id | ✅ | ❌ | ✅ | ✅ | ✅ |
| student_id | ✅ | ❌ | ✅ | ✅ | ❌ |
| subject | ✅ | ✅ | ✅ | ✅ | ✅ |
| status | ✅ | ❌ | ✅ | ✅ | ❌ |
| created_at | ✅ | ❌ | ✅ | ✅ | ❌ |
| updated_at | ✅ | ❌ | ✅ | ✅ | ❌ |
| renderer_id | ✅ | ✅ | ✅ | ✅ | ✅ |
| theme_id | ✅ | ✅ | ✅ | ✅ | ✅ |
| narration_mode | ✅ | ✅ | ✅ | ✅ | ✅ |
| storyboard | ✅ | ✅ | ✅ | ✅ | ✅ |

### 9.2 Storyboard

| Champ | Flutter | Bobodo | Supabase | Kamatera | Renderer |
|-------|---------|--------|----------|----------|----------|
| version | ✅ | ✅ | ✅ | ✅ | ✅ |
| created_at | ✅ | ✅ | ✅ | ✅ | ❌ |
| created_by | ✅ | ❌ | ✅ | ✅ | ❌ |
| subject | ✅ | ✅ | ✅ | ✅ | ✅ |
| renderer | ✅ | ✅ | ✅ | ✅ | ✅ |
| theme | ✅ | ✅ | ✅ | ✅ | ✅ |
| narration_mode | ✅ | ✅ | ✅ | ✅ | ✅ |
| export_settings | ✅ | ❌ | ✅ | ✅ | ✅ |
| scenes | ✅ | ✅ | ✅ | ✅ | ✅ |

### 9.3 Scene

| Champ | Flutter | Bobodo | Supabase | Kamatera | Renderer |
|-------|---------|--------|----------|----------|----------|
| id | ✅ | ✅ | ✅ | ✅ | ✅ |
| order | ✅ | ✅ | ✅ | ✅ | ✅ |
| title | ✅ | ✅ | ✅ | ✅ | ✅ |
| duration_ms | ✅ | ❌ | ✅ | ✅ | ✅ |
| transition | ✅ | ❌ | ✅ | ✅ | ❌ |
| blocks | ✅ | ✅ | ✅ | ✅ | ✅ |

### 9.4 Block

| Champ | Flutter | Bobodo | Supabase | Kamatera | Renderer |
|-------|---------|--------|----------|----------|----------|
| id | ✅ | ✅ | ✅ | ✅ | ✅ |
| type | ✅ | ✅ | ✅ | ✅ | ✅ |
| content | ✅ | ✅ | ✅ | ✅ | ✅ |
| order | ✅ | ✅ | ✅ | ✅ | ✅ |
| visible | ✅ | ❌ | ✅ | ✅ | ✅ |
| animation | ✅ | ❌ | ✅ | ✅ | ❌ |
| position | ✅ | ❌ | ✅ | ✅ | ❌ |
| style | ✅ | ✅ | ✅ | ✅ | ✅ |

### 9.5 Narration

| Champ | Flutter | Bobodo | Supabase | Kamatera | Renderer |
|-------|---------|--------|----------|----------|----------|
| mode | ✅ | ✅ | ✅ | ✅ | ✅ |
| audio_url | ✅ | ❌ | ✅ | ✅ | ✅ |
| duration_ms | ✅ | ❌ | ✅ | ✅ | ✅ |
| language | ✅ | ❌ | ✅ | ✅ | ❌ |
| voice | ✅ | ❌ | ✅ | ✅ | ❌ |

### 9.6 RenderJob

| Champ | Flutter | Bobodo | Supabase | Kamatera | Renderer |
|-------|---------|--------|----------|----------|----------|
| id | ✅ | ❌ | ✅ | ✅ | ✅ |
| project_id | ✅ | ❌ | ✅ | ✅ | ✅ |
| status | ✅ | ❌ | ✅ | ✅ | ✅ |
| video_url | ✅ | ❌ | ✅ | ✅ | ✅ |
| duration_ms | ✅ | ❌ | ✅ | ✅ | ✅ |
| error_message | ✅ | ❌ | ✅ | ✅ | ❌ |
| progress | ✅ | ❌ | ✅ | ✅ | ❌ |
| created_at | ✅ | ❌ | ✅ | ✅ | ❌ |
| completed_at | ✅ | ❌ | ✅ | ✅ | ❌ |

### 9.7 ExportSettings

| Champ | Flutter | Bobodo | Supabase | Kamatera | Renderer |
|-------|---------|--------|----------|----------|----------|
| format | ✅ | ❌ | ✅ | ✅ | ✅ |
| resolution | ✅ | ❌ | ✅ | ✅ | ✅ |
| frame_rate | ✅ | ❌ | ✅ | ✅ | ✅ |
| video_codec | ✅ | ❌ | ✅ | ✅ | ✅ |
| audio_codec | ✅ | ❌ | ✅ | ✅ | ✅ |

---

## PARTIE 10 – CONTRÔLE DE NON-DUPLICATION

### 10.1 Champs redondants identifiés

| Champ | Duplication | Action |
|-------|-------------|--------|
| subject | Storyboard.subject et WhiteboardProject.subject | ✅ Conservé (utile pour filtrage) |
| renderer | Storyboard.renderer et WhiteboardProject.renderer_id | ✅ Conservé (utile pour filtrage) |
| theme | Storyboard.theme et WhiteboardProject.theme_id | ✅ Conservé (utile pour filtrage) |
| narration_mode | Storyboard.narration_mode et WhiteboardProject.narration_mode | ✅ Conservé (utile pour filtrage) |

### 10.2 Structures redondantes identifiées

| Structure | Duplication | Action |
|-----------|-------------|--------|
| Aucune | - | - |

### 10.3 Métadonnées inutiles identifiées

| Métadonnée | Utilité | Action |
|------------|---------|--------|
| Scene.transition | Non utilisé V1 | ✅ Conservé (pour V2) |
| Block.animation | Non utilisé V1 | ✅ Conservé (pour V2) |
- Block.position | Non utilisé V1 | ✅ Conservé (pour V2) |
- Narration.language | Non utilisé V1 | ✅ Conservé (pour V2) |
- Narration.voice | Non utilisé V1 | ✅ Conservé (pour V2) |

### 10.4 Conclusion

Aucune suppression nécessaire. Tous les champs sont justifiés :
- Duplication sujet/renderer/theme/narration_mode : Utile pour filtrage au niveau projet
- Métadonnées non utilisées V1 : Conservées pour évolution future

---

## CONCLUSION

Ce contrat de données définitif garantit que :

**Flutter → Bobodo → Supabase → Kamatera → Renderer**

parlent exactement le même langage de données.

**Aucune conversion complexe.**
**Aucune duplication inutile.**
**Aucune ambiguïté.**

Ce document est la référence officielle pour toutes les phases de développement du Smart Whiteboard IA V1.

---

**Fin du document**

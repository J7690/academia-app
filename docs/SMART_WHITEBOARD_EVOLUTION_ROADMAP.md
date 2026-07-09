# SMART WHITEBOARD EVOLUTION ROADMAP

**Version** : 1.0  
**Date** : 23 Juin 2026  
**Phase** : UX.2 – Evolution Roadmap Smart Whiteboard  
**Mode** : ANALYSE  
**Objectif** : Définir l'évolution du Smart Whiteboard de V1 à V5

---

## CRITÈRE DE RÉUSSITE

Le document doit permettre de construire V1 aujourd'hui sans bloquer V2, V3, V4 ou V5 demain.

---

## PARTIE 1 – VERSIONS V1 À V5

### 1.1 V1 – MVP (Minimum Viable Product)

**Fonctionnalités** :
- Génération de storyboard depuis sujet/plan/texte
- Rendu PNG (Pillow)
- Rendu LaTeX (Matplotlib, optionnel)
- Assemblage PNG → MP4 (FFmpeg)
- Animation fade_in uniquement
- Thèmes scientific et notebook
- Blocs : title, paragraph, formula, definition, exercise, correction
- Narration : lecture de script (enregistrement utilisateur)
- Export MP4 (1080x1920)
- Publication TikTok, Facebook, Instagram Reels, YouTube Shorts

**Impact utilisateur** :
- Création de vidéo pédagogique en 7-8 minutes
- Courbe d'apprentissage faible
- Résultat visuel professionnel

**Complexité technique** :
- Faible
- Dépendances : Pillow, Matplotlib (optionnel), FFmpeg
- Worker Python simple
- Pas de synchronisation audio
- Pas d'animations complexes

**Dépendances** :
- Pillow (génération PNG)
- Matplotlib (rendu LaTeX, optionnel)
- FFmpeg (assemblage MP4)
- Python 3.11+
- Supabase (stockage, RPCs)

### 1.2 V2 – Narration Avancée

**Fonctionnalités** :
- Toutes les fonctionnalités V1
- Voix IA (TTS) avec sélection de voix
- Synchronisation mot à mot (timestamps)
- Script généré par Bobodo
- Option hybride (utilisateur + IA)
- Captions automatiques
- Musique de fond (bibliothèque)

**Impact utilisateur** :
- Création de vidéo pédagogique en 5-6 minutes
- Plus de flexibilité dans la narration
- Meilleure qualité audio

**Complexité technique** :
- Moyenne
- Dépendances : TTS (OpenRouter/ElevenLabs), timestamps
- Worker Python avec synchronisation audio
- Nécessité métadonnées timestamps dans Storyboard

**Dépendances** :
- TTS API (OpenRouter/ElevenLabs)
- Timestamps (mot à mot)
- Metadata extended dans Storyboard

### 1.3 V3 – Animations Avancées

**Fonctionnalités** :
- Toutes les fonctionnalités V2
- Animations avancées (slide_in, zoom_in, rotate, bounce, elastic)
- Écriture manuscrite animée
- Surlignage automatique
- Zoom intelligent
- Thèmes personnalisés
- Blocs personnalisés

**Impact utilisateur** :
- Création de vidéo pédagogique en 5-6 minutes
- Résultat visuel plus dynamique
- Plus d'options de personnalisation

**Complexité technique** :
- Élevée
- Dépendances : SVG, vector tracing, handwritten fonts
- Worker Python avec animations complexes
- Nécessité métadonnées animations dans Storyboard

**Dépendances** :
- SVG (écriture manuscrite)
- Vector tracing (tracé vectoriel)
- Handwritten fonts (fonts manuscrites)
- Metadata extended dans Storyboard

### 1.4 V4 – Intelligence Contextuelle

**Fonctionnalités** :
- Toutes les fonctionnalités V3
- Analyse sémantique automatique
- Détection automatique des mots clés
- Détection automatique des définitions
- Détection automatique des formules importantes
- Suggestions d'animations basées sur le contenu
- Suggestions de zoom basées sur le contenu
- Suggestions de surlignage basées sur le contenu

**Impact utilisateur** :
- Création de vidéo pédagogique en 4-5 minutes
- Suggestions automatiques
- Moins de corrections manuelles

**Complexité technique** :
- Très élevée
- Dépendances : NLP, analyse sémantique, LLM avancé
- Worker Python avec IA contextuelle
- Nécessité métadonnées sémantiques dans Storyboard

**Dépendances** :
- NLP (analyse sémantique)
- LLM avancé (suggestions)
- Metadata extended dans Storyboard

### 1.5 V5 – Collaboration et Analytics

**Fonctionnalités** :
- Toutes les fonctionnalités V4
- Collaboration en temps réel (multi-utilisateurs)
- Commentaires et suggestions
- Versioning (historique des modifications)
- Analytics (vues, engagement, retention)
- A/B testing (versions alternatives)
- Intégration LMS (Moodle, Canvas)
- Export multi-résolution (240p, 360p, 480p, 720p, 1080p)
- Export HLS (adaptive bitrate)

**Impact utilisateur** :
- Création collaborative de vidéo pédagogique
- Analytics pour optimiser le contenu
- Intégration avec les plateformes LMS

**Complexité technique** :
- Très élevée
- Dépendances : WebSocket, analytics, LMS API
- Worker Python avec collaboration
- Nécessité métadonnées collaboration dans Storyboard

**Dépendances** :
- WebSocket (collaboration)
- Analytics (vues, engagement)
- LMS API (Moodle, Canvas)
- Metadata extended dans Storyboard

---

## PARTIE 2 – DÉTAILS PAR VERSION

### 2.1 V1 – MVP

| Aspect | Détail |
|--------|--------|
| **Fonctionnalités** | Génération storyboard, rendu PNG, assemblage MP4, fade_in, 2 thèmes, 6 blocs, narration script, export MP4, publication multi-plateforme |
| **Impact utilisateur** | 7-8 minutes pour créer une vidéo, courbe d'apprentissage faible, résultat professionnel |
| **Complexité technique** | Faible, Pillow + Matplotlib + FFmpeg, worker simple |
| **Dépendances** | Pillow, Matplotlib (optionnel), FFmpeg, Python 3.11+, Supabase |

### 2.2 V2 – Narration Avancée

| Aspect | Détail |
|--------|--------|
| **Fonctionnalités** | V1 + TTS, synchronisation mot à mot, script Bobodo, option hybride, captions, musique de fond |
| **Impact utilisateur** | 5-6 minutes pour créer une vidéo, plus de flexibilité, meilleure qualité audio |
| **Complexité technique** | Moyenne, TTS API, timestamps, worker avec synchronisation |
| **Dépendances** | TTS API (OpenRouter/ElevenLabs), timestamps, metadata extended |

### 2.3 V3 – Animations Avancées

| Aspect | Détail |
|--------|--------|
| **Fonctionnalités** | V2 + animations avancées, écriture manuscrite, surlignage, zoom, thèmes personnalisés, blocs personnalisés |
| **Impact utilisateur** | 5-6 minutes pour créer une vidéo, résultat plus dynamique, plus de personnalisation |
| **Complexité technique** | Élevée, SVG, vector tracing, handwritten fonts, worker avec animations complexes |
| **Dépendances** | SVG, vector tracing, handwritten fonts, metadata extended |

### 2.4 V4 – Intelligence Contextuelle

| Aspect | Détail |
|--------|--------|
| **Fonctionnalités** | V3 + analyse sémantique, détection automatique, suggestions d'animations/zoom/surlignage |
| **Impact utilisateur** | 4-5 minutes pour créer une vidéo, suggestions automatiques, moins de corrections |
| **Complexité technique** | Très élevée, NLP, analyse sémantique, LLM avancé, worker avec IA contextuelle |
| **Dépendances** | NLP, LLM avancé, metadata extended |

### 2.5 V5 – Collaboration et Analytics

| Aspect | Détail |
|--------|--------|
| **Fonctionnalités** | V4 + collaboration temps réel, commentaires, versioning, analytics, A/B testing, intégration LMS, export multi-résolution, export HLS |
| **Impact utilisateur** | Création collaborative, analytics pour optimisation, intégration LMS |
| **Complexité technique** | Très élevée, WebSocket, analytics, LMS API, worker avec collaboration |
| **Dépendances** | WebSocket, analytics, LMS API, metadata extended |

---

## PARTIE 3 – ÉCRITURE MANUSCRITE ANIMÉE

### 3.1 Description

L'écriture manuscrite animée simule le tracé d'un texte à la main, comme si un professeur écrivait au tableau en temps réel.

### 3.2 Options de génération

**Option 1 : SVG**
- Avantages : Vectoriel, scalable, léger
- Inconvénients : Complexité élevée, nécessité bibliothèque SVG
- Implémentation : `<path>` avec `stroke-dasharray` et `stroke-dashoffset`

**Option 2 : Tracé vectoriel**
- Avantages : Précision, contrôle total
- Inconvénients : Complexité très élevée, nécessité algorithme de tracé
- Implémentation : Bézier curves, interpolation

**Option 3 : Fonts manuscrites**
- Avantages : Simple, rapide, légère
- Inconvénients : Moins réaliste, dépendance à la font
- Implémentation : Font manuscrite + animation d'opacité

**Option 4 : Combinaison**
- Avantages : Meilleur compromis réalisme/complexité
- Inconvénients : Complexité moyenne
- Implémentation : Font manuscrite + SVG pour les lettres complexes

### 3.3 Recommandation

**Option recommandée** : Option 3 (Fonts manuscrites)

**Justification** :
- Plus simple à implémenter
- Performance meilleure
- Résultat visuel acceptable
- Compatible avec Pillow (text rendering)

**Implémentation V3** :
- Font manuscrite (ex: "Comic Sans MS", "Patrick Hand")
- Animation d'opacité (fade_in lettre par lettre)
- Alternative : SVG pour les lettres complexes (option V4)

### 3.4 Comment sera-t-elle générée ?

**Processus** :
1. Bobodo détecte les blocs qui nécessitent une écriture manuscrite (ex: definition, exercise)
2. Bobodo ajoute un metadata `handwriting: true` au bloc
3. Le Renderer V3 utilise une font manuscrite pour ces blocs
4. Le Renderer V3 anime l'opacité lettre par lettre (fade_in progressif)
5. Alternative V4 : Le Renderer V4 génère un SVG pour chaque lettre et anime le tracé

---

## PARTIE 4 – SURLIGNAGE AUTOMATIQUE

### 4.1 Description

Le surlignage automatique met en évidence les mots importants, les définitions et les formules importantes.

### 4.2 Comment Bobodo indique-t-il ?

**Mot important** :
- Bobodo analyse le texte et détecte les mots clés (ex: "photosynthèse", "chlorophylle")
- Bobodo ajoute un metadata `highlight: true` et `highlight_type: "important"` au mot
- Bobodo ajoute un metadata `highlight_color: "yellow"` au mot

**Définition** :
- Bobodo détecte les blocs de type `definition`
- Bobodo ajoute un metadata `highlight: true` et `highlight_type: "definition"` au bloc
- Bobodo ajoute un metadata `highlight_color: "blue"` au bloc

**Formule importante** :
- Bobodo détecte les blocs de type `formula` qui sont complexes
- Bobodo ajoute un metadata `highlight: true` et `highlight_type: "formula"` au bloc
- Bobodo ajoute un metadata `highlight_color: "green"` au bloc

### 4.3 Implémentation V3

**Processus** :
1. Bobodo analyse le storyboard et ajoute les métadonnées de surlignage
2. Le Renderer V3 lit les métadonnées `highlight`, `highlight_type`, `highlight_color`
3. Le Renderer V3 applique un surlignage (fond coloré) aux mots/blocs concernés
4. Le Renderer V3 anime le surlignage (fade_in)

### 4.4 Métadonnées requises

```json
{
  "type": "paragraph",
  "content": "La photosynthèse est le processus par lequel les plantes convertissent la lumière en énergie.",
  "metadata": {
    "highlight": true,
    "highlight_type": "important",
    "highlight_color": "yellow",
    "highlight_words": ["photosynthèse", "plantes", "énergie"]
  }
}
```

---

## PARTIE 5 – ZOOM INTELLIGENT

### 5.1 Description

Le zoom intelligent zoome automatiquement sur les parties importantes de la vidéo (ex: formule, définition, mot clé).

### 5.2 Comment le Renderer sait-il ?

**Où zoomer** :
- Bobodo détecte les blocs qui nécessitent un zoom (ex: formula, definition, important word)
- Bobodo ajoute un metadata `zoom: true` et `zoom_target: "block_id"` au bloc
- Bobodo ajoute un metadata `zoom_level: 1.5` au bloc (1.5x = 50% de zoom)

**Quand zoomer** :
- Bobodo ajoute un metadata `zoom_start_time: 5.0` au bloc (zoom commence à 5s)
- Bobodo ajoute un metadata `zoom_duration: 2.0` au bloc (zoom dure 2s)
- Bobodo ajoute un metadata `zoom_end_time: 7.0` au bloc (zoom se termine à 7s)

**Combien zoomer** :
- Bobodo ajoute un metadata `zoom_level: 1.5` au bloc (1.5x = 50% de zoom)
- Bobodo ajoute un metadata `zoom_max: 2.0` au bloc (2.0x = 100% de zoom maximum)

### 5.3 Implémentation V3

**Processus** :
1. Bobodo analyse le storyboard et ajoute les métadonnées de zoom
2. Le Renderer V3 lit les métadonnées `zoom`, `zoom_target`, `zoom_level`, `zoom_start_time`, `zoom_duration`, `zoom_end_time`
3. Le Renderer V3 applique un zoom progressif sur le bloc concerné
4. Le Renderer V3 utilise FFmpeg `scale` et `pan` filters pour le zoom

### 5.4 Métadonnées requises

```json
{
  "type": "formula",
  "content": "6CO2 + 6H2O → C6H12O6 + 6O2",
  "metadata": {
    "zoom": true,
    "zoom_target": "block_001",
    "zoom_level": 1.5,
    "zoom_start_time": 5.0,
    "zoom_duration": 2.0,
    "zoom_end_time": 7.0
  }
}
```

---

## PARTIE 6 – SYNCHRONISATION AUDIO

### 6.1 Description

La synchronisation audio relie la narration aux mots, aux blocs et aux animations.

### 6.2 Comment relier ?

**Narration → Mots** :
- TTS génère l'audio et les timestamps mot à mot
- Bobodo stocke les timestamps dans le storyboard
- Exemple : "photosynthèse" → 0.5s-1.2s

**Mots → Blocs** :
- Bobodo associe chaque mot à un bloc
- Bobodo ajoute un metadata `word_timestamps` au bloc
- Exemple : block_001 → [{"word": "photosynthèse", "start": 0.5, "end": 1.2}]

**Blocs → Animations** :
- Le Renderer lit les timestamps et déclenche les animations
- Exemple : block_001 fade_in commence à 0.5s

### 6.3 Implémentation V2

**Processus** :
1. Bobodo génère le script
2. TTS génère l'audio et les timestamps mot à mot
3. Bobodo associe les mots aux blocs
4. Bobodo ajoute les métadonnées `word_timestamps` aux blocs
5. Le Renderer V2 lit les métadonnées et synchronise les animations

### 6.4 Métadonnées requises

```json
{
  "type": "paragraph",
  "content": "La photosynthèse est le processus par lequel les plantes convertissent la lumière en énergie.",
  "metadata": {
    "word_timestamps": [
      {"word": "La", "start": 0.0, "end": 0.2},
      {"word": "photosynthèse", "start": 0.2, "end": 0.8},
      {"word": "est", "start": 0.8, "end": 1.0},
      {"word": "le", "start": 1.0, "end": 1.2},
      {"word": "processus", "start": 1.2, "end": 1.8},
      {"word": "par", "start": 1.8, "end": 2.0},
      {"word": "lequel", "start": 2.0, "end": 2.4},
      {"word": "les", "start": 2.4, "end": 2.6},
      {"word": "plantes", "start": 2.6, "end": 3.2},
      {"word": "convertissent", "start": 3.2, "end": 4.0},
      {"word": "la", "start": 4.0, "end": 4.2},
      {"word": "lumière", "start": 4.2, "end": 4.8},
      {"word": "en", "start": 4.8, "end": 5.0},
      {"word": "énergie", "start": 5.0, "end": 5.6}
    ]
  }
}
```

---

## PARTIE 7 – CHOIX ARCHITECTURAUX V1

### 7.1 Choix à prendre aujourd'hui

**Choix 1 : Metadata extensibles dans Storyboard**

**Décision** : Ajouter un champ `metadata` (JSONB) à chaque bloc dès V1

**Justification** :
- Permet d'ajouter des métadonnées futures sans changer le schéma
- Compatible avec V2 (timestamps), V3 (animations, zoom, surlignage), V4 (sémantique), V5 (collaboration)
- Coût minimal (champ JSONB vide en V1)

**Implémentation** :
```json
{
  "type": "paragraph",
  "content": "La photosynthèse est le processus par lequel les plantes convertissent la lumière en énergie.",
  "metadata": {}
}
```

**Choix 2 : Animation system extensibles**

**Décision** : Ajouter un champ `animation` (objet) à chaque bloc dès V1

**Justification** :
- Permet d'ajouter des animations futures sans changer le schéma
- Compatible avec V1 (fade_in), V2 (fade_in + timing), V3 (animations avancées)
- Coût minimal (champ animation simple en V1)

**Implémentation** :
```json
{
  "type": "paragraph",
  "content": "La photosynthèse est le processus par lequel les plantes convertissent la lumière en énergie.",
  "animation": {
    "type": "fade_in",
    "duration": 0.5,
    "delay": 0.0
  }
}
```

**Choix 3 : Theme system extensibles**

**Décision** : Ajouter un champ `theme` (objet) au storyboard dès V1

**Justification** :
- Permet d'ajouter des thèmes futurs sans changer le schéma
- Compatible avec V1 (scientific, notebook), V3 (thèmes personnalisés)
- Coût minimal (champ theme simple en V1)

**Implémentation** :
```json
{
  "theme": {
    "name": "scientific",
    "background": "#0a192f",
    "text_color": "#ffffff",
    "accent_color": "#69f0ae"
  }
}
```

**Choix 4 : Audio system extensibles**

**Décision** : Ajouter un champ `audio` (objet) au storyboard dès V1

**Justification** :
- Permet d'ajouter de l'audio futur sans changer le schéma
- Compatible avec V1 (script), V2 (TTS, timestamps), V3 (musique de fond)
- Coût minimal (champ audio simple en V1)

**Implémentation** :
```json
{
  "audio": {
    "type": "user_recording",
    "script": "La photosynthèse est le processus par lequel les plantes convertissent la lumière en énergie.",
    "timestamps": []
  }
}
```

**Choix 5 : Block ID system**

**Décision** : Ajouter un champ `id` (UUID) à chaque bloc dès V1

**Justification** :
- Permet de référencer les blocs dans les métadonnées futures
- Compatible avec V3 (zoom target), V4 (sémantique), V5 (collaboration)
- Coût minimal (champ id UUID en V1)

**Implémentation** :
```json
{
  "id": "block_001",
  "type": "paragraph",
  "content": "La photosynthèse est le processus par lequel les plantes convertissent la lumière en énergie."
}
```

### 7.2 Choix à éviter

**Choix à éviter 1 : Hardcoder les animations**

**Pourquoi** : Bloque l'ajout d'animations futures

**Alternative** : Utiliser un champ `animation` extensibles

**Choix à éviter 2 : Hardcoder les thèmes**

**Pourquoi** : Bloque l'ajout de thèmes futurs

**Alternative** : Utiliser un champ `theme` extensibles

**Choix à éviter 3 : Hardcoder les types de blocs**

**Pourquoi** : Bloque l'ajout de blocs futurs

**Alternative** : Utiliser un champ `type` extensibles + metadata

**Choix à éviter 4 : Ignorer les métadonnées**

**Pourquoi** : Force une réécriture complète en V2-V5

**Alternative** : Ajouter un champ `metadata` (JSONB) dès V1

---

## PARTIE 8 – MÉTADONNÉES À AJOUTER DÈS MAINTENANT

### 8.1 Métadonnées requises

**Bloc level** :
- `id` (UUID) : Identifiant unique du bloc
- `metadata` (JSONB) : Métadonnées extensibles (vide en V1)
- `animation` (objet) : Animation du bloc (fade_in en V1)
- `highlight` (booléen) : Surlignage (false en V1)
- `zoom` (booléen) : Zoom (false en V1)
- `handwriting` (booléen) : Écriture manuscrite (false en V1)

**Storyboard level** :
- `theme` (objet) : Thème (scientific ou notebook en V1)
- `audio` (objet) : Audio (script en V1)
- `metadata` (JSONB) : Métadonnées extensibles (vide en V1)

### 8.2 Exemple de Storyboard V1 avec métadonnées

```json
{
  "id": "storyboard_001",
  "title": "La photosynthèse",
  "theme": {
    "name": "scientific",
    "background": "#0a192f",
    "text_color": "#ffffff",
    "accent_color": "#69f0ae"
  },
  "audio": {
    "type": "user_recording",
    "script": "La photosynthèse est le processus par lequel les plantes convertissent la lumière en énergie.",
    "timestamps": []
  },
  "metadata": {},
  "scenes": [
    {
      "id": "scene_001",
      "duration_ms": 5000,
      "blocks": [
        {
          "id": "block_001",
          "type": "title",
          "content": "La photosynthèse",
          "animation": {
            "type": "fade_in",
            "duration": 0.5,
            "delay": 0.0
          },
          "metadata": {},
          "highlight": false,
          "zoom": false,
          "handwriting": false
        },
        {
          "id": "block_002",
          "type": "paragraph",
          "content": "La photosynthèse est le processus par lequel les plantes convertissent la lumière en énergie.",
          "animation": {
            "type": "fade_in",
            "duration": 0.5,
            "delay": 0.5
          },
          "metadata": {},
          "highlight": false,
          "zoom": false,
          "handwriting": false
        }
      ]
    }
  ]
}
```

### 8.3 Exemple de Storyboard V3 avec métadonnées

```json
{
  "id": "storyboard_001",
  "title": "La photosynthèse",
  "theme": {
    "name": "scientific",
    "background": "#0a192f",
    "text_color": "#ffffff",
    "accent_color": "#69f0ae"
  },
  "audio": {
    "type": "tts",
    "script": "La photosynthèse est le processus par lequel les plantes convertissent la lumière en énergie.",
    "timestamps": [
      {"word": "photosynthèse", "start": 0.2, "end": 0.8}
    ]
  },
  "metadata": {},
  "scenes": [
    {
      "id": "scene_001",
      "duration_ms": 5000,
      "blocks": [
        {
          "id": "block_001",
          "type": "title",
          "content": "La photosynthèse",
          "animation": {
            "type": "fade_in",
            "duration": 0.5,
            "delay": 0.0
          },
          "metadata": {},
          "highlight": false,
          "zoom": false,
          "handwriting": false
        },
        {
          "id": "block_002",
          "type": "paragraph",
          "content": "La photosynthèse est le processus par lequel les plantes convertissent la lumière en énergie.",
          "animation": {
            "type": "fade_in",
            "duration": 0.5,
            "delay": 0.5
          },
          "metadata": {
            "word_timestamps": [
              {"word": "photosynthèse", "start": 0.2, "end": 0.8}
            ]
          },
          "highlight": true,
          "highlight_type": "important",
          "highlight_color": "yellow",
          "zoom": false,
          "handwriting": false
        },
        {
          "id": "block_003",
          "type": "formula",
          "content": "6CO2 + 6H2O → C6H12O6 + 6O2",
          "animation": {
            "type": "fade_in",
            "duration": 0.5,
            "delay": 1.0
          },
          "metadata": {},
          "highlight": true,
          "highlight_type": "formula",
          "highlight_color": "green",
          "zoom": true,
          "zoom_level": 1.5,
          "zoom_start_time": 1.0,
          "zoom_duration": 2.0,
          "zoom_end_time": 3.0,
          "handwriting": false
        }
      ]
    }
  ]
}
```

---

## PARTIE 9 – CONCLUSION

### 9.1 Résumé

**V1** : MVP (fade_in, 2 thèmes, 6 blocs, narration script)  
**V2** : Narration avancée (TTS, synchronisation mot à mot, captions)  
**V3** : Animations avancées (écriture manuscrite, surlignage, zoom)  
**V4** : Intelligence contextuelle (analyse sémantique, suggestions)  
**V5** : Collaboration et analytics (temps réel, commentaires, versioning)

**Écriture manuscrite** : Fonts manuscrites + animation d'opacité (recommandé)  
**Surlignage automatique** : Bobodo détecte et ajoute métadonnées `highlight`  
**Zoom intelligent** : Bobodo détecte et ajoute métadonnées `zoom`  
**Synchronisation audio** : TTS + timestamps + association mots-blocs

**Choix architecturaux V1** :
- Metadata extensibles (JSONB)
- Animation system extensibles
- Theme system extensibles
- Audio system extensibles
- Block ID system

**Métadonnées à ajouter dès maintenant** :
- `id` (UUID) pour chaque bloc
- `metadata` (JSONB) pour chaque bloc
- `animation` (objet) pour chaque bloc
- `highlight` (booléen) pour chaque bloc
- `zoom` (booléen) pour chaque bloc
- `handwriting` (booléen) pour chaque bloc
- `theme` (objet) pour le storyboard
- `audio` (objet) pour le storyboard
- `metadata` (JSONB) pour le storyboard

### 9.2 Décision

**PHASE UX.2 VALIDÉE** ✅

**Justification** :
- L'évolution de V1 à V5 est clairement définie
- Les choix architecturaux V1 évitent une réécriture complète en V3-V5
- Les métadonnées à ajouter dès maintenant sont identifiées
- L'écriture manuscrite, le surlignage, le zoom et la synchronisation audio sont clairement décrits
- Le document permet de construire V1 aujourd'hui sans bloquer V2, V3, V4 ou V5 demain

---

**Fin du document**

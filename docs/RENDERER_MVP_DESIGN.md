# RENDERER MVP DESIGN

**Version** : 1.0  
**Date** : 23 Juin 2026  
**Phase** : C.2 – Renderer MVP Design  
**Mode** : LECTURE SEULE  
**Objectif** : Définir précisément le plus petit Renderer Smart Whiteboard V1 viable

---

## DIRECTIVE TECHNIQUE PERMANENTE

Ce document est une spécification architecturale. Aucune ligne de code. Uniquement architecture.

---

## PARTIE 1 – PIPELINE COMPLET

### 1.1 Chemin le plus court

```
Storyboard JSON (Supabase)
↓
Worker Kamatera (poll whiteboard_renders)
↓
Parse JSON (Python)
↓
Pour chaque scène :
  - Créer canvas Pillow (1080x1920)
  - Pour chaque bloc :
    - TitleBlock → Texte Pillow
    - ParagraphBlock → Texte Pillow
    - FormulaBlock → Matplotlib (LaTeX) → PNG
    - DefinitionBlock → Texte Pillow
    - ExerciseBlock → Texte Pillow
    - CorrectionBlock → Texte Pillow
  - Sauvegarder scène PNG
↓
Assemblage PNGs → MP4 (FFmpeg)
  - ffmpeg -f image2 -framerate 30 -i scene_%d.png -c:v libx264 -pix_fmt yuv420p output.mp4
↓
Upload MP4 → Supabase Storage (whiteboard-renders)
↓
Update whiteboard_renders (status=done, video_url)
```

### 1.2 Étapes détaillées

**Étape 1 : Polling**
- Worker poll whiteboard_renders (status=queued)
- Marque job comme processing
- Récupère storyboard_json

**Étape 2 : Parse JSON**
- Parse storyboard_json (JSONB)
- Extrait scenes (liste)
- Extrait blocks (liste par scène)

**Étape 3 : Génération PNGs**
- Pour chaque scène :
  - Créer canvas Pillow (1080x1920)
  - Appliquer thème (scientific ou notebook)
  - Pour chaque bloc :
    - Rendre bloc selon type
    - Appliquer animation (fade_in)
  - Sauvegarder scène PNG (scene_001.png, scene_002.png, ...)

**Étape 4 : Assemblage MP4**
- FFmpeg assemble PNGs en MP4
- 30 fps
- H.264
- yuv420p

**Étape 5 : Upload**
- Upload MP4 vers Supabase Storage (whiteboard-renders)
- Update whiteboard_renders (status=done, video_url, duration_ms)

---

## PARTIE 2 – COMPOSANTS EXACTS

### 2.1 Pillow

**Rôle** : Génération d'images PNG

**Fonctions** :
- Création canvas (1080x1920)
- Rendu texte (title, paragraph, definition, exercise, correction)
- Application thème (scientific, notebook)
- Application animation (fade_in)
- Sauvegarde PNG

**Dépendances** :
- Pillow (Python Imaging Library)

**Configuration** :
- Résolution : 1080x1920 (vertical TikTok)
- DPI : 72
- Format : PNG

### 2.2 Matplotlib

**Rôle** : Rendu de formules LaTeX

**Fonctions** :
- Parse LaTeX
- Rendu formule en PNG
- Intégration dans canvas Pillow

**Dépendances** :
- Matplotlib
- LaTeX (optionnel, fallback sur MathText)

**Configuration** :
- Résolution : 1080x1920
- DPI : 72
- Format : PNG

**Note** : Matplotlib est optionnel pour V1. Si non disponible, les formules sont affichées comme texte brut.

### 2.3 FFmpeg

**Rôle** : Assemblage PNGs en MP4

**Fonctions** :
- Lecture PNGs séquentiels
- Encodage H.264
- Génération MP4

**Dépendances** :
- FFmpeg (installé sur Kamatera)

**Configuration** :
- Input : image2 (PNGs)
- Framerate : 30 fps
- Codec : libx264
- Pixel format : yuv420p
- Preset : medium
- CRF : 23

**Commande** :
```bash
ffmpeg -y -f image2 -framerate 30 -i scene_%d.png -c:v libx264 -pix_fmt yuv420p -r 30 -preset medium -crf 23 output.mp4
```

### 2.4 Worker

**Rôle** : Orchestration du pipeline

**Fonctions** :
- Polling whiteboard_renders
- Parse storyboard_json
- Orchestration génération PNGs
- Orchestration assemblage MP4
- Upload Supabase Storage
- Update whiteboard_renders

**Dépendances** :
- Python 3.11+
- Pillow
- Matplotlib (optionnel)
- httpx
- python-dotenv

**Configuration** :
- WORKER_LOOP=1 (boucle infinie)
- WORKER_INTERVAL_SECONDS=2 (intervalle polling)
- WORKER_MAX_JOBS=1 (jobs max par itération)

---

## PARTIE 3 – BLOCS V1 SUPPORTÉS

### 3.1 Blocs supportés

| Bloc | Supporté | Rendu | Notes |
|------|----------|-------|-------|
| TitleBlock | ✅ OUI | Texte Pillow | Gras, taille 32px, centré |
| ParagraphBlock | ✅ OUI | Texte Pillow | Normal, taille 24px, justifié |
| FormulaBlock | ⚠️ PARTIEL | Matplotlib ou texte brut | Si Matplotlib : rendu LaTeX, sinon texte brut |
| DefinitionBlock | ✅ OUI | Texte Pillow | Italique, taille 20px, justifié |
| ExerciseBlock | ✅ OUI | Texte Pillow | Normal, taille 24px, justifié |
| CorrectionBlock | ✅ OUI | Texte Pillow | Vert, taille 20px, justifié |

### 3.2 Blocs non supportés

Aucun bloc n'est explicitement non supporté en V1. Tous les blocs sont supportés, avec une limitation pour FormulaBlock (texte brut si Matplotlib non disponible).

### 3.3 Rendu détaillé par bloc

**TitleBlock** :
- Police : Arial Black
- Taille : 32px
- Couleur : Blanc (thème scientific), Noir (thème notebook)
- Alignement : Centré
- Animation : fade_in (0.5s)

**ParagraphBlock** :
- Police : Arial
- Taille : 24px
- Couleur : Blanc (thème scientific), Noir (thème notebook)
- Alignement : Justifié
- Animation : fade_in (0.5s)

**FormulaBlock** :
- Police : Times New Roman (si Matplotlib), Arial (texte brut)
- Taille : 28px (si Matplotlib), 24px (texte brut)
- Couleur : Blanc (thème scientific), Noir (thème notebook)
- Alignement : Centré
- Animation : fade_in (0.5s)

**DefinitionBlock** :
- Police : Arial
- Taille : 20px
- Couleur : Gris clair (thème scientific), Gris foncé (thème notebook)
- Alignement : Justifié
- Animation : fade_in (0.5s)

**ExerciseBlock** :
- Police : Arial
- Taille : 24px
- Couleur : Blanc (thème scientific), Noir (thème notebook)
- Alignement : Justifié
- Animation : fade_in (0.5s)

**CorrectionBlock** :
- Police : Arial
- Taille : 20px
- Couleur : Vert clair (thème scientific), Vert foncé (thème notebook)
- Alignement : Justifié
- Animation : fade_in (0.5s)

---

## PARTIE 4 – ANIMATIONS V1

### 4.1 Animation unique

**fade_in uniquement**

### 4.2 Spécification fade_in

**Durée** : 0.5s par bloc

**Implémentation** :
- Bloc invisible (alpha=0) au début
- Alpha progressif de 0 à 255 sur 0.5s
- Bloc visible (alpha=255) à la fin

**Application** :
- Chaque bloc a son propre fade_in
- Les blocs sont animés séquentiellement (pas simultanément)
- Le premier bloc commence à t=0s
- Le deuxième bloc commence à t=0.5s
- Le troisième bloc commence à t=1.0s
- ...

**Exemple** :
- Scène avec 3 blocs
- Bloc 1 : fade_in 0.0s → 0.5s
- Bloc 2 : fade_in 0.5s → 1.0s
- Bloc 3 : fade_in 1.0s → 1.5s
- Durée totale de la scène : 1.5s + 2s (pause) = 3.5s

### 4.3 Animations non supportées en V1

- slide_in
- zoom_in
- rotate
- bounce
- elastic
- any custom animation

---

## PARTIE 5 – THÈMES V1

### 5.1 Thèmes supportés

**scientific**  
**notebook**

### 5.2 Thème scientific

**Fond** : Bleu nuit (#0a192f)

**Couleurs** :
- Titre : Blanc (#ffffff)
- Paragraphe : Blanc (#ffffff)
- Formule : Blanc (#ffffff)
- Définition : Gris clair (#b0bec5)
- Exercice : Blanc (#ffffff)
- Correction : Vert clair (#69f0ae)

**Police** : Arial

**Style** : Moderne, minimaliste

### 5.3 Thème notebook

**Fond** : Blanc (#ffffff)

**Couleurs** :
- Titre : Noir (#000000)
- Paragraphe : Noir (#000000)
- Formule : Noir (#000000)
- Définition : Gris foncé (#424242)
- Exercice : Noir (#000000)
- Correction : Vert foncé (#2e7d32)

**Police** : Arial

**Style** : Classique, papier

### 5.4 Thèmes non supportés en V1

- dark
- light
- colorful
- any custom theme

---

## PARTIE 6 – TEMPS DE RENDU ESTIMÉ

### 6.1 Scénario typique

**Storyboard** :
- 3 scènes
- 3 blocs par scène
- Durée totale : ~10s

### 6.2 Temps de rendu estimé

| Étape | Durée |
|-------|-------|
| Polling + Parse JSON | 0.5s |
| Génération PNGs (9 blocs) | 5s |
| Assemblage MP4 (FFmpeg) | 3s |
| Upload MP4 | 2s |
| Update whiteboard_renders | 0.5s |
| **Total** | **11s** |

### 6.3 Temps de rendu par complexité

**Simple (1 scène, 2 blocs)** : 30s  
**Moyen (3 scènes, 3 blocs)** : 60s  
**Complexe (5 scènes, 5 blocs)** : 180s

### 6.4 Facteurs d'influence

- Nombre de scènes
- Nombre de blocs
- Présence de formules (Matplotlib plus lent que texte)
- Complexité des formules LaTeX
- Vitesse CPU Kamatera

---

## PARTIE 7 – CONSOMMATION CPU ET RAM

### 7.1 Consommation CPU

**Par rendu** : 1-2 cores

**Détail** :
- Parse JSON : 0.1 core
- Génération PNGs : 0.5-1 core (Pillow)
- Rendu LaTeX : 0.5-1 core (Matplotlib, si présent)
- Assemblage MP4 : 0.5-1 core (FFmpeg)
- Upload : 0.1 core

**Maximum** : 2 cores (si Matplotlib présent)

### 7.2 Consommation RAM

**Par rendu** : 500 Mo - 1 Go

**Détail** :
- Parse JSON : 10 Mo
- Génération PNGs : 200-400 Mo (Pillow)
- Rendu LaTeX : 200-400 Mo (Matplotlib, si présent)
- Assemblage MP4 : 100-200 Mo (FFmpeg)
- Upload : 10 Mo

**Maximum** : 1 Go (si Matplotlib présent)

### 7.3 Consommation disque

**Par rendu** : 50-100 Mo

**Détail** :
- PNGs : 30-60 Mo (3-5 scènes, 1080x1920)
- MP4 temporaire : 20-40 Mo

---

## PARTIE 8 – FONCTIONNALITÉS REPORTÉES EN V2

### 8.1 Fonctionnalités reportées

| Fonctionnalité | Reportée en V2 | Raison |
|----------------|----------------|--------|
| Écriture manuscrite | ✅ OUI | Complexité élevée, nécessité reconnaissance d'écriture |
| Synchronisation mot à mot | ✅ OUI | Nécessité narration audio + timestamps |
| Zoom intelligent | ✅ OUI | Nécessité analyse sémantique + animation complexe |
| Surlignage automatique | ✅ OUI | Nécessité analyse sémantique + animation complexe |
| Animation avancée | ✅ OUI | Complexité élevée, priorité fade_in pour MVP |
| Narration audio | ✅ OUI | Nécessité TTS + synchronisation |
| Thèmes personnalisés | ✅ OUI | Priorité thèmes scientific + notebook pour MVP |
| Blocs personnalisés | ✅ OUI | Priorité blocs standard pour MVP |
| Export multi-résolution | ✅ OUI | Priorité 1080p pour MVP |
| Export HLS | ✅ OUI | Priorité MP4 pour MVP |

### 8.1.1 Écriture manuscrite

**Description** : Rendu de blocs avec style écriture manuscrite

**Complexité** : Élevée  
**Raison** : Nécessité reconnaissance d'écriture + police manuscrite + animation tracé

### 8.1.2 Synchronisation mot à mot

**Description** : Synchronisation du texte avec la narration audio

**Complexité** : Élevée  
**Raison** : Nécessité TTS + timestamps mot à mot + animation mot par mot

### 8.1.3 Zoom intelligent

**Description** : Zoom automatique sur les parties importantes

**Complexité** : Élevée  
**Raison** : Nécessité analyse sémantique + animation zoom + timing

### 8.1.4 Surlignage automatique

**Description** : Surlignage automatique des mots clés

**Complexité** : Élevée  
**Raison** : Nécessité analyse sémantique + animation surlignage + timing

### 8.1.5 Animation avancée

**Description** : Animations complexes (slide_in, zoom_in, rotate, bounce, elastic)

**Complexité** : Moyenne  
**Raison** : Priorité fade_in pour MVP, animations avancées pour V2

### 8.1.6 Narration audio

**Description** : Génération audio TTS + synchronisation

**Complexité** : Élevée  
**Raison** : Nécessité TTS + timestamps + synchronisation + upload audio

### 8.1.7 Thèmes personnalisés

**Description** : Thèmes personnalisés par l'utilisateur

**Complexité** : Moyenne  
**Raison** : Priorité thèmes scientific + notebook pour MVP

### 8.1.8 Blocs personnalisés

**Description** : Blocs personnalisés par l'utilisateur

**Complexité** : Moyenne  
**Raison** : Priorité blocs standard pour MVP

### 8.1.9 Export multi-résolution

**Description** : Export en plusieurs résolutions (240p, 360p, 480p, 720p, 1080p)

**Complexité** : Moyenne  
**Raison** : Priorité 1080p pour MVP

### 8.1.10 Export HLS

**Description** : Export en HLS (adaptive bitrate)

**Complexité** : Moyenne  
**Raison** : Priorité MP4 pour MVP

---

## PARTIE 9 – ARCHITECTURE TECHNIQUE

### 9.1 Worker Python

**Fichier** : `whiteboard_render_worker.py`

**Boucle principale** :
```python
while True:
    jobs = await _fetch_queued_jobs(limit=1)
    for job in jobs:
        await _process_single_job(job)
    await asyncio.sleep(2)
```

**Process job** :
```python
async def _process_single_job(job):
    # Mark as processing
    await _mark_job_processing(job_id)
    
    # Parse storyboard_json
    storyboard = json.loads(job["storyboard_json"])
    
    # Generate PNGs
    pngs = await _generate_pngs(storyboard)
    
    # Assemble MP4
    mp4_path = await _assemble_mp4(pngs)
    
    # Upload MP4
    video_url = await _upload_mp4(mp4_path, job_id)
    
    # Update job
    await _mark_job_done(job_id, video_url)
```

### 9.2 Génération PNGs

**Fichier** : `whiteboard_png_generator.py`

**Fonction principale** :
```python
async def _generate_pngs(storyboard):
    pngs = []
    for scene in storyboard["scenes"]:
        canvas = _create_canvas(1080, 1920, theme=storyboard["theme"])
        for block in scene["blocks"]:
            rendered_block = _render_block(block, theme=storyboard["theme"])
            canvas.paste(rendered_block)
        png_path = _save_png(canvas, scene_index)
        pngs.append(png_path)
    return pngs
```

### 9.3 Rendu bloc

**Fonction** :
```python
def _render_block(block, theme):
    if block["type"] == "title":
        return _render_title(block, theme)
    elif block["type"] == "paragraph":
        return _render_paragraph(block, theme)
    elif block["type"] == "formula":
        return _render_formula(block, theme)
    elif block["type"] == "definition":
        return _render_definition(block, theme)
    elif block["type"] == "exercise":
        return _render_exercise(block, theme)
    elif block["type"] == "correction":
        return _render_correction(block, theme)
```

### 9.4 Assemblage MP4

**Fonction** :
```python
def _assemble_mp4(pngs):
    cmd = [
        "ffmpeg",
        "-y",
        "-f", "image2",
        "-framerate", "30",
        "-i", "scene_%d.png",
        "-c:v", "libx264",
        "-pix_fmt", "yuv420p",
        "-r", "30",
        "-preset", "medium",
        "-crf", "23",
        "output.mp4",
    ]
    subprocess.run(cmd)
    return "output.mp4"
```

---

## PARTIE 10 – CRITÈRE DE RÉUSSITE

### 10.1 Critère

Le document doit permettre à un développeur de construire le Renderer V1 sans ambiguïté.

### 10.2 Vérification

- ✅ Pipeline complet décrit
- ✅ Composants exacts décrits
- ✅ Blocs V1 supportés définis
- ✅ Animations V1 définies
- ✅ Thèmes V1 définis
- ✅ Temps de rendu estimé
- ✅ Consommation CPU et RAM décrite
- ✅ Fonctionnalités reportées en V2 identifiées
- ✅ Architecture technique décrite
- ✅ Aucune ligne de code
- ✅ Uniquement architecture

---

## PARTIE 11 – CONCLUSION

### 11.1 Résumé

**Pipeline** : Storyboard JSON → PNG → FFmpeg → MP4  
**Composants** : Pillow, Matplotlib (optionnel), FFmpeg, Worker  
**Blocs V1** : Tous supportés (title, paragraph, formula, definition, exercise, correction)  
**Animations V1** : fade_in uniquement  
**Thèmes V1** : scientific, notebook  
**Temps de rendu** : 30s (simple), 60s (moyen), 180s (complexe)  
**Consommation CPU** : 1-2 cores  
**Consommation RAM** : 500 Mo - 1 Go  
**Fonctionnalités V2** : Écriture manuscrite, synchronisation mot à mot, zoom intelligent, surlignage automatique, animation avancée

### 11.2 Décision

**PHASE C.2 VALIDÉE** ✅

**Justification** :
- Le document définit précisément le plus petit Renderer Smart Whiteboard V1 viable
- Le pipeline est clair et sans ambiguïté
- Les composants sont exactement définis
- Les blocs, animations et thèmes V1 sont clairement spécifiés
- Les temps de rendu et la consommation sont estimés
- Les fonctionnalités reportées en V2 sont identifiées
- Un développeur peut construire le Renderer V1 sans ambiguïté

---

**Fin du document**

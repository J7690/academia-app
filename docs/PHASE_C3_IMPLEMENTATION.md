# PHASE C.3 – RENDERER CORE IMPLEMENTATION

**Version** : 1.0  
**Date** : 23 Juin 2026  
**Phase** : C.3 – Renderer Core Implementation  
**Mode** : DÉVELOPPEMENT AUTORISÉ  
**Objectif** : Construire le cœur du Renderer V1

---

## DIRECTIVE TECHNIQUE PERMANENTE

Toute intervention Supabase, Kamatera, Docker, FFmpeg, Backend Python doit être vérifiée via les RPC Python administrateurs présents dans `.windsurf`.

---

## RÈGLE ABSOLUE

Aucun impact autorisé sur :
- Challenge Feed
- Challenge Upload
- Challenge Publish
- Bobodo existant
- TV Pro
- LiveKit

Le Smart Whiteboard reste complètement isolé.

---

## INFRASTRUCTURE EXISTANTE

### Table whiteboard_renders

**Statut** : ✅ Existe déjà

**Colonnes** : 13 colonnes (vérifié via RPC)

**Bucket** : whiteboard-renders (✅ Existe déjà)

---

## COMPOSANTS CRÉÉS

### 1. whiteboard_render_worker.py

**Fichier** : `academia_bobodo_backend/whiteboard_render_worker.py`

**Responsabilités** :
- Polling whiteboard_renders (status=queued)
- Récupération storyboard_json
- Orchestration pipeline (PNG → MP4 → Upload)
- Mise à jour statut (processing → done/failed)

**Configuration** :
- WORKER_LOOP=1 (boucle infinie)
- WORKER_INTERVAL_SECONDS=2 (intervalle polling)
- WORKER_MAX_JOBS=1 (jobs max par itération)

**Pattern** : Basé sur videoasset_worker.py

**Fonctions principales** :
- `_fetch_queued_jobs()` : Récupère les jobs en attente
- `_update_job()` : Met à jour un job
- `_mark_job_processing()` : Marque comme processing
- `_mark_job_done()` : Marque comme done
- `_mark_job_failed()` : Marque comme failed
- `_process_single_job()` : Traite un seul job
- `run_once()` : Exécute une seule itération
- `_loop()` : Boucle infinie

### 2. whiteboard_png_renderer.py

**Fichier** : `academia_bobodo_backend/whiteboard_png_renderer.py`

**Responsabilités** :
- Lecture storyboard (JSON)
- Génération PNG 1080x1920
- Support des blocs V1

**Configuration** :
- WIDTH = 1080
- HEIGHT = 1920
- DPI = 72

**Thèmes** :
- scientific (bleu nuit, couleurs claires)
- notebook (blanc, couleurs foncées)

**Blocs supportés** :
- TitleBlock (gras, centré, 32px)
- ParagraphBlock (normal, justifié, 24px)
- DefinitionBlock (italique, justifié, 20px)
- ExerciseBlock (normal, justifié, 24px)
- CorrectionBlock (vert, justifié, 20px)
- FormulaBlock (centré, 28px, fallback texte brut)

**Fonctions principales** :
- `_get_font()` : Récupère une police
- `_render_title_block()` : Rend un titre
- `_render_paragraph_block()` : Rend un paragraphe
- `_render_definition_block()` : Rend une définition
- `_render_exercise_block()` : Rend un exercice
- `_render_correction_block()` : Rend une correction
- `_render_formula_block()` : Rend une formule (fallback texte brut)
- `_render_block()` : Rend un bloc selon son type
- `render_storyboard_to_pngs()` : Génère des PNGs à partir d'un storyboard

### 3. whiteboard_ffmpeg_assembler.py

**Fichier** : `academia_bobodo_backend/whiteboard_ffmpeg_assembler.py`

**Responsabilités** :
- Assemblage PNGs → MP4
- Format 1080x1920
- 30 fps
- H.264
- AAC

**Configuration** :
- Input : image2 (PNGs)
- Framerate : 30 fps
- Codec : libx264
- Pixel format : yuv420p
- Preset : medium
- CRF : 23

**Commande FFmpeg** :
```bash
ffmpeg -y -f image2 -framerate 30 -i scene_%03d.png -c:v libx264 -pix_fmt yuv420p -r 30 -preset medium -crf 23 output.mp4
```

**Fonctions principales** :
- `assemble_pngs_to_mp4()` : Assemble des PNGs en MP4

### 4. whiteboard_upload_renderer.py

**Fichier** : `academia_bobodo_backend/whiteboard_upload_renderer.py`

**Responsabilités** :
- Upload MP4 vers Supabase Storage
- Bucket whiteboard-renders
- Génération URL publique

**Pattern** : Basé sur videoasset_worker.py

**Configuration** :
- Bucket : whiteboard-renders
- Timeout : 600s

**Fonctions principales** :
- `_storage_base()` : Base URL Storage
- `_supabase_headers()` : Headers Supabase
- `upload_mp4_to_storage()` : Upload un MP4 vers Storage

---

## DÉPENDANCES

### Python

- Pillow (génération PNG)
- httpx (requêtes HTTP)
- python-dotenv (variables d'environnement)

### Système

- FFmpeg (assemblage MP4)

### Supabase

- Table whiteboard_renders
- Bucket whiteboard-renders
- Service Role Key

---

## INTERDICTIONS

**Non développé en V1** :
- Écriture manuscrite (reporté en V3)
- Synchronisation audio (reporté en V2)
- Zoom intelligent (reporté en V3)
- Surlignage automatique (reporté en V3)
- Thèmes personnalisés (reporté en V3)
- Multi-résolution (reporté en V5)
- HLS (reporté en V5)

---

## PIPELINE COMPLET

```
Storyboard JSON (Supabase)
↓
Worker Kamatera (poll whiteboard_renders)
↓
Parse JSON
↓
Génération PNGs (Pillow)
↓
Assemblage MP4 (FFmpeg)
↓
Upload MP4 (Supabase Storage)
↓
Update whiteboard_renders (status=done)
```

---

## VALIDATION

**Critère de réussite** :
- Un Storyboard stocké dans Supabase produit réellement un MP4 valide
- Stocké dans whiteboard-renders
- Visible dans la table whiteboard_renders
- Avec statut done

---

## PROCHAINES ÉTAPES

1. Créer document PHASE_C3_VALIDATION.md
2. Valider le flux complet avec un Storyboard réel
3. Tester sur Kamatera

---

**Fin du document**

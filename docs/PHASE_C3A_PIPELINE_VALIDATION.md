# PHASE C.3A – REAL PIPELINE VALIDATION

**Version** : 1.0  
**Date** : 23 Juin 2026  
**Phase** : C.3A – Real Pipeline Validation  
**Mode** : EXÉCUTION  
**Objectif** : Prouver que le Renderer V1 fonctionne réellement de bout en bout

---

## DIRECTIVE TECHNIQUE PERMANENTE

Toutes les vérifications Kamatera, Supabase et Storage doivent continuer à utiliser les RPC Python administrateurs présents dans `.windsurf`.

---

## ÉTAPE 1 – DÉPLOIEMENT SUR KAMATERA

### 1.1 Composants à déployer

**Fichiers** :
- `whiteboard_render_worker.py`
- `whiteboard_png_renderer.py`
- `whiteboard_ffmpeg_assembler.py`
- `whiteboard_upload_renderer.py`

**Emplacement** : `academia_bobodo_backend/`

### 1.2 Méthode de déploiement

**Option 1 : SCP (recommandée)**

```bash
# Copier les fichiers vers Kamatera
scp academia_bobodo_backend/whiteboard_*.py user@kamatera:/path/to/academia_bobodo_backend/

# Copier les dépendances
scp academia_bobodo_backend/requirements.txt user@kamatera:/path/to/academia_bobodo_backend/
```

**Option 2 : Git pull**

```bash
# Sur Kamatera
cd /path/to/academia
git pull
```

### 1.3 Installation des dépendances

```bash
# Sur Kamatera
cd /path/to/academia_bobodo_backend
pip install -r requirements.txt
```

**Dépendances requises** :
- Pillow
- httpx
- python-dotenv

### 1.4 Configuration des variables d'environnement

```bash
# Sur Kamatera
export SUPABASE_URL="https://thevdfcwlcqzdoybfvgs.supabase.co"
export SUPABASE_SERVICE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
export WORKER_LOOP=1
export WORKER_INTERVAL_SECONDS=2
export WORKER_MAX_JOBS=1
```

### 1.5 Vérification de FFmpeg

```bash
# Sur Kamatera
ffmpeg -version
```

**Attendu** : FFmpeg 6.1.1-3ubuntu5 (déjà installé selon audit Kamatera)

---

## ÉTAPE 2 – CRÉATION STORYBOARD RÉEL

### 2.1 Sujet

**Photosynthèse**

### 2.2 Contenu minimum

- Titre
- Définition
- Paragraphe
- Exercice
- Correction

### 2.3 Script d'insertion

**Fichier** : `.windsurf/phase_c3a_insert_storyboard.py`

**Exécution** :
```bash
python .windsurf/phase_c3a_insert_storyboard.py
```

**Résultat** :
- Job ID généré
- Statut : queued
- Storyboard inséré dans whiteboard_renders

---

## ÉTAPE 3 – CRÉATION RENDERJOB RÉEL

### 3.1 Statut

**queued**

### 3.2 Vérification

```sql
SELECT id, status, created_at 
FROM app.whiteboard_renders 
ORDER BY created_at DESC 
LIMIT 1;
```

---

## ÉTAPE 4 – LANCEMENT WORKER

### 4.1 Commande

```bash
# Sur Kamatera
cd /path/to/academia_bobodo_backend
python whiteboard_render_worker.py
```

### 4.2 Configuration

- WORKER_LOOP=1 (boucle infinie)
- WORKER_INTERVAL_SECONDS=2 (intervalle polling)
- WORKER_MAX_JOBS=1 (jobs max par itération)

### 4.3 Logs attendus

```
[whiteboard_render_worker] Found 1 queued job(s)
[whiteboard_render_worker] Processing job {job_id}
[whiteboard_render_worker] Generating PNGs for job {job_id}
[whiteboard_render_worker] Assembling MP4 for job {job_id}
[whiteboard_render_worker] Uploading MP4 for job {job_id}
[whiteboard_render_worker] Job {job_id} completed successfully
```

---

## ÉTAPE 5 – OBSERVATION TRAITEMENT

### 5.1 Script de surveillance

**Fichier** : `.windsurf/phase_c3a_monitor.py`

**Exécution** :
```bash
python .windsurf/phase_c3a_monitor.py {job_id}
```

**Ou sans job_id (dernier job)** :
```bash
python .windsurf/phase_c3a_monitor.py
```

### 5.2 Transitions attendues

```
queued
↓
processing
↓
done
```

### 5.3 Durée attendue

**Estimation** : 30-60 secondes

**Détail** :
- Polling : 2s
- Génération PNGs (6 scènes) : 10-20s
- Assemblage MP4 : 5-10s
- Upload : 5-10s
- Total : 22-42s

---

## ÉTAPE 6 – VÉRIFICATION RÉSULTAT

### 6.1 PNG générés

**Vérification** : Les PNGs doivent être générés dans le répertoire temporaire du Worker

**Nombre attendu** : 6 PNGs (scene_001.png à scene_006.png)

### 6.2 MP4 généré

**Vérification** : Le MP4 doit être généré dans le répertoire temporaire du Worker

**Format attendu** :
- Résolution : 1080x1920
- Codec : H.264
- Pixel format : yuv420p
- Framerate : 30 fps
- Durée : ~30s (6 scènes × 5s)

### 6.3 MP4 uploadé

**Vérification** : Le MP4 doit être uploadé dans whiteboard-renders

**URL** : `{SUPABASE_URL}/storage/v1/object/public/whiteboard-renders/renders/{job_id}/{uuid}.mp4`

### 6.4 URL stockée

**Vérification** : L'URL doit être stockée dans whiteboard_renders.video_url

```sql
SELECT video_url FROM app.whiteboard_renders WHERE id = '{job_id}';
```

### 6.5 Statut done

**Vérification** : Le statut doit être done

```sql
SELECT status FROM app.whiteboard_renders WHERE id = '{job_id}';
```

---

## ÉTAPE 7 – MESURE PERFORMANCE

### 7.1 Temps réel

**Mesure** : completed_at - started_at

**Attendu** : 22-42 secondes

### 7.2 CPU réel

**Mesure** : `top` ou `htop` sur Kamatera pendant le traitement

**Attendu** : 1-2 cores

### 7.3 RAM réelle

**Mesure** : `free -h` sur Kamatera pendant le traitement

**Attendu** : 500 Mo - 1 Go

### 7.4 Taille MP4

**Mesure** : Taille du fichier MP4 uploadé

**Attendu** : 5-10 Mo (30s, H.264, CRF 23)

---

## CRITÈRE DE RÉUSSITE

**Un MP4 réel existe dans whiteboard-renders et le statut du RenderJob est done sans intervention manuelle.**

---

## LIVRABLES

- `docs/PHASE_C3A_PIPELINE_VALIDATION.md` (ce document)
- `docs/PHASE_C3A_PERFORMANCE.md`

---

## PROCHAINES ÉTAPES

1. Déployer les composants sur Kamatera
2. Exécuter `phase_c3a_insert_storyboard.py`
3. Lancer le Worker
4. Exécuter `phase_c3a_monitor.py`
5. Mesurer les performances
6. Créer `docs/PHASE_C3A_PERFORMANCE.md`

---

**Fin du document**

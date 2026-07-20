# PHASE C.3B – FIRST REAL VIDEO

**Version** : 1.0  
**Date** : 23 Juin 2026  
**Phase** : C.3B – First Real Video  
**Mode** : EXÉCUTION RÉELLE  
**Objectif** : Produire le premier MP4 réel Smart Whiteboard

---

## DIRECTIVE TECHNIQUE PERMANENTE

Toute vérification Supabase et Kamatera doit continuer à utiliser les RPC Python administrateurs présents dans `.windsurf`.

---

## CONTRAINTE

AUCUNE NOUVELLE FONCTIONNALITÉ  
Ne pas développer  
Ne pas refactoriser  
Ne pas améliorer  
Utiliser exclusivement les composants déjà créés

---

## ÉTAPE 1 – DÉPLOIEMENT SUR KAMATERA

### 1.1 Copier les fichiers

```bash
# Depuis votre machine locale
scp academia_bobodo_backend/whiteboard_render_worker.py user@kamatera:/path/to/academia_bobodo_backend/
scp academia_bobodo_backend/whiteboard_png_renderer.py user@kamatera:/path/to/academia_bobodo_backend/
scp academia_bobodo_backend/whiteboard_ffmpeg_assembler.py user@kamatera:/path/to/academia_bobodo_backend/
scp academia_bobodo_backend/whiteboard_upload_renderer.py user@kamatera:/path/to/academia_bobodo_backend/
```

### 1.2 Se connecter à Kamatera

```bash
ssh user@kamatera
cd /path/to/academia_bobodo_backend
```

### 1.3 Vérifier les fichiers

```bash
ls -la whiteboard_*.py
```

**Attendu** : 4 fichiers

---

## ÉTAPE 2 – INSTALLATION DÉPENDANCES

### 2.1 Vérifier Python

```bash
python --version
```

**Attendu** : Python 3.11+

### 2.2 Installer Pillow

```bash
pip install Pillow
```

### 2.3 Vérifier httpx

```bash
pip show httpx
```

Si non installé :
```bash
pip install httpx
```

### 2.4 Vérifier python-dotenv

```bash
pip show python-dotenv
```

Si non installé :
```bash
pip install python-dotenv
```

### 2.5 Vérifier FFmpeg

```bash
ffmpeg -version
```

**Attendu** : FFmpeg 6.1.1-3ubuntu5 (déjà installé selon audit)

---

## ÉTAPE 3 – CONFIGURATION VARIABLES D'ENVIRONNEMENT

### 3.1 Créer ou éditer .env

```bash
nano .env
```

### 3.2 Ajouter les variables

```env
SUPABASE_URL=https://thevdfcwlcqzdoybfvgs.supabase.co
SUPABASE_SERVICE_KEY=<REDACTED_SUPABASE_SERVICE_ROLE_KEY>
WORKER_LOOP=1
WORKER_INTERVAL_SECONDS=2
WORKER_MAX_JOBS=1
```

### 3.3 Sauvegarder et quitter

Ctrl+O, Enter, Ctrl+X

---

## ÉTAPE 4 – CRÉATION STORYBOARD RÉEL

### 4.1 Exécuter le script d'insertion

```bash
# Depuis votre machine locale
python .windsurf/phase_c3a_insert_storyboard.py
```

### 4.2 Noter le Job ID

Le script affichera :
```
Job ID : {uuid}
```

Notez ce UUID pour la surveillance.

---

## ÉTAPE 5 – LANCEMENT WORKER

### 5.1 Lancer le worker en mode loop

```bash
# Sur Kamatera
cd /path/to/academia_bobodo_backend
python whiteboard_render_worker.py
```

### 5.2 Observer les logs

**Logs attendus** :
```
[whiteboard_render_worker] Found 1 queued job(s)
[whiteboard_render_worker] Processing job {job_id}
[whiteboard_render_worker] Generating PNGs for job {job_id}
[whiteboard_render_worker] Assembling MP4 for job {job_id}
[whiteboard_render_worker] Uploading MP4 for job {job_id}
[whiteboard_render_worker] Job {job_id} completed successfully
```

---

## ÉTAPE 6 – SURVEILLANCE

### 6.1 Exécuter le script de surveillance

```bash
# Depuis votre machine locale
python .windsurf/phase_c3a_monitor.py {job_id}
```

### 6.2 Observer les transitions

```
queued → processing → done
```

### 6.3 Attendre le résultat

Timeout : 120 secondes

---

## VÉRIFICATIONS OBLIGATOIRES

### Vérification 1 : PNG générés

**Action** : Vérifier les logs du worker

**Attendu** :
```
[whiteboard_render_worker] Generating PNGs for job {job_id}
```

**Preuve** : Logs worker

### Vérification 2 : FFmpeg exécuté

**Action** : Vérifier les logs du worker

**Attendu** :
```
[whiteboard_render_worker] Assembling MP4 for job {job_id}
```

**Preuve** : Logs worker + logs FFmpeg (stderr si erreur)

### Vérification 3 : MP4 généré

**Action** : Télécharger le MP4 depuis l'URL

**Commande** :
```bash
curl -O {video_url}
ffprobe output.mp4
```

**Attendu** :
- Taille : 5-10 Mo
- Durée : ~30s
- Résolution : 1080x1920

**Preuve** : ffprobe output

### Vérification 4 : Upload Storage réussi

**Action** : Vérifier l'URL dans la table

**SQL** :
```sql
SELECT video_url FROM app.whiteboard_renders WHERE id = '{job_id}';
```

**Attendu** : URL valide commençant par `https://thevdfcwlcqzdoybfvgs.supabase.co/storage/v1/object/public/whiteboard-renders/`

**Preuve** : URL réelle

### Vérification 5 : Table mise à jour

**Action** : Vérifier le statut

**SQL** :
```sql
SELECT status, video_url, duration_ms, error_message, started_at, completed_at 
FROM app.whiteboard_renders 
WHERE id = '{job_id}';
```

**Attendu** :
- status = done
- video_url = URL valide
- duration_ms = 30000 (6 scènes × 5s)
- error_message = NULL
- started_at = timestamp
- completed_at = timestamp

**Preuve** : SQL output

---

## MESURES

### Mesure 1 : Temps réel

**Méthode** : completed_at - started_at

**SQL** :
```sql
SELECT 
    EXTRACT(EPOCH FROM (completed_at - started_at)) as duration_seconds
FROM app.whiteboard_renders 
WHERE id = '{job_id}';
```

**Attendu** : 22-42 secondes

### Mesure 2 : Ressources

**CPU** :
```bash
# Sur Kamatera pendant le traitement
top -b -n 1 | grep python
```

**RAM** :
```bash
# Sur Kamatera pendant le traitement
free -h
```

**Attendu** :
- CPU : 1-2 cores
- RAM : 500 Mo - 1 Go

---

## PREUVES OBLIGATOIRES

1. **Logs worker** : Copier les logs du worker
2. **Logs FFmpeg** : Si erreur, copier stderr
3. **URL MP4** : Copier l'URL depuis la table
4. **Taille MP4** : Copier la taille du fichier
5. **Statut final** : Copier le SQL output

---

## CRITÈRE DE RÉUSSITE

Un fichier MP4 réel existe dans whiteboard-renders et peut être ouvert. Le statut est done sans intervention manuelle.

---

## PROBLÈMES COURANTS

### Problème 1 : Pillow non installé

**Erreur** : `ModuleNotFoundError: No module named 'PIL'`

**Solution** :
```bash
pip install Pillow
```

### Problème 2 : FFmpeg non trouvé

**Erreur** : `FileNotFoundError: [Errno 2] No such file or directory: 'ffmpeg'`

**Solution** :
```bash
sudo apt-get install ffmpeg
```

### Problème 3 : Variables d'environnement manquantes

**Erreur** : `KeyError: 'SUPABASE_URL'`

**Solution** : Créer le fichier .env avec les variables

### Problème 4 : Permission denied sur Storage

**Erreur** : HTTP 403 lors de l'upload

**Solution** : Vérifier que SUPABASE_SERVICE_KEY est correct

---

## LIVRABLES

- `docs/PHASE_C3B_FIRST_VIDEO.md` (ce document)
- `docs/PHASE_C3B_REAL_METRICS.md`

---

**Fin du document**

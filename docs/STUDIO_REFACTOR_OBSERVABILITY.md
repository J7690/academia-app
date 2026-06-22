# STUDIO REFACTOR - OBSERVABILITY

**Date :** 19 Juin 2026
**Chantier :** G - Observabilité
**Statut :** 🚧 En cours

---

## OBJECTIF

Ajouter un système de tracking et de métriques pour observer le pipeline vidéo en production. Permettre de tracer chaque vidéo depuis l'upload jusqu'au transcodage, et de mesurer les temps de traitement pour identifier les goulots d'étranglement.

---

## ANALYSE ACTUELLE

### Tracking Existant

**Table :** `video_processing_jobs`
- `id` - UUID du job
- `video_asset_id` - UUID de la vidéo
- `job_type` - Type de job (generate_hls, generate_mp4, export_watermarked, transcode_resolution)
- `status` - Statut (queued, processing, done, failed)
- `payload` - Payload JSON avec les arguments FFmpeg
- `worker_id` - ID du worker (optionnel)
- `started_at` - Timestamp de début
- `completed_at` - Timestamp de fin
- `error_message` - Message d'erreur si échec

**Problème :**
- Pas de tracking granulaire par étape (upload, transcodage, upload renditions)
- Pas de métriques de durée (temps upload, temps transcodage, temps total)
- Pas de tracking par worker (quel worker a traité quel job)
- Pas de métriques agrégées (temps moyen, taux d'échec, etc.)

### Worker Kamatera

**Fichier :** `academia_bobodo_backend/videoasset_worker.py`

**Tracking actuel :**
- `_mark_job_processing(job_id)` - Marque job comme processing
- `_mark_job_done(job_id)` - Marque job comme done
- `_mark_job_failed(job_id, error)` - Marque job comme failed

**Problème :**
- Pas de tracking des étapes intermédiaires (téléchargement, FFmpeg, upload)
- Pas de métriques de durée par étape
- Pas de tracking du worker_id

---

## ACTIONS REQUISES

### 1. Ajouter tracking video_asset_id/job_id/worker_id

**Action :** Ajouter le worker_id dans les logs et dans la table video_processing_jobs.

**Changement dans videoasset_worker.py :**
```python
# Ajouter worker_id comme constante
WORKER_ID = os.getenv('WORKER_ID', 'worker-unknown')

# Quand on marque un job processing
await _mark_job_processing(job_id, worker_id=WORKER_ID)

# Quand on marque un job done
await _mark_job_done(job_id, worker_id=WORKER_ID)
```

**Changement dans la table video_processing_jobs :**
```sql
ALTER TABLE video_processing_jobs 
ADD COLUMN worker_id TEXT;
```

### 2. Ajouter metrics duration

**Action :** Ajouter des colonnes de durée dans video_processing_jobs et créer une table de métriques agrégées.

**Changement dans video_processing_jobs :**
```sql
ALTER TABLE video_processing_jobs 
ADD COLUMN upload_duration_ms INTEGER,
ADD COLUMN transcode_duration_ms INTEGER,
ADD COLUMN upload_renditions_duration_ms INTEGER,
ADD COLUMN total_duration_ms INTEGER;
```

**Changement dans videoasset_worker.py :**
```python
# Mesurer le temps de téléchargement
download_start = time.time()
await _download_video(...)
download_duration_ms = int((time.time() - download_start) * 1000)

# Mesurer le temps de transcodage
transcode_start = time.time()
await _run_ffmpeg(...)
transcode_duration_ms = int((time.time() - transcode_start) * 1000)

# Mesurer le temps d'upload des renditions
upload_start = time.time()
await _upload_renditions(...)
upload_renditions_duration_ms = int((time.time() - upload_start) * 1000)

# Marquer le job avec les durées
await _mark_job_done(
    job_id, 
    worker_id=WORKER_ID,
    upload_duration_ms=download_duration_ms,
    transcode_duration_ms=transcode_duration_ms,
    upload_renditions_duration_ms=upload_renditions_duration_ms,
    total_duration_ms=download_duration_ms + transcode_duration_ms + upload_renditions_duration_ms
)
```

### 3. Créer table video_processing_metrics

**Action :** Créer une table pour stocker les métriques agrégées par jour/heure.

```sql
CREATE TABLE video_processing_metrics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  period_start TIMESTAMP NOT NULL,
  period_end TIMESTAMP NOT NULL,
  job_type TEXT NOT NULL,
  worker_id TEXT,
  total_jobs INTEGER DEFAULT 0,
  successful_jobs INTEGER DEFAULT 0,
  failed_jobs INTEGER DEFAULT 0,
  avg_upload_duration_ms NUMERIC,
  avg_transcode_duration_ms NUMERIC,
  avg_upload_renditions_duration_ms NUMERIC,
  avg_total_duration_ms NUMERIC,
  p95_total_duration_ms NUMERIC,
  p99_total_duration_ms NUMERIC,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_video_processing_metrics_period ON video_processing_metrics(period_start, period_end);
CREATE INDEX idx_video_processing_metrics_job_type ON video_processing_metrics(job_type);
```

**RPC pour agréger les métriques :**
```sql
CREATE OR REPLACE FUNCTION app_aggregate_video_processing_metrics(
  p_period_start TIMESTAMP,
  p_period_end TIMESTAMP
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO video_processing_metrics (
    period_start,
    period_end,
    job_type,
    worker_id,
    total_jobs,
    successful_jobs,
    failed_jobs,
    avg_upload_duration_ms,
    avg_transcode_duration_ms,
    avg_upload_renditions_duration_ms,
    avg_total_duration_ms
  )
  SELECT
    p_period_start,
    p_period_end,
    job_type,
    worker_id,
    COUNT(*) as total_jobs,
    COUNT(*) FILTER (WHERE status = 'done') as successful_jobs,
    COUNT(*) FILTER (WHERE status = 'failed') as failed_jobs,
    AVG(upload_duration_ms) as avg_upload_duration_ms,
    AVG(transcode_duration_ms) as avg_transcode_duration_ms,
    AVG(upload_renditions_duration_ms) as avg_upload_renditions_duration_ms,
    AVG(total_duration_ms) as avg_total_duration_ms
  FROM video_processing_jobs
  WHERE created_at >= p_period_start
    AND created_at < p_period_end
  GROUP BY job_type, worker_id;
END;
$$;
```

### 4. Dashboard d'observabilité

**Action :** Créer un dashboard admin pour visualiser les métriques.

**Métriques à afficher :**
- Jobs par heure/jour
- Taux d'échec par job_type
- Temps moyen de traitement par job_type
- Temps de traitement P95/P99
- Performance par worker

---

## PIPELINE DE CHANGEMENT

### Étape 1: Modifier la table video_processing_jobs

**Action :** Ajouter les colonnes worker_id et duration.

### Étape 2: Modifier le Worker Kamatera

**Fichier :** `academia_bobodo_backend/videoasset_worker.py`

**Action :** 
- Ajouter WORKER_ID
- Mesurer les durées par étape
- Passer les durées à _mark_job_done

### Étape 3: Créer la table video_processing_metrics

**Action :** Créer la table et la RPC d'agrégation.

### Étape 4: Créer un job pg_cron pour l'agrégation

**Action :** Agréger les métriques toutes les heures.

```sql
SELECT cron.schedule(
  'aggregate-video-metrics-hourly',
  '0 * * * *',
  $$
  SELECT app_aggregate_video_processing_metrics(
    NOW() - INTERVAL '1 hour',
    NOW()
  );
  $$
);
```

### Étape 5: Créer le dashboard admin

**Action :** Créer un écran Flutter pour visualiser les métriques.

---

## LIVRABLES

- [ ] Ajouter tracking video_asset_id/job_id/worker_id
- [ ] Ajouter metrics duration
- [ ] Créer table video_processing_metrics
- [ ] Livrable STUDIO_REFACTOR_OBSERVABILITY.md

---

**Statut :** 🚧 En cours

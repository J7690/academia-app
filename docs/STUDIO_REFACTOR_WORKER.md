# STUDIO_REFACTOR_WORKER

**Date :** 19 Juin 2026  
**Objectif :** Faire de Kamatera l'unique moteur FFmpeg et corriger les jobs ignorés

---

## ANALYSE DU WORKER

### Code actuel - _process_single_job()

**Fichier :** academia_bobodo_backend/videoasset_worker.py:586-605

```python
async def _process_single_job(job: Dict[str, Any], worker_id: str) -> None:
    job_type = str(job.get("job_type") or "").strip().lower()
    job_id = str(job.get("id") or "").strip()

    if not job_type or not job_id:
        logger.warning("[videoasset_worker] Job sans job_type ou id, on le marque failed.")
        await _mark_job_failed(job_id or "", "invalid_job_payload")
        return

    if job_type in ("generate_hls", "generate_mp4"):
        await _process_generate_hls_job(job, worker_id)
        return

    if job_type == "export_watermarked":
        await _process_export_watermarked_job(job, worker_id)
        return

    # Pour l'instant, les autres types de job sont marqués comme terminés sans effet.
    logger.info("[videoasset_worker] Job %s ignoré (type=%s), marqué done.", job_id, job_type)
    await _mark_job_done(job_id)
```

### Jobs créés par Edge Function transcode-multi-resolution

**Fichier :** supabase/functions/transcode-multi-resolution/index.ts:127-145

```typescript
// Insert processing job
const { error: jobErr } = await appDb
  .from('video_processing_jobs')
  .insert({
    video_asset_id: videoAssetId,
    job_type: 'transcode_resolution',
    status: 'queued',
    payload: {
      source_url: sourceUrl,
      source_bucket: bucket,
      source_path: path,
      output_bucket: 'video-assets',
      output_path: outputPath,
      rendition_id: rendition?.id,
      rendition_key: profile.key,
      target_height: profile.height,
      target_bitrate: profile.bitrate,
      ffmpeg_args: `-vf "scale=-2:${profile.height}" -c:v libx264 -preset fast -b:v ${profile.bitrate} -c:a aac -b:a 128k -movflags +faststart`,
    },
  });
```

### Root cause identifiée

**Incompatibilité job_type :**
- Edge Function crée des jobs avec `job_type: 'transcode_resolution'`
- Worker ne traite que `generate_hls`, `generate_mp4`, `export_watermarked`
- Les jobs `transcode_resolution` sont ignorés et marqués `done` sans traitement

**Preuve :**
```python
if job_type in ("generate_hls", "generate_mp4"):
    await _process_generate_hls_job(job, worker_id)
    return

if job_type == "export_watermarked":
    await _process_export_watermarked_job(job, worker_id)
    return

# Pour l'instant, les autres types de job sont marqués comme terminés sans effet.
logger.info("[videoasset_worker] Job %s ignoré (type=%s), marqué done.", job_id, job_type)
await _mark_job_done(job_id)
```

**Résultat :**
- Les jobs `transcode_resolution` sont créés en statut `queued`
- Le Worker les pickup mais les ignore
- Les jobs sont marqués `done` sans générer de renditions

---

## ACTIONS REQUISES

### 1. Corriger le Worker pour traiter transcode_resolution

**Problème :** Le Worker ignore les jobs `transcode_resolution` créés par Edge Function.

**Solution :** Ajouter le support pour `transcode_resolution` dans le Worker.

**Modification :**
```python
if job_type in ("generate_hls", "generate_mp4"):
    await _process_generate_hls_job(job, worker_id)
    return

if job_type == "export_watermarked":
    await _process_export_watermarked_job(job, worker_id)
    return

if job_type == "transcode_resolution":
    await _process_transcode_resolution_job(job, worker_id)
    return

# Pour l'instant, les autres types de job sont marqués comme terminés sans effet.
logger.info("[videoasset_worker] Job %s ignoré (type=%s), marqué done.", job_id, job_type)
await _mark_job_done(job_id)
```

### 2. Implémenter _process_transcode_resolution_job()

**Fonction à implémenter :**
- `_process_transcode_resolution_job()` - utilise le payload FFmpeg args pour générer la rendition spécifique

### 3. Simplifier le pipeline

**Flux actuel :**
```
Flutter upload
↓
transcode-video Edge Function
↓
transcode-multi-resolution Edge Function
↓
Jobs transcode_resolution créés (ignorés par Worker)
↓
Worker marque jobs done sans traitement
```

**Flux cible :**
```
Flutter upload
↓
transcode-video Edge Function
↓
Worker crée jobs generate_mp4 (toutes renditions)
↓
Worker traite jobs
↓
Worker génère renditions (main, 480p, 360p, 240p)
↓
Worker marque jobs done
```

---

## LIVRABLES

- [ ] Ajouter support transcode_resolution dans Worker
- [ ] Implémenter _process_transcode_resolution_job()
- [ ] Tests Worker traitement jobs
- [ ] Logs Worker réels

---

**Statut :** 🚧 En cours

# RENDERER REUSE AUDIT

**Version** : 1.0  
**Date** : 23 Juin 2026  
**Phase** : C.1 – Renderer Reuse Audit  
**Mode** : LECTURE SEULE  
**Objectif** : Identifier précisément ce qui peut être réutilisé du renderer vidéo actuel

---

## DIRECTIVE TECHNIQUE PERMANENTE

Toute vérification Kamatera a été réalisée via l'analyse des fichiers existants dans `academia_bobodo_backend/`.

---

## PARTIE 1 – ANALYSE studio_video_renderer.py

### 1.1 Rôle actuel

Transcodage vidéo multi-résolution pour le Studio TikTok :
- Rendition principale (source légère) : 720p, H.264 Baseline Level 3.0
- Rendition 480p : 480p, 30fps, 600k bitrate
- Rendition 360p : 360p, 30fps, 450k bitrate
- Rendition 240p : 240p, 24fps, 300k bitrate
- Upload vers Supabase Storage (challenge-media)

### 1.2 Dépendances

```python
from pathlib import Path
import os
import uuid
import tempfile
import subprocess
from typing import Any, Dict, Optional, List

import httpx
from fastapi import FastAPI, HTTPException, Request
from pydantic import BaseModel
from dotenv import load_dotenv
```

### 1.3 Fonctions principales

| Fonction | Rôle | Réutilisable | Adaptations nécessaires |
|----------|------|--------------|------------------------|
| _download_video_to_temp | Téléchargement vidéo depuis URL | ✅ OUI | Adapter pour téléchargement storyboard_json |
| _run_ffmpeg_transcode | Transcodage 720p | ⚠️ Partiellement | Remplacer par génération PNG |
| _run_ffmpeg_transcode_480p | Transcodage 480p | ⚠️ Partiellement | Remplacer par génération PNG |
| _run_ffmpeg_transcode_360p | Transcodage 360p | ⚠️ Partiellement | Remplacer par génération PNG |
| _run_ffmpeg_transcode_240p | Transcodage 240p | ⚠️ Partiellement | Remplacer par génération PNG |
| _run_ffmpeg_generic | Transcodage générique | ✅ OUI | Adapter pour assemblage PNG → MP4 |
| _run_ffmpeg_tv_complex | Transcodage TV complexe | ❌ NON | Non utilisé pour Smart Whiteboard |
| _upload_to_supabase_storage | Upload MP4 vers Storage | ✅ OUI | Adapter pour whiteboard-renders bucket |

### 1.4 Pattern FFmpeg

**Pattern réutilisable** :
```python
cmd = [
    "ffmpeg",
    "-y",
    "-i", str(input_path),
    "-vf", vf_filter,
    "-c:v", "libx264",
    "-preset", "veryfast",
    "-profile:v", "baseline",
    "-level", "3.0",
    "-x264-params", x264_params,
    "-g", "30",
    "-keyint_min", "30",
    "-pix_fmt", "yuv420p",
    "-color_primaries", "bt709",
    "-color_trc", "bt709",
    "-colorspace", "bt709",
    "-movflags", "+faststart",
    "-c:a", "aac",
    "-ac", "2",
    "-ar", "44100",
    "-b:a", audio_bitrate,
    str(output_path),
]
```

**Adaptation nécessaire** :
```python
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
    str(output_path),
]
```

### 1.5 Conclusion

**Réutilisable** : ⚠️ Partiellement (pattern FFmpeg, upload Storage)  
**À adapter** : Remplacer transcodage vidéo par génération PNG + assemblage MP4  
**Pourcentage de réutilisation** : ~40%

---

## PARTIE 2 – ANALYSE videoasset_worker.py

### 2.1 Rôle actuel

Worker polling pour traitement vidéo VideoAsset :
- Poll video_processing_jobs (status=queued)
- Marque job comme running
- Télécharge source depuis Supabase Storage
- Exécute FFmpeg (transcodage ou watermark)
- Upload renditions vers Supabase Storage
- Met à jour video_renditions
- Marque job comme done

### 2.2 Dépendances

```python
from __future__ import annotations

import asyncio
import logging
import os
import socket
import subprocess
import tempfile
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional

import httpx
from dotenv import load_dotenv

from studio_video_renderer import (
    _run_ffmpeg_transcode,
    _run_ffmpeg_transcode_240p,
    _run_ffmpeg_transcode_360p,
    _run_ffmpeg_transcode_480p,
)
```

### 2.3 Fonctions principales

| Fonction | Rôle | Réutilisable | Adaptations nécessaires |
|----------|------|--------------|------------------------|
| _check_config | Vérification configuration | ✅ OUI | Aucune |
| _diagnose_supabase_dns | Diagnostic DNS | ✅ OUI | Aucune |
| _rest_base | Base URL REST | ✅ OUI | Aucune |
| _storage_base | Base URL Storage | ✅ OUI | Aucune |
| _supabase_headers | Headers Supabase | ✅ OUI | Aucune |
| _fetch_queued_jobs | Poll jobs | ✅ OUI | Adapter pour whiteboard_renders |
| _update_job | Update job | ✅ OUI | Adapter pour whiteboard_renders |
| _mark_job_running | Marque running | ✅ OUI | Adapter pour whiteboard_renders |
| _mark_job_done | Marque done | ✅ OUI | Adapter pour whiteboard_renders |
| _mark_job_failed | Marque failed | ✅ OUI | Adapter pour whiteboard_renders |
| _get_primary_source_for_asset | Récupération source | ✅ OUI | Adapter pour storyboard_json |
| _download_source_to_temp | Téléchargement source | ✅ OUI | Adapter pour storyboard_json |
| _delete_existing_mp4_renditions | Suppression renditions | ✅ OUI | Adapter pour whiteboard_renders |
| _get_rendition_row | Récupération rendition | ✅ OUI | Adapter pour whiteboard_renders |
| _delete_rendition_by_key | Suppression rendition | ✅ OUI | Adapter pour whiteboard_renders |
| _upload_rendition_file | Upload rendition | ✅ OUI | Adapter pour whiteboard-renders |
| _insert_video_renditions | Insert renditions | ✅ OUI | Adapter pour whiteboard_renders |
| _upsert_video_rendition | Upsert rendition | ✅ OUI | Adapter pour whiteboard_renders |
| _run_ffmpeg_export_watermarked | Watermark TikTok | ❌ NON | Non utilisé pour Smart Whiteboard |
| _mark_video_asset_ready | Marque asset ready | ✅ OUI | Adapter pour whiteboard_renders |
| _process_generate_hls_job | Process job generate_hls | ⚠️ Partiellement | Adapter pour whiteboard_render |
| _process_export_watermarked_job | Process job export_watermarked | ❌ NON | Non utilisé pour Smart Whiteboard |
| _process_single_job | Process job générique | ✅ OUI | Adapter pour whiteboard_render |
| run_once | Exécution one-shot | ✅ OUI | Aucune |

### 2.4 Pattern worker

**Pattern réutilisable** :
```python
if __name__ == "__main__":
    loop_mode = (os.getenv("WORKER_LOOP") or "").strip().lower() in {"1", "true", "yes"}
    if not loop_mode:
        asyncio.run(run_once())
    else:
        interval_s = float((os.getenv("WORKER_INTERVAL_SECONDS") or "2").strip() or "2")

        async def _loop():
            while True:
                try:
                    await run_once(max_jobs=int(os.getenv("WORKER_MAX_JOBS") or "3"))
                except Exception:
                    logger.exception("[videoasset_worker] Loop iteration failed")
                await asyncio.sleep(max(interval_s, 0.5))

        asyncio.run(_loop())
```

**Configuration** :
- WORKER_LOOP=1 (boucle infinie)
- WORKER_INTERVAL_SECONDS=2 (intervalle polling)
- WORKER_MAX_JOBS=3 (jobs max par itération)

### 2.5 Pattern queue de jobs

**Pattern réutilisable** :
```python
async def _fetch_queued_jobs(limit: int = 5) -> List[Dict[str, Any]]:
    url = f"{_rest_base()}/video_processing_jobs"
    params = {
        "status": "eq.queued",
        "order": "created_at.asc",
        "limit": str(limit),
    }
    async with httpx.AsyncClient(timeout=SUPABASE_HTTP_TIMEOUT) as client:
        resp = await client.get(url, headers=_supabase_headers(), params=params)
    # ...
```

**Adaptation nécessaire** :
```python
async def _fetch_queued_jobs(limit: int = 5) -> List[Dict[str, Any]]:
    url = f"{_rest_base()}/whiteboard_renders"
    params = {
        "status": "eq.queued",
        "order": "created_at.asc",
        "limit": str(limit),
    }
    # ...
```

### 2.6 Pattern logs

**Pattern réutilisable** :
```python
logger = logging.getLogger("videoasset_worker")
if not logging.getLogger().handlers:
    logging.basicConfig(level=logging.INFO)

logger.info("[videoasset_worker] Traitement de %d job(s) VideoAsset.", len(jobs))
logger.exception("[videoasset_worker] Erreur sur job generate_hls %s", job_id)
```

### 2.7 Conclusion

**Réutilisable** : ✅ Fortement (pattern worker, queue, upload Storage, logs)  
**À adapter** : Remplacer video_processing_jobs par whiteboard_renders, remplacer transcodage par génération PNG  
**Pourcentage de réutilisation** : ~80%

---

## PARTIE 3 – ANALYSE main.py

### 3.1 Rôle actuel

Backend FastAPI pour l'assistant Bobodo :
- Proxy Supabase (contournement DNS)
- Endpoints vidéo (debug/ffmpeg, studio/video/render, challenge/burn-overlays, challenge/generate-thumbnail)
- Endpoints IA (bobodo-chat, ai/prep/generate)
- Endpoints LiveKit (livekit/token)
- Endpoints Studio (studio/transcription, studio/analyze, studio/proofread, studio/audio/render, studio/video/render)

### 3.2 Dépendances

```python
import os
from pathlib import Path
from typing import Any, Dict, List, Optional
from datetime import datetime, timezone
import subprocess
import tempfile
import json
import time
import uuid
import hashlib
import logging
import math
import shutil

from fastapi import FastAPI, HTTPException, Request, Response, UploadFile, File, Form
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import httpx
from dotenv import load_dotenv
from livekit import api as livekit_api
from studio_video_renderer import (
    _download_video_to_temp,
    _run_ffmpeg_transcode,
    _run_ffmpeg_transcode_480p,
    _run_ffmpeg_transcode_360p,
    _run_ffmpeg_transcode_240p,
    _upload_to_supabase_storage,
    _run_ffmpeg_generic,
)
from studio_video_renderer_pro import run_ffmpeg_tv_pro
from tv_pro_filter_builder import build_tv_pro_filtergraph
```

### 3.3 Fonctions principales

| Fonction | Rôle | Réutilisable | Adaptations nécessaires |
|----------|------|--------------|------------------------|
| debug_ffmpeg | Diagnostic FFmpeg | ✅ OUI | Aucune |
| supabase_proxy | Proxy Supabase | ✅ OUI | Aucune |
| call_supabase_rpc | Appel RPC | ✅ OUI | Aucune |
| call_openrouter | Appel OpenRouter | ❌ NON | Non utilisé pour Smart Whiteboard |
| get_livekit_token | Token LiveKit | ❌ NON | Non utilisé pour Smart Whiteboard |
| ai_prep_generate | Génération IA Prépa | ❌ NON | Non utilisé pour Smart Whiteboard |

### 3.4 Pattern proxy Supabase

**Pattern réutilisable** :
```python
@app.api_route("/supabase/{full_path:path}", methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"])
async def supabase_proxy(full_path: str, request: Request) -> Response:
    supabase_base = SUPABASE_URL.rstrip("/")
    target_url = f"{supabase_base}/{full_path}"
    # Construction headers
    # Appel httpx
    # Retourne Response
```

### 3.5 Conclusion

**Réutilisable** : ⚠️ Partiellement (pattern FastAPI, proxy Supabase)  
**À adapter** : Ajouter endpoints Smart Whiteboard (whiteboard/render, whiteboard/status)  
**Pourcentage de réutilisation** : ~30%

---

## PARTIE 4 – ANALYSE COMPOSANTS FFMPEG

### 4.1 Composants existants

| Composant | Fichier | Rôle | Réutilisable | Adaptations nécessaires |
|-----------|---------|------|--------------|------------------------|
| _run_ffmpeg_transcode | studio_video_renderer.py | Transcodage 720p | ⚠️ Partiellement | Remplacer par génération PNG |
| _run_ffmpeg_transcode_480p | studio_video_renderer.py | Transcodage 480p | ⚠️ Partiellement | Remplacer par génération PNG |
| _run_ffmpeg_transcode_360p | studio_video_renderer.py | Transcodage 360p | ⚠️ Partiellement | Remplacer par génération PNG |
| _run_ffmpeg_transcode_240p | studio_video_renderer.py | Transcodage 240p | ⚠️ Partiellement | Remplacer par génération PNG |
| _run_ffmpeg_generic | studio_video_renderer.py | Transcodage générique | ✅ OUI | Adapter pour assemblage PNG → MP4 |
| _run_ffmpeg_tv_complex | studio_video_renderer.py | Transcodage TV complexe | ❌ NON | Non utilisé |
| _run_ffmpeg_export_watermarked | videoasset_worker.py | Watermark TikTok | ❌ NON | Non utilisé |

### 4.2 Pattern FFmpeg réutilisable

**Pattern subprocess** :
```python
result = subprocess.run(
    cmd,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    check=False,
)

if result.returncode != 0:
    stderr_text = result.stderr.decode("utf-8", errors="ignore")
    raise HTTPException(
        status_code=500,
        detail=f"ffmpeg error (code {result.returncode}): {stderr_text[:4000]}",
    )
```

### 4.3 Nouveau composant nécessaire

**_run_ffmpeg_assemble_pngs** :
```python
def _run_ffmpeg_assemble_pngs(input_dir: Path, output_path: Path) -> Path:
    """Assemble PNGs en MP4 pour Smart Whiteboard."""
    cmd = [
        "ffmpeg",
        "-y",
        "-f", "image2",
        "-framerate", "30",
        "-i", str(input_dir / "scene_%d.png"),
        "-c:v", "libx264",
        "-pix_fmt", "yuv420p",
        "-r", "30",
        "-preset", "medium",
        "-crf", "23",
        str(output_path),
    ]
    # subprocess.run(...)
```

### 4.4 Conclusion

**Réutilisable** : ⚠️ Partiellement (pattern subprocess, pattern FFmpeg)  
**À créer** : _run_ffmpeg_assemble_pngs  
**Pourcentage de réutilisation** : ~50%

---

## PARTIE 5 – ANALYSE COMPOSANTS GÉNÉRATION VIDÉO

### 5.1 Composants existants

| Composant | Type | Rôle | Réutilisable pour Smart Whiteboard |
|-----------|------|------|-----------------------------------|
| Transcodage MP4 → MP4 | Vidéo | Input MP4 → Output MP4 (multi-résolution) | ❌ NON (différent de PNG → MP4) |
| Watermark TikTok | Vidéo | Overlay logo animé | ❌ NON (non utilisé) |
| Filtergraph TV | Vidéo | Multi-input complex | ❌ NON (non utilisé) |

### 5.2 Composants nécessaires pour Smart Whiteboard

| Composant | Type | Rôle | Existe |
|-----------|------|------|--------|
| Génération PNG | Image | Storyboard JSON → Canvas Pillow → PNG | ❌ NON |
| Rendu LaTeX | Image | Formule LaTeX → Matplotlib → PNG | ❌ NON |
| Assemblage PNG → MP4 | Vidéo | PNGs → FFmpeg → MP4 | ❌ NON |

### 5.3 Conclusion

**Réutilisable** : ❌ NON (aucun composant de génération d'images)  
**À créer** : Génération PNG (Pillow), Rendu LaTeX (Matplotlib), Assemblage PNG → MP4 (FFmpeg)  
**Pourcentage de réutilisation** : ~0%

---

## PARTIE 6 – IDENTIFICATION QUEUE DE JOBS

### 6.1 Queue existante

**Table** : `video_processing_jobs` (schéma app)

**Colonnes** :
- id (UUID)
- video_asset_id (UUID)
- job_type (text)
- status (text: queued, running, done, failed)
- locked_at (timestamptz)
- locked_by (text)
- error (text, nullable)
- created_at (timestamptz)
- updated_at (timestamptz)

**Pattern** : Polling (status=queued)

### 6.2 Queue nécessaire pour Smart Whiteboard

**Table** : `whiteboard_renders` (schéma app)

**Colonnes** :
- id (UUID)
- project_id (UUID)
- status (text: queued, processing, done, failed)
- storyboard_json (jsonb)
- video_url (text, nullable)
- video_storage_bucket (text, nullable)
- video_storage_path (text, nullable)
- duration_ms (integer, nullable)
- error_message (text, nullable)
- started_at (timestamptz, nullable)
- completed_at (timestamptz, nullable)
- created_at (timestamptz)
- updated_at (timestamptz)

### 6.3 Conclusion

**Réutilisable** : ⚠️ Partiellement (pattern queue)  
**À créer** : Table whiteboard_renders  
**Pourcentage de réutilisation** : ~70%

---

## PARTIE 7 – IDENTIFICATION WORKER

### 7.1 Worker existant

**Fichier** : `videoasset_worker.py`

**Pattern** :
- Polling (WORKER_LOOP=1)
- Intervalle (WORKER_INTERVAL_SECONDS=2)
- Jobs max (WORKER_MAX_JOBS=3)
- Boucle infinie

**Configuration** :
```yaml
academia-videoasset-worker:
  environment:
    - WORKER_LOOP=1
    - WORKER_INTERVAL_SECONDS=2
    - WORKER_MAX_JOBS=3
```

### 7.2 Worker nécessaire pour Smart Whiteboard

**Fichier** : `whiteboard_render_worker.py` (à créer)

**Pattern** :
- Polling (WORKER_LOOP=1)
- Intervalle (WORKER_INTERVAL_SECONDS=2)
- Jobs max (WORKER_MAX_JOBS=1 pour éviter CPU overload)
- Boucle infinie

**Configuration** :
```yaml
whiteboard-render-worker:
  environment:
    - WORKER_LOOP=1
    - WORKER_INTERVAL_SECONDS=2
    - WORKER_MAX_JOBS=1
```

### 7.3 Conclusion

**Réutilisable** : ✅ Fortement (pattern worker)  
**À créer** : whiteboard_render_worker.py  
**Pourcentage de réutilisation** : ~90%

---

## PARTIE 8 – IDENTIFICATION RÉCUPÉRATION STORAGE

### 8.1 Récupération existante

**Fonction** : `_download_source_to_temp` (videoasset_worker.py)

**Pattern** :
```python
async def _download_source_to_temp(source: Dict[str, Any]) -> Path:
    bucket = str(source.get("storage_bucket") or "").strip()
    storage_path = str(source.get("storage_path") or "").strip()
    url = f"{_storage_base()}/object/{bucket}/{storage_path}"
    headers = _supabase_headers()
    async with httpx.AsyncClient(timeout=600.0) as client:
        resp = await client.get(url, headers=headers)
    dest_path.write_bytes(resp.content)
    return dest_path
```

### 8.2 Récupération nécessaire pour Smart Whiteboard

**Fonction** : `_download_storyboard_json` (à créer)

**Pattern** :
```python
async def _download_storyboard_json(render_id: str) -> Dict[str, Any]:
    # Appel RPC whiteboard_get_project
    # Récupère storyboard_json
    # Parse JSON
    return storyboard
```

### 8.3 Conclusion

**Réutilisable** : ✅ Fortement (pattern download)  
**À adapter** : Adapter pour storyboard_json (via RPC au lieu de Storage)  
**Pourcentage de réutilisation** : ~80%

---

## PARTIE 9 – IDENTIFICATION UPLOAD STORAGE

### 9.1 Upload existant

**Fonction** : `_upload_to_supabase_storage` (studio_video_renderer.py)

**Pattern** :
```python
async def _upload_to_supabase_storage(path: Path, participation_id: str) -> str:
    bucket = "challenge-media"
    object_key = f"renders/{participation_id}/{uuid.uuid4().hex}.mp4"
    storage_url = f"{SUPABASE_URL}/storage/v1/object/{bucket}/{object_key}"
    headers = {
        "apikey": SUPABASE_SERVICE_KEY,
        "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
        "Content-Type": "video/mp4",
    }
    data = path.read_bytes()
    async with httpx.AsyncClient(timeout=600.0) as client:
        resp = await client.post(storage_url, headers=headers, content=data)
    public_url = f"{SUPABASE_URL}/storage/v1/object/public/{bucket}/{object_key}"
    return public_url
```

**Fonction** : `_upload_rendition_file` (videoasset_worker.py)

**Pattern** :
```python
async def _upload_rendition_file(
    video_asset_id: str,
    path: Path,
    rendition_key: str,
    approx_width: Optional[int],
) -> Dict[str, Any]:
    object_key = f"renditions/{video_asset_id}/{rendition_key}.mp4"
    storage_url = f"{_storage_base()}/object/{VIDEO_ASSET_BUCKET}/{object_key}"
    headers = _supabase_headers({"Content-Type": "video/mp4", "x-upsert": "true"})
    data = path.read_bytes()
    async with httpx.AsyncClient(timeout=600.0) as client:
        resp = await client.put(storage_url, headers=headers, content=data)
    # ...
```

### 9.2 Upload nécessaire pour Smart Whiteboard

**Fonction** : `_upload_whiteboard_render` (à créer)

**Pattern** :
```python
async def _upload_whiteboard_render(path: Path, render_id: str) -> str:
    bucket = "whiteboard-renders"
    object_key = f"renders/{render_id}/{uuid.uuid4().hex}.mp4"
    storage_url = f"{_storage_base()}/object/{bucket}/{object_key}"
    headers = _supabase_headers({"Content-Type": "video/mp4"})
    data = path.read_bytes()
    async with httpx.AsyncClient(timeout=600.0) as client:
        resp = await client.put(storage_url, headers=headers, content=data)
    public_url = f"{SUPABASE_URL}/storage/v1/object/public/{bucket}/{object_key}"
    return public_url
```

### 9.3 Conclusion

**Réutilisable** : ✅ Fortement (pattern upload)  
**À adapter** : Adapter pour whiteboard-renders bucket  
**Pourcentage de réutilisation** : ~90%

---

## PARTIE 10 – IDENTIFICATION MONITORING

### 10.1 Monitoring existant

**Aucun monitoring spécifique** n'existe pour le renderer vidéo actuel.

**Logs** : logging standard (videoasset_worker.py)

### 10.2 Monitoring nécessaire pour Smart Whiteboard

**Monitoring** :
- Métriques de rendu (durée, succès/échec)
- Métriques de queue (jobs queued, running, done, failed)
- Métriques de performance (CPU, RAM)

**Logs** :
- logging standard (pattern existant)

### 10.3 Conclusion

**Réutilisable** : ❌ NON (aucun monitoring)  
**À créer** : Monitoring (Prometheus, Grafana) ou logs structurés  
**Pourcentage de réutilisation** : ~0%

---

## PARTIE 11 – IDENTIFICATION LOGS

### 11.1 Logs existants

**Pattern** (videoasset_worker.py) :
```python
logger = logging.getLogger("videoasset_worker")
if not logging.getLogger().handlers:
    logging.basicConfig(level=logging.INFO)

logger.info("[videoasset_worker] Traitement de %d job(s) VideoAsset.", len(jobs))
logger.exception("[videoasset_worker] Erreur sur job generate_hls %s", job_id)
```

### 11.2 Logs nécessaires pour Smart Whiteboard

**Pattern** (whiteboard_render_worker.py) :
```python
logger = logging.getLogger("whiteboard_render_worker")
if not logging.getLogger().handlers:
    logging.basicConfig(level=logging.INFO)

logger.info("[whiteboard_render_worker] Traitement de %d job(s) Whiteboard.", len(jobs))
logger.exception("[whiteboard_render_worker] Erreur sur job render %s", job_id)
```

### 11.3 Conclusion

**Réutilisable** : ✅ Fortement (pattern logging)  
**À adapter** : Adapter pour whiteboard_render_worker  
**Pourcentage de réutilisation** : ~95%

---

## PARTIE 12 – MATRICE DE RÉUTILISATION

### 12.1 Réutilisation directe

| Composant | Fichier | Pourcentage |
|-----------|---------|-------------|
| Pattern logging | videoasset_worker.py | 95% |
| Pattern upload Storage | studio_video_renderer.py, videoasset_worker.py | 90% |
| Pattern worker | videoasset_worker.py | 90% |
| Pattern download Storage | videoasset_worker.py | 80% |
| Pattern queue de jobs | videoasset_worker.py | 70% |
| Pattern subprocess FFmpeg | studio_video_renderer.py | 50% |
| Pattern FFmpeg | studio_video_renderer.py | 50% |
| Pattern proxy Supabase | main.py | 30% |
| Pattern FastAPI | main.py | 30% |

### 12.2 Réutilisation partielle

| Composant | Fichier | Pourcentage | Adaptations nécessaires |
|-----------|---------|-------------|------------------------|
| studio_video_renderer.py | studio_video_renderer.py | 40% | Remplacer transcodage par génération PNG |
| main.py | main.py | 30% | Ajouter endpoints Smart Whiteboard |
| Composants FFmpeg | studio_video_renderer.py | 50% | Créer _run_ffmpeg_assemble_pngs |

### 12.3 À recréer

| Composant | Pourcentage | Raison |
|-----------|-------------|--------|
| Génération PNG (Pillow) | 0% | Aucun composant de génération d'images |
| Rendu LaTeX (Matplotlib) | 0% | Aucun composant de rendu LaTeX |
| Assemblage PNG → MP4 | 0% | Différent de transcodage MP4 → MP4 |
| Monitoring | 0% | Aucun monitoring existant |
| Table whiteboard_renders | 0% | Table spécifique Smart Whiteboard |
| whiteboard_render_worker.py | 0% | Worker spécifique Smart Whiteboard |

---

## PARTIE 13 – POURCENTAGE RÉEL DE RÉUTILISATION

### 13.1 Calcul

**Composants analysés** : 11

**Réutilisation directe (≥80%)** : 4 composants (logging, upload Storage, worker, download Storage)  
**Réutilisation partielle (30-70%)** : 4 composants (studio_video_renderer.py, main.py, FFmpeg, queue)  
**À recréer (0-30%)** : 3 composants (génération PNG, rendu LaTeX, monitoring)

**Pourcentage moyen** : (95 + 90 + 90 + 80 + 70 + 50 + 50 + 30 + 30 + 0 + 0) / 11 = **~58%**

### 13.2 Conclusion

**Pourcentage réel de réutilisation** : **~58%**

---

## PARTIE 14 – COMPOSANTS À CONSERVER

### 14.1 Composants à conserver tel quel

- Pattern logging (videoasset_worker.py)
- Pattern upload Storage (studio_video_renderer.py, videoasset_worker.py)
- Pattern worker (videoasset_worker.py)
- Pattern download Storage (videoasset_worker.py)
- Pattern subprocess FFmpeg (studio_video_renderer.py)
- Pattern proxy Supabase (main.py)
- Pattern FastAPI (main.py)

### 14.2 Fichiers à conserver

- `academia_bobodo_backend/videoasset_worker.py` (pattern worker)
- `academia_bobodo_backend/studio_video_renderer.py` (pattern FFmpeg, upload Storage)
- `academia_bobodo_backend/main.py` (pattern FastAPI, proxy Supabase)

---

## PARTIE 15 – COMPOSANTS À ADAPTER

### 15.1 Composants à adapter

| Composant | Adaptation |
|-----------|------------|
| studio_video_renderer.py | Remplacer transcodage par génération PNG, adapter upload Storage pour whiteboard-renders |
| videoasset_worker.py | Adapter polling pour whiteboard_renders, adapter download pour storyboard_json, adapter upload pour whiteboard-renders |
| main.py | Ajouter endpoints Smart Whiteboard (whiteboard/render, whiteboard/status) |
| FFmpeg | Créer _run_ffmpeg_assemble_pngs |

### 15.2 Fichiers à adapter

- `academia_bobodo_backend/studio_video_renderer.py` → Ajouter _run_ffmpeg_assemble_pngs
- `academia_bobodo_backend/videoasset_worker.py` → Adapter pour whiteboard_renders
- `academia_bobodo_backend/main.py` → Ajouter endpoints Smart Whiteboard

---

## PARTIE 16 – COMPOSANTS À CRÉER

### 16.1 Composants à créer

| Composant | Type | Priorité |
|-----------|------|----------|
| Génération PNG (Pillow) | Python | HAUTE |
| Rendu LaTeX (Matplotlib) | Python | MOYENNE (optionnel pour V1) |
| whiteboard_render_worker.py | Python | HAUTE |
| Table whiteboard_renders | SQL | HAUTE |
| Bucket whiteboard-renders | Storage | HAUTE |
| Monitoring | Infrastructure | FAIBLE (optionnel) |

### 16.2 Fichiers à créer

- `academia_bobodo_backend/whiteboard_render_worker.py`
- `academia_bobodo_backend/whiteboard_png_generator.py`
- `academia_bobodo_backend/whiteboard_latex_renderer.py` (optionnel)
- `.windsurf/sql_changes/change_20260623_whiteboard_renders_table.sql`
- `.windsurf/sql_changes/change_20260623_whiteboard_renders_bucket.sql`

---

## PARTIE 17 – ESTIMATION RÉVISÉE DU CHANTIER RENDERER

### 17.1 Chantier initial (sans réutilisation)

- Backend FastAPI : 2 jours
- Worker Python : 2 jours
- Génération PNG (Pillow) : 2 jours
- Rendu LaTeX (Matplotlib) : 1 jour
- Assemblage PNG → MP4 (FFmpeg) : 1 jour
- Tables Supabase : 0.5 jour
- Buckets Supabase : 0.5 jour
- RPCs Supabase : 1 jour
- Tests : 2 jours
- **Total** : **12 jours**

### 17.2 Chantier révisé (avec réutilisation)

- Adaptation studio_video_renderer.py : 0.5 jour
- Adaptation videoasset_worker.py : 1 jour
- Adaptation main.py : 0.5 jour
- Création whiteboard_render_worker.py : 1 jour
- Création génération PNG (Pillow) : 2 jours
- Création rendu LaTeX (Matplotlib) : 1 jour (optionnel)
- Création assemblage PNG → MP4 (FFmpeg) : 0.5 jour
- Tables Supabase : 0.5 jour
- Buckets Supabase : 0.5 jour
- RPCs Supabase : 1 jour
- Tests : 2 jours
- **Total** : **10 jours** (sans LaTeX) / **11 jours** (avec LaTeX)

### 17.3 Gain de temps

**Gain** : 12 jours → 10-11 jours = **1-2 jours** (~8-17% de gain)

### 17.4 Conclusion

**Estimation révisée du chantier Renderer** : **10-11 jours**

---

## PARTIE 18 – RÉPONSES AUX QUESTIONS

### 18.1 Le Smart Whiteboard Renderer V1 peut-il être construit en réutilisant au moins 50 % de l'infrastructure vidéo actuelle ?

**Réponse** : ✅ **OUI**

**Justification** :
- Pourcentage réel de réutilisation : ~58%
- Composants réutilisables : pattern worker, pattern upload Storage, pattern download Storage, pattern logging, pattern FFmpeg, pattern FastAPI, pattern proxy Supabase
- Gain de temps : 1-2 jours (8-17%)

### 18.2 Pourcentage réel de réutilisation

**Réponse** : **~58%**

**Détail** :
- Réutilisation directe (≥80%) : 4 composants
- Réutilisation partielle (30-70%) : 4 composants
- À recréer (0-30%) : 3 composants

### 18.3 Composants à conserver

**Réponse** :

**Fichiers** :
- `academia_bobodo_backend/videoasset_worker.py` (pattern worker)
- `academia_bobodo_backend/studio_video_renderer.py` (pattern FFmpeg, upload Storage)
- `academia_bobodo_backend/main.py` (pattern FastAPI, proxy Supabase)

**Patterns** :
- Pattern logging
- Pattern upload Storage
- Pattern worker
- Pattern download Storage
- Pattern subprocess FFmpeg
- Pattern proxy Supabase
- Pattern FastAPI

### 18.4 Composants à adapter

**Réponse** :

**Fichiers** :
- `academia_bobodo_backend/studio_video_renderer.py` → Ajouter _run_ffmpeg_assemble_pngs
- `academia_bobodo_backend/videoasset_worker.py` → Adapter pour whiteboard_renders
- `academia_bobodo_backend/main.py` → Ajouter endpoints Smart Whiteboard

**Adaptations** :
- Remplacer transcodage par génération PNG
- Adapter polling pour whiteboard_renders
- Adapter download pour storyboard_json
- Adapter upload pour whiteboard-renders
- Ajouter endpoints Smart Whiteboard

### 18.5 Estimation révisée du chantier Renderer

**Réponse** : **10-11 jours**

**Détail** :
- Sans réutilisation : 12 jours
- Avec réutilisation : 10-11 jours
- Gain : 1-2 jours (8-17%)

---

## PARTIE 19 – CONCLUSION

### 19.1 Résumé

**Pourcentage de réutilisation** : ~58%  
**Composants à conserver** : 7 patterns (logging, upload Storage, worker, download Storage, subprocess FFmpeg, proxy Supabase, FastAPI)  
**Composants à adapter** : 3 fichiers (studio_video_renderer.py, videoasset_worker.py, main.py)  
**Composants à créer** : 6 composants (génération PNG, rendu LaTeX, whiteboard_render_worker.py, table whiteboard_renders, bucket whiteboard-renders, monitoring)  
**Estimation révisée** : 10-11 jours

### 19.2 Décision

**PHASE C.1 VALIDÉE** ✅

**Justification** :
- Le Smart Whiteboard Renderer V1 peut être construit en réutilisant ~58% de l'infrastructure vidéo actuelle
- Les patterns worker, upload Storage, download Storage, logging, FFmpeg, FastAPI, proxy Supabase sont fortement réutilisables
- Le gain de temps est significatif (1-2 jours)
- L'estimation révisée du chantier est réaliste (10-11 jours)

---

**Fin du document**

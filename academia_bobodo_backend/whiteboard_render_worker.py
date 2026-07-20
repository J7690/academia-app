"""
Whiteboard Render Worker - Phase C.3
Worker pour le traitement des jobs de rendu Smart Whiteboard
Basé sur le pattern de videoasset_worker.py
"""

from __future__ import annotations

import asyncio
import logging
import os
import subprocess
import tempfile
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional

import httpx
from dotenv import load_dotenv

from whiteboard_png_renderer import render_storyboard_to_pngs
from whiteboard_ffmpeg_assembler import assemble_pngs_to_mp4
from whiteboard_upload_renderer import upload_mp4_to_storage

# Vision Engine (Phase B) — rendu HTML/Playwright/KaTeX
try:
    import sys
    sys.path.insert(0, "/opt/whiteboard-worker/vision_engine")
    from whiteboard_scene_engine import render_storyboard_to_pngs_vision
    _HAS_VISION = True
except ImportError:
    _HAS_VISION = False

# Narration Audio (Phase G) — TTS gTTS + mixage FFmpeg
try:
    import whiteboard_narration
    _HAS_NARRATION = True
except ImportError:
    _HAS_NARRATION = False

# Configuration
load_dotenv()

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_KEY = os.getenv("SUPABASE_SERVICE_KEY")
WHITEBOARD_BUCKET = "whiteboard-renders"
WHITEBOARD_TABLE = "whiteboard_renders"

WORKER_LOOP = (os.getenv("WORKER_LOOP") or "").strip().lower() in {"1", "true", "yes"}
WORKER_INTERVAL_SECONDS = float((os.getenv("WORKER_INTERVAL_SECONDS") or "2").strip() or "2")
WORKER_MAX_JOBS = int((os.getenv("WORKER_MAX_JOBS") or "1").strip() or "1")

# Feature flag: "vision" = HTML/Playwright/KaTeX, "legacy" = Pillow text-on-image
RENDERER_ENGINE = (os.getenv("RENDERER_ENGINE") or "vision").strip().lower()

SUPABASE_HTTP_TIMEOUT = 600.0

# Logging
logger = logging.getLogger("whiteboard_render_worker")
if not logging.getLogger().handlers:
    logging.basicConfig(level=logging.INFO)


def _rest_base() -> str:
    return f"{SUPABASE_URL.rstrip('/')}/rest/v1"


def _storage_base() -> str:
    return f"{SUPABASE_URL.rstrip('/')}/storage/v1"


def _supabase_headers(extra: Optional[Dict[str, str]] = None) -> Dict[str, str]:
    headers = {
        "apikey": SUPABASE_SERVICE_KEY,
        "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
        "Content-Type": "application/json",
    }
    if extra:
        headers.update(extra)
    return headers


async def _fetch_queued_jobs(limit: int = 5) -> List[Dict[str, Any]]:
    """Récupère les jobs en attente (status=queued) via RPC spécifique"""
    rpc_url = f"{SUPABASE_URL.rstrip('/')}/rest/v1/rpc/whiteboard_fetch_queued_jobs"
    async with httpx.AsyncClient(timeout=SUPABASE_HTTP_TIMEOUT) as client:
        resp = await client.post(rpc_url, headers=_supabase_headers(), json={"p_limit": limit})
    resp.raise_for_status()
    return resp.json()


async def _mark_job_processing(job_id: str) -> None:
    """Marque un job comme processing via RPC spécifique"""
    rpc_url = f"{SUPABASE_URL.rstrip('/')}/rest/v1/rpc/whiteboard_mark_processing"
    async with httpx.AsyncClient(timeout=SUPABASE_HTTP_TIMEOUT) as client:
        resp = await client.post(rpc_url, headers=_supabase_headers(), json={"p_job_id": job_id})
    resp.raise_for_status()


async def _mark_job_done(job_id: str, video_url: str, duration_ms: int) -> None:
    """Marque un job comme done via RPC spécifique"""
    rpc_url = f"{SUPABASE_URL.rstrip('/')}/rest/v1/rpc/whiteboard_mark_done"
    async with httpx.AsyncClient(timeout=SUPABASE_HTTP_TIMEOUT) as client:
        resp = await client.post(rpc_url, headers=_supabase_headers(), json={
            "p_job_id": job_id,
            "p_video_url": video_url,
            "p_duration_ms": duration_ms
        })
    resp.raise_for_status()


async def _mark_job_failed(job_id: str, error_message: str) -> None:
    """Marque un job comme failed via RPC spécifique"""
    rpc_url = f"{SUPABASE_URL.rstrip('/')}/rest/v1/rpc/whiteboard_mark_failed"
    async with httpx.AsyncClient(timeout=SUPABASE_HTTP_TIMEOUT) as client:
        resp = await client.post(rpc_url, headers=_supabase_headers(), json={
            "p_job_id": job_id,
            "p_error_message": error_message
        })
    resp.raise_for_status()


async def _process_single_job(job: Dict[str, Any]) -> None:
    """Traite un seul job de rendu"""
    job_id = job["id"]
    storyboard_json = job.get("storyboard")
    
    if not storyboard_json:
        await _mark_job_failed(job_id, "storyboard_json is empty")
        return
    
    try:
        # Marquer comme processing
        await _mark_job_processing(job_id)
        logger.info(f"[whiteboard_render_worker] Processing job {job_id}")
        
        # Créer un répertoire temporaire
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_path = Path(temp_dir)
            
            # Générer les PNGs (Vision Engine ou Legacy Pillow)
            use_vision = RENDERER_ENGINE == "vision" and _HAS_VISION
            engine_name = "vision" if use_vision else "legacy"
            logger.info(f"[whiteboard_render_worker] Generating PNGs for job {job_id} (engine={engine_name})")
            if use_vision:
                png_paths = render_storyboard_to_pngs_vision(storyboard_json, temp_path)
            else:
                png_paths = render_storyboard_to_pngs(storyboard_json, temp_path)

            # Durées par scène : on RESPECTE le storyboard (duration_ms par scène).
            # 1 PNG == 1 scène (aligné 1:1). Repli 5000 ms si une scène n'en a pas.
            storyboard = storyboard_json if isinstance(storyboard_json, dict) else {}
            scenes = storyboard.get("scenes", []) or []
            DEFAULT_SCENE_MS = 5000
            scene_durations_ms: List[int] = []
            for scene in scenes:
                raw = (scene or {}).get("duration_ms") if isinstance(scene, dict) else None
                try:
                    ms = int(raw)
                    if ms <= 0:
                        ms = DEFAULT_SCENE_MS
                except (TypeError, ValueError):
                    ms = DEFAULT_SCENE_MS
                scene_durations_ms.append(ms)
            # Aligner strictement sur le nombre de PNG réellement produits
            if len(scene_durations_ms) < len(png_paths):
                scene_durations_ms += [DEFAULT_SCENE_MS] * (len(png_paths) - len(scene_durations_ms))
            scene_durations_ms = scene_durations_ms[:len(png_paths)]
            scene_durations_sec = [ms / 1000.0 for ms in scene_durations_ms]

            # Narration audio (Phase G) : si narration_mode == 'tts', on génère
            # une piste TTS et on ajuste les durées de scène pour la synchroniser.
            narration_mode = str(storyboard.get("narration_mode") or "none").strip().lower()
            narration_audio_path = None
            if (
                narration_mode == "tts"
                and _HAS_NARRATION
                and whiteboard_narration.is_available()
            ):
                logger.info(f"[whiteboard_render_worker] Generating TTS narration for job {job_id}")
                narration_result = whiteboard_narration.build_narration(
                    storyboard, scene_durations_sec, temp_path
                )
                if narration_result is not None:
                    narration_audio_path, adjusted_durations = narration_result
                    scene_durations_sec = adjusted_durations[:len(png_paths)]
                    scene_durations_ms = [int(s * 1000) for s in scene_durations_sec]
                    logger.info(
                        f"[whiteboard_render_worker] Narration ready, adjusted durations "
                        f"total={sum(scene_durations_sec):.1f}s"
                    )
                else:
                    logger.warning(f"[whiteboard_render_worker] Narration unavailable for job {job_id}")

            # Assembler les PNGs en MP4 (durées respectées)
            logger.info(f"[whiteboard_render_worker] Assembling MP4 for job {job_id}")
            mp4_path = assemble_pngs_to_mp4(png_paths, temp_path, durations=scene_durations_sec)

            # Injecter la narration si disponible
            if narration_audio_path is not None:
                logger.info(f"[whiteboard_render_worker] Muxing narration into video for job {job_id}")
                muxed_path = temp_path / "final_with_audio.mp4"
                try:
                    mp4_path = whiteboard_narration.mux_audio_into_video(
                        Path(mp4_path), narration_audio_path, muxed_path
                    )
                except Exception as e:
                    logger.warning(f"[whiteboard_render_worker] Mux failed, using silent video: {e}")

            # Uploader le MP4
            logger.info(f"[whiteboard_render_worker] Uploading MP4 for job {job_id}")
            video_url = await upload_mp4_to_storage(mp4_path, job_id)

            # Durée réelle = somme des durées de scène effectivement rendues
            duration_ms = int(sum(scene_durations_ms))
            
            # Marquer comme done
            await _mark_job_done(job_id, video_url, duration_ms)
            logger.info(f"[whiteboard_render_worker] Job {job_id} completed successfully")
            
    except Exception as e:
        logger.exception(f"[whiteboard_render_worker] Error processing job {job_id}")
        await _mark_job_failed(job_id, str(e))


async def run_once(max_jobs: int = 1) -> None:
    """Exécute une seule itération du worker"""
    jobs = await _fetch_queued_jobs(limit=max_jobs)
    logger.info(f"[whiteboard_render_worker] Found {len(jobs)} queued job(s)")
    
    for job in jobs:
        await _process_single_job(job)


async def _loop() -> None:
    """Boucle infinie du worker"""
    while True:
        try:
            await run_once(max_jobs=WORKER_MAX_JOBS)
        except Exception:
            logger.exception("[whiteboard_render_worker] Loop iteration failed")
        await asyncio.sleep(max(WORKER_INTERVAL_SECONDS, 0.5))


if __name__ == "__main__":
    if not WORKER_LOOP:
        asyncio.run(run_once())
    else:
        asyncio.run(_loop())

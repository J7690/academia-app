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

# Configuration
load_dotenv()

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_KEY = os.getenv("SUPABASE_SERVICE_KEY")
WHITEBOARD_BUCKET = "whiteboard-renders"
WHITEBOARD_TABLE = "whiteboard_renders"

WORKER_LOOP = (os.getenv("WORKER_LOOP") or "").strip().lower() in {"1", "true", "yes"}
WORKER_INTERVAL_SECONDS = float((os.getenv("WORKER_INTERVAL_SECONDS") or "2").strip() or "2")
WORKER_MAX_JOBS = int((os.getenv("WORKER_MAX_JOBS") or "1").strip() or "1")

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
            
            # Générer les PNGs
            logger.info(f"[whiteboard_render_worker] Generating PNGs for job {job_id}")
            png_paths = render_storyboard_to_pngs(storyboard_json, temp_path)
            
            # Assembler les PNGs en MP4
            logger.info(f"[whiteboard_render_worker] Assembling MP4 for job {job_id}")
            mp4_path = assemble_pngs_to_mp4(png_paths, temp_path)
            
            # Uploader le MP4
            logger.info(f"[whiteboard_render_worker] Uploading MP4 for job {job_id}")
            video_url = await upload_mp4_to_storage(mp4_path, job_id)
            
            # Calculer la durée (estimation basée sur le nombre de scènes)
            # Pour V1, on estime 5 secondes par scène
            storyboard = storyboard_json if isinstance(storyboard_json, dict) else {}
            scenes = storyboard.get("scenes", [])
            duration_ms = len(scenes) * 5000
            
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

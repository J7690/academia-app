"""
Whiteboard Render Worker - Phase C.3
Worker pour le traitement des jobs de rendu Smart Whiteboard
Basé sur le pattern de videoasset_worker.py
"""

from __future__ import annotations

import asyncio
import json
import logging
import os
import socket
import tempfile
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

# Moteur STUDIO Remotion (cahier continu, annotations, rappel, Kokoro).
# Opt-in via storyboard.engine == 'remotion'. Repli automatique sinon.
try:
    import sys as _sys_remotion
    _sys_remotion.path.insert(0, os.environ.get("REMOTION_ENGINE_DIR", "/opt/whiteboard-engine-remotion"))
    from render_bridge import render_storyboard_remotion
    _HAS_REMOTION = True
except Exception:
    _HAS_REMOTION = False


def _storyboard_total_ms(storyboard: Dict[str, Any]) -> int:
    """Somme des durées de scène (ms), repli 5000 ms/scène."""
    total = 0
    for sc in (storyboard.get("scenes") or []):
        try:
            v = int((sc or {}).get("duration_ms") or 5000)
            total += v if v > 0 else 5000
        except (TypeError, ValueError):
            total += 5000
    return total or 5000

# Logging (doit être configuré avant toute opération)
logger = logging.getLogger("whiteboard_render_worker")
if not logging.getLogger().handlers:
    logging.basicConfig(level=logging.INFO)


BASE_DIR = Path(__file__).resolve().parent
load_dotenv(BASE_DIR / ".env", override=True)

SUPABASE_URL = (os.getenv("SUPABASE_URL") or "").rstrip("/")
SUPABASE_SERVICE_KEY = os.getenv("SUPABASE_SERVICE_KEY") or ""
SUPABASE_PROXY_URL = (os.getenv("SUPABASE_PROXY_URL") or "").rstrip("/")

WHITEBOARD_BUCKET = "whiteboard-renders"
WHITEBOARD_TABLE = "whiteboard_renders"

WORKER_LOOP = (os.getenv("WORKER_LOOP") or "").strip().lower() in {"1", "true", "yes"}
WORKER_INTERVAL_SECONDS = float((os.getenv("WORKER_INTERVAL_SECONDS") or "2").strip() or "2")
WORKER_MAX_JOBS = int((os.getenv("WORKER_MAX_JOBS") or "1").strip() or "1")

# Feature flag: "vision" = HTML/Playwright/KaTeX, "legacy" = Pillow text-on-image
RENDERER_ENGINE = (os.getenv("RENDERER_ENGINE") or "vision").strip().lower()

SUPABASE_HTTP_TIMEOUT = float((os.getenv("SUPABASE_HTTP_TIMEOUT") or "600").strip() or "600")


def _check_config() -> None:
    if not SUPABASE_SERVICE_KEY:
        raise RuntimeError("SUPABASE_SERVICE_KEY manquant pour whiteboard_render_worker.")
    if not SUPABASE_URL and not SUPABASE_PROXY_URL:
        raise RuntimeError("SUPABASE_URL ou SUPABASE_PROXY_URL manquant pour whiteboard_render_worker.")


def _diagnose_supabase_dns() -> None:
    if not SUPABASE_URL:
        return
    try:
        host = SUPABASE_URL.replace("https://", "").replace("http://", "").split("/")[0]
        socket.getaddrinfo(host, 443)
    except Exception as exc:
        logger.warning("[whiteboard_render_worker] DNS resolution failed for SUPABASE host: %s (%s)", SUPABASE_URL, exc)


def _rest_base() -> str:
    if SUPABASE_PROXY_URL:
        return f"{SUPABASE_PROXY_URL}/supabase/rest/v1"
    return f"{SUPABASE_URL}/rest/v1"


def _storage_base() -> str:
    if SUPABASE_PROXY_URL:
        return f"{SUPABASE_PROXY_URL}/supabase/storage/v1"
    return f"{SUPABASE_URL}/storage/v1"


def _supabase_headers(extra: Optional[Dict[str, str]] = None) -> Dict[str, str]:
    headers = {
        "apikey": SUPABASE_SERVICE_KEY,
        "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
        "Accept": "application/json",
        "Content-Type": "application/json",
    }
    if extra:
        headers.update(extra)
    return headers


async def _fetch_queued_jobs(limit: int = 5) -> List[Dict[str, Any]]:
    """Récupère les jobs en attente (status=queued) via RPC spécifique"""
    _check_config()
    _diagnose_supabase_dns()
    rpc_url = f"{_rest_base()}/rpc/whiteboard_fetch_queued_jobs"
    try:
        async with httpx.AsyncClient(timeout=SUPABASE_HTTP_TIMEOUT) as client:
            resp = await client.post(rpc_url, headers=_supabase_headers(), json={"p_limit": limit})
    except Exception as exc:
        logger.exception("[whiteboard_render_worker] whiteboard_fetch_queued_jobs HTTP error: %s", exc)
        return []
    if resp.status_code >= 400:
        logger.error("[whiteboard_render_worker] whiteboard_fetch_queued_jobs failed: %s %s", resp.status_code, resp.text[:400])
        return []
    try:
        data = resp.json()
    except ValueError:
        logger.error("[whiteboard_render_worker] whiteboard_fetch_queued_jobs invalid JSON")
        return []
    if isinstance(data, list):
        return [row for row in data if isinstance(row, dict)]
    return []


async def _call_status_rpc(rpc_name: str, payload: Dict[str, Any]) -> None:
    _check_config()
    rpc_url = f"{_rest_base()}/rpc/{rpc_name}"
    try:
        async with httpx.AsyncClient(timeout=SUPABASE_HTTP_TIMEOUT) as client:
            resp = await client.post(rpc_url, headers=_supabase_headers(), json=payload)
    except Exception as exc:
        logger.exception("[whiteboard_render_worker] %s HTTP error: %s", rpc_name, exc)
        raise RuntimeError(f"{rpc_name} HTTP error: {exc}") from exc
    if resp.status_code >= 400:
        logger.error("[whiteboard_render_worker] %s failed: %s %s", rpc_name, resp.status_code, resp.text[:400])
        raise RuntimeError(f"{rpc_name} returned {resp.status_code}: {resp.text[:200]}")


async def _mark_job_processing(job_id: str) -> None:
    """Marque un job comme processing via RPC spécifique"""
    await _call_status_rpc("whiteboard_mark_processing", {"p_job_id": job_id})


async def _mark_job_done(job_id: str, video_url: str, duration_ms: int) -> None:
    """Marque un job comme done via RPC spécifique"""
    await _call_status_rpc("whiteboard_mark_done", {
        "p_job_id": job_id,
        "p_video_url": video_url,
        "p_duration_ms": duration_ms,
    })


async def _mark_job_failed(job_id: str, error_message: str) -> None:
    """Marque un job comme failed via RPC spécifique"""
    await _call_status_rpc("whiteboard_mark_failed", {
        "p_job_id": job_id,
        "p_error_message": error_message[:1000],
    })


def _parse_storyboard(value: Any) -> Dict[str, Any]:
    """Normalise le storyboard reçu depuis la DB (dict ou JSON string) en dict."""
    if isinstance(value, dict):
        return value
    if isinstance(value, str):
        try:
            parsed = json.loads(value)
        except json.JSONDecodeError as exc:
            raise ValueError(f"storyboard is not valid JSON: {exc}") from exc
        if not isinstance(parsed, dict):
            raise ValueError("storyboard JSON must be an object")
        return parsed
    raise ValueError("storyboard must be a dict or a JSON string")


async def _process_single_job(job: Dict[str, Any], worker_id: str) -> None:
    """Traite un seul job de rendu"""
    job_id = str(job.get("id") or "").strip()
    if not job_id:
        logger.warning("[whiteboard_render_worker] Job sans id, ignoré.")
        return

    raw_storyboard = job.get("storyboard")
    if not raw_storyboard:
        logger.error("[whiteboard_render_worker] Job %s: storyboard_json is empty", job_id)
        await _mark_job_failed(job_id, "storyboard_json is empty")
        return

    try:
        storyboard = _parse_storyboard(raw_storyboard)
    except ValueError as exc:
        logger.exception("[whiteboard_render_worker] Job %s: storyboard invalide", job_id)
        await _mark_job_failed(job_id, f"storyboard invalide: {exc}")
        return

    # Claim the job
    try:
        await _mark_job_processing(job_id)
    except Exception as exc:
        logger.warning("[whiteboard_render_worker] Job %s: impossible de le réserver (%s), on skip.", job_id, exc)
        return

    logger.info("[whiteboard_render_worker] Processing job %s on %s", job_id, worker_id)

    try:
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_path = Path(temp_dir)

            # ── Moteur STUDIO Remotion (opt-in) ────────────────────────────
            # IMPORTANT : si engine=remotion est demandé, on NE retombe PAS en
            # silence sur vision/legacy. On échoue bruyamment (visible dans
            # error_message) pour ne jamais rendre avec le mauvais moteur.
            if str(storyboard.get("engine") or "").strip().lower() == "remotion":
                if not _HAS_REMOTION:
                    raise RuntimeError(
                        "engine=remotion demandé mais Remotion indisponible "
                        f"(_HAS_REMOTION=False, REMOTION_ENGINE_DIR={os.environ.get('REMOTION_ENGINE_DIR')}). "
                        "Redémarre le worker après un import propre de render_bridge."
                    )
                logger.info("[whiteboard_render_worker] Job %s: moteur REMOTION", job_id)
                mp4_path = render_storyboard_remotion(storyboard, temp_path)
                video_url = await upload_mp4_to_storage(mp4_path, job_id)
                await _mark_job_done(job_id, video_url, _storyboard_total_ms(storyboard))
                logger.info("[whiteboard_render_worker] Job %s completed (remotion)", job_id)
                return

            # Générer les PNGs (Vision Engine ou Legacy Pillow)
            use_vision = RENDERER_ENGINE == "vision" and _HAS_VISION
            engine_name = "vision" if use_vision else "legacy"
            logger.info("[whiteboard_render_worker] Generating PNGs for job %s (engine=%s)", job_id, engine_name)
            if use_vision:
                png_paths = render_storyboard_to_pngs_vision(storyboard, temp_path)
            else:
                png_paths = render_storyboard_to_pngs(storyboard, temp_path)

            # Durées par scène : on RESPECTE le storyboard (duration_ms par scène).
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
                and getattr(whiteboard_narration, "is_available", lambda: False)()
            ):
                logger.info("[whiteboard_render_worker] Generating TTS narration for job %s", job_id)
                narration_result = whiteboard_narration.build_narration(
                    storyboard, scene_durations_sec, temp_path
                )
                if narration_result is not None:
                    narration_audio_path, adjusted_durations = narration_result
                    scene_durations_sec = adjusted_durations[:len(png_paths)]
                    scene_durations_ms = [int(s * 1000) for s in scene_durations_sec]
                    logger.info(
                        "[whiteboard_render_worker] Narration ready, adjusted durations total=%.1fs",
                        sum(scene_durations_sec),
                    )
                else:
                    logger.warning("[whiteboard_render_worker] Narration unavailable for job %s", job_id)

            # Assembler les PNGs en MP4 (durées respectées)
            logger.info("[whiteboard_render_worker] Assembling MP4 for job %s", job_id)
            mp4_path = assemble_pngs_to_mp4(png_paths, temp_path, durations=scene_durations_sec)

            # Injecter la narration si disponible
            if narration_audio_path is not None:
                logger.info("[whiteboard_render_worker] Muxing narration into video for job %s", job_id)
                muxed_path = temp_path / "final_with_audio.mp4"
                try:
                    mp4_path = whiteboard_narration.mux_audio_into_video(
                        Path(mp4_path), narration_audio_path, muxed_path
                    )
                except Exception as exc:
                    logger.warning("[whiteboard_render_worker] Mux failed, using silent video: %s", exc)

            # Uploader le MP4
            logger.info("[whiteboard_render_worker] Uploading MP4 for job %s", job_id)
            video_url = await upload_mp4_to_storage(mp4_path, job_id)

            # Durée réelle = somme des durées de scène effectivement rendues
            duration_ms = int(sum(scene_durations_ms))

            await _mark_job_done(job_id, video_url, duration_ms)
            logger.info("[whiteboard_render_worker] Job %s completed successfully", job_id)

    except Exception as exc:
        logger.exception("[whiteboard_render_worker] Error processing job %s", job_id)
        try:
            await _mark_job_failed(job_id, str(exc))
        except Exception:
            logger.exception("[whiteboard_render_worker] Failed to mark job %s as failed", job_id)


async def run_once(max_jobs: Optional[int] = None) -> None:
    """Exécute une seule itération du worker"""
    max_jobs = max_jobs if max_jobs is not None else WORKER_MAX_JOBS
    _check_config()
    _diagnose_supabase_dns()
    worker_id = f"whiteboard_render_worker_{os.getpid()}_{asyncio.get_event_loop().time():.0f}"
    jobs = await _fetch_queued_jobs(limit=max_jobs)
    logger.info("[whiteboard_render_worker] Found %d queued job(s)", len(jobs))

    for job in jobs:
        try:
            await _process_single_job(job, worker_id)
        except Exception:
            logger.exception("[whiteboard_render_worker] Uncaught error in job iteration")


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

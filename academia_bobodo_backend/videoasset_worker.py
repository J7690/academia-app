from __future__ import annotations

import asyncio
import logging
import os
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


logger = logging.getLogger("videoasset_worker")
if not logging.getLogger().handlers:
    logging.basicConfig(level=logging.INFO)

BASE_DIR = Path(__file__).resolve().parent
load_dotenv(BASE_DIR / ".env", override=True)

SUPABASE_URL = (os.getenv("SUPABASE_URL") or "").rstrip("/")
SUPABASE_SERVICE_KEY = os.getenv("SUPABASE_SERVICE_KEY") or ""
VIDEO_ASSET_BUCKET = os.getenv("VIDEO_ASSET_BUCKET", "video-assets")


def _check_config() -> None:
    if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
        raise RuntimeError("SUPABASE_URL ou SUPABASE_SERVICE_KEY manquant pour videoasset_worker.")


def _supabase_headers(extra: Optional[Dict[str, str]] = None) -> Dict[str, str]:
    headers: Dict[str, str] = {
        "apikey": SUPABASE_SERVICE_KEY,
        "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
        "Accept": "application/json",
    }
    if extra:
        headers.update(extra)
    return headers


async def _fetch_queued_jobs(limit: int = 5) -> List[Dict[str, Any]]:
    _check_config()
    url = f"{SUPABASE_URL}/rest/v1/app.video_processing_jobs"
    params = {
        "status": "eq.queued",
        "order": "created_at.asc",
        "limit": str(limit),
    }
    async with httpx.AsyncClient(timeout=10.0) as client:
        resp = await client.get(url, headers=_supabase_headers(), params=params)

    if resp.status_code >= 400:
        logger.error("[videoasset_worker] fetch_queued_jobs failed: %s %s", resp.status_code, resp.text[:400])
        return []

    try:
        data = resp.json()
    except ValueError:
        logger.error("[videoasset_worker] fetch_queued_jobs invalid JSON")
        return []

    if isinstance(data, list):
        return [row for row in data if isinstance(row, dict)]

    return []


async def _update_job(job_id: str, fields: Dict[str, Any]) -> None:
    if not fields:
        return
    _check_config()
    url = f"{SUPABASE_URL}/rest/v1/app.video_processing_jobs"
    params = {"id": f"eq.{job_id}"}
    async with httpx.AsyncClient(timeout=10.0) as client:
        await client.patch(url, headers=_supabase_headers({"Content-Type": "application/json"}), params=params, json=fields)


async def _mark_job_running(job_id: str, worker_id: str) -> None:
    now = datetime.now(timezone.utc).isoformat()
    await _update_job(
        job_id,
        {
            "status": "running",
            "locked_at": now,
            "locked_by": worker_id,
        },
    )


async def _mark_job_done(job_id: str) -> None:
    await _update_job(job_id, {"status": "done", "error": None})


async def _mark_job_failed(job_id: str, message: str) -> None:
    await _update_job(job_id, {"status": "failed", "error": message[:1000]})


async def _get_primary_source_for_asset(video_asset_id: str) -> Optional[Dict[str, Any]]:
    _check_config()
    url = f"{SUPABASE_URL}/rest/v1/app.video_sources"
    params = {
        "video_asset_id": f"eq.{video_asset_id}",
        "select": "id,storage_bucket,storage_path",
        "limit": "1",
    }
    async with httpx.AsyncClient(timeout=10.0) as client:
        resp = await client.get(url, headers=_supabase_headers(), params=params)

    if resp.status_code >= 400:
        logger.error(
            "[videoasset_worker] get_primary_source_for_asset failed: %s %s",
            resp.status_code,
            resp.text[:400],
        )
        return None

    try:
        data = resp.json()
    except ValueError:
        return None

    if isinstance(data, list) and data:
        row = data[0]
        if isinstance(row, dict):
            return row
    return None


async def _download_source_to_temp(source: Dict[str, Any]) -> Path:
    _check_config()
    bucket = str(source.get("storage_bucket") or "").strip()
    storage_path = str(source.get("storage_path") or "").strip()
    if not bucket or not storage_path:
        raise RuntimeError("storage_bucket ou storage_path manquant pour la source vidéo.")

    url = f"{SUPABASE_URL}/storage/v1/object/{bucket}/{storage_path}"
    headers = _supabase_headers()

    tmp_dir = Path(tempfile.gettempdir())
    file_name = f"videoasset_input_{uuid.uuid4().hex}.mp4"
    dest_path = tmp_dir / file_name

    async with httpx.AsyncClient(timeout=600.0) as client:
        resp = await client.get(url, headers=headers)

    if resp.status_code >= 400:
        raise RuntimeError(
            f"Erreur lors du téléchargement de la source VideoAsset ({resp.status_code})."
        )

    dest_path.write_bytes(resp.content)
    return dest_path


async def _delete_existing_mp4_renditions(video_asset_id: str) -> None:
    _check_config()
    url = f"{SUPABASE_URL}/rest/v1/app.video_renditions"
    params = {
        "video_asset_id": f"eq.{video_asset_id}",
        "kind": "eq.mp4",
    }
    async with httpx.AsyncClient(timeout=10.0) as client:
        resp = await client.delete(url, headers=_supabase_headers())
    if resp.status_code >= 400:
        logger.error(
            "[videoasset_worker] delete_existing_mp4_renditions failed: %s %s",
            resp.status_code,
            resp.text[:400],
        )


async def _upload_rendition_file(
    video_asset_id: str,
    path: Path,
    rendition_key: str,
    approx_width: Optional[int],
) -> Dict[str, Any]:
    _check_config()
    if not path.exists():
        raise RuntimeError(f"Rendition file missing: {path}")

    object_key = f"renditions/{video_asset_id}/{rendition_key}.mp4"
    storage_url = f"{SUPABASE_URL}/storage/v1/object/{VIDEO_ASSET_BUCKET}/{object_key}"

    headers = _supabase_headers({"Content-Type": "video/mp4"})
    data = path.read_bytes()

    async with httpx.AsyncClient(timeout=600.0) as client:
        resp = await client.post(storage_url, headers=headers, content=data)

    if resp.status_code >= 400:
        try:
            body = resp.json()
        except ValueError:
            body = {"raw": resp.text[:400]}
        raise RuntimeError(
            f"Erreur upload rendition VideoAsset ({resp.status_code}): {body}"
        )

    public_url = f"{SUPABASE_URL}/storage/v1/object/public/{VIDEO_ASSET_BUCKET}/{object_key}"

    row: Dict[str, Any] = {
        "video_asset_id": video_asset_id,
        "rendition_key": rendition_key,
        "kind": "mp4",
        "storage_bucket": VIDEO_ASSET_BUCKET,
        "storage_path": object_key,
        "public_url_hint": public_url,
        "status": "ready",
    }
    if approx_width is not None:
        row["width"] = approx_width

    return row


async def _insert_video_renditions(rows: List[Dict[str, Any]]) -> None:
    if not rows:
        return
    _check_config()
    url = f"{SUPABASE_URL}/rest/v1/app.video_renditions"
    headers = _supabase_headers({"Content-Type": "application/json", "Prefer": "return=minimal"})
    async with httpx.AsyncClient(timeout=10.0) as client:
        resp = await client.post(url, headers=headers, json=rows)
    if resp.status_code >= 400:
        logger.error(
            "[videoasset_worker] insert_video_renditions failed: %s %s",
            resp.status_code,
            resp.text[:400],
        )
        raise RuntimeError("Echec de l'insertion des renditions VideoAsset.")


async def _mark_video_asset_ready(video_asset_id: str) -> None:
    _check_config()
    url = f"{SUPABASE_URL}/rest/v1/app.video_assets"
    params = {"id": f"eq.{video_asset_id}"}
    body = {"status": "ready"}
    async with httpx.AsyncClient(timeout=10.0) as client:
        resp = await client.patch(
            url,
            headers=_supabase_headers({"Content-Type": "application/json"}),
            params=params,
            json=body,
        )
    if resp.status_code >= 400:
        logger.error(
            "[videoasset_worker] mark_video_asset_ready failed: %s %s",
            resp.status_code,
            resp.text[:400],
        )
        raise RuntimeError("Impossible de passer le VideoAsset en status=ready.")


async def _process_generate_hls_job(job: Dict[str, Any], worker_id: str) -> None:
    video_asset_id = str(job.get("video_asset_id") or "").strip()
    job_id = str(job.get("id") or "").strip()
    if not video_asset_id or not job_id:
        raise RuntimeError("Job generate_hls sans video_asset_id ou id.")

    await _mark_job_running(job_id, worker_id)

    source = await _get_primary_source_for_asset(video_asset_id)
    if not source:
        raise RuntimeError("Aucune source trouvée pour ce VideoAsset.")

    input_path: Optional[Path] = None
    out_main: Optional[Path] = None
    out_480: Optional[Path] = None
    out_360: Optional[Path] = None
    out_240: Optional[Path] = None

    try:
        input_path = await _download_source_to_temp(source)

        # Génère des MP4 ultra-compatibles (mêmes profils que le Studio)
        out_main = _run_ffmpeg_transcode(input_path)
        out_480 = _run_ffmpeg_transcode_480p(input_path)
        out_360 = _run_ffmpeg_transcode_360p(input_path)
        out_240 = _run_ffmpeg_transcode_240p(input_path)

        await _delete_existing_mp4_renditions(video_asset_id)

        rows: List[Dict[str, Any]] = []
        if out_main is not None:
            rows.append(await _upload_rendition_file(video_asset_id, out_main, "mp4_main", approx_width=720))
        if out_480 is not None:
            rows.append(await _upload_rendition_file(video_asset_id, out_480, "mp4_480p", approx_width=480))
        if out_360 is not None:
            rows.append(await _upload_rendition_file(video_asset_id, out_360, "mp4_360p", approx_width=360))
        if out_240 is not None:
            rows.append(await _upload_rendition_file(video_asset_id, out_240, "mp4_240p", approx_width=240))

        if not rows:
            raise RuntimeError("Aucune rendition MP4 générée pour VideoAsset.")

        await _insert_video_renditions(rows)
        await _mark_video_asset_ready(video_asset_id)
        await _mark_job_done(job_id)
        logger.info(
            "[videoasset_worker] VideoAsset %s: renditions MP4 créées (%d) et asset READY.",
            video_asset_id,
            len(rows),
        )
    except Exception as exc:  # noqa: BLE001
        logger.exception("[videoasset_worker] Erreur sur job generate_hls %s", job_id)
        await _mark_job_failed(job_id, str(exc))
        raise
    finally:
        for p in (input_path, out_main, out_480, out_360, out_240):
            try:
                if p is not None and isinstance(p, Path) and p.exists():
                    p.unlink()
            except Exception:  # noqa: BLE001
                pass


async def _process_single_job(job: Dict[str, Any], worker_id: str) -> None:
    job_type = str(job.get("job_type") or "").strip().lower()
    job_id = str(job.get("id") or "").strip()

    if not job_type or not job_id:
        logger.warning("[videoasset_worker] Job sans job_type ou id, on le marque failed.")
        await _mark_job_failed(job_id or "", "invalid_job_payload")
        return

    if job_type == "generate_hls":
        await _process_generate_hls_job(job, worker_id)
        return

    # Pour l'instant, les autres types de job sont marqués comme terminés sans effet.
    logger.info("[videoasset_worker] Job %s ignoré (type=%s), marqué done.", job_id, job_type)
    await _mark_job_done(job_id)


async def run_once(max_jobs: int = 3) -> None:
    """Traite quelques jobs de video_processing_jobs (mode one-shot).

    Conçu pour être appelé par un cron ou un worker externe, sans boucle infinie.
    """

    _check_config()
    worker_id = f"videoasset_worker_{uuid.uuid4().hex[:8]}"
    jobs = await _fetch_queued_jobs(limit=max_jobs)
    if not jobs:
        logger.info("[videoasset_worker] Aucun job video_processing_jobs en file d'attente.")
        return

    logger.info("[videoasset_worker] Traitement de %d job(s) VideoAsset.", len(jobs))

    for job in jobs:
        try:
            await _process_single_job(job, worker_id)
        except Exception:  # noqa: BLE001
            # L'erreur est déjà loggée dans _process_generate_hls_job ou _mark_job_failed
            continue


if __name__ == "__main__":  # pragma: no cover
    asyncio.run(run_once())

#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import subprocess
import tempfile
import time
import uuid
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, Optional, Tuple

import requests

from supabase_auto_manager import SupabaseAutoManager


@dataclass(frozen=True)
class SupabaseConfig:
    url: str
    service_key: str


def get_supabase_service_config() -> SupabaseConfig:
    url = (os.environ.get("SUPABASE_URL") or "").strip().rstrip("/")
    key = (os.environ.get("SUPABASE_SERVICE_KEY") or os.environ.get("SUPABASE_SERVICE_ROLE_KEY") or "").strip()
    if not url or not key:
        m = SupabaseAutoManager()
        url = (m.url or "").strip().rstrip("/")
        key = (m.service_key or "").strip()
    if not url or not key:
        raise RuntimeError("Missing SUPABASE_URL / SUPABASE_SERVICE_KEY")
    return SupabaseConfig(url=url, service_key=key)


def _headers(cfg: SupabaseConfig) -> Dict[str, str]:
    return {
        "apikey": cfg.service_key,
        "Authorization": f"Bearer {cfg.service_key}",
        "Content-Type": "application/json",
        "Accept": "application/json",
    }


def _headers_app(cfg: SupabaseConfig) -> Dict[str, str]:
    return {
        **_headers(cfg),
        "Accept-Profile": "app",
        "Content-Profile": "app",
    }


def call_rpc(cfg: SupabaseConfig, name: str, payload: Dict[str, Any], timeout: int = 60) -> Any:
    resp = requests.post(
        f"{cfg.url}/rest/v1/rpc/{name}",
        headers=_headers(cfg),
        json=payload,
        timeout=timeout,
    )
    if not resp.ok:
        raise RuntimeError(f"rpc_failed name={name} http={resp.status_code} body={(resp.text or '')[:1200]}")
    return resp.json()


def postgrest_insert(cfg: SupabaseConfig, table: str, row: Dict[str, Any]) -> Dict[str, Any]:
    resp = requests.post(
        f"{cfg.url}/rest/v1/{table}",
        headers={**_headers_app(cfg), "Prefer": "return=representation"},
        json=row,
        timeout=60,
    )
    if not resp.ok:
        raise RuntimeError(f"insert_failed table={table} http={resp.status_code} body={(resp.text or '')[:1200]}")
    data = resp.json()
    if isinstance(data, list) and data and isinstance(data[0], dict):
        return data[0]
    raise RuntimeError(f"insert_unexpected_response table={table}")


def postgrest_patch(cfg: SupabaseConfig, table: str, filters: str, patch: Dict[str, Any]) -> None:
    resp = requests.patch(
        f"{cfg.url}/rest/v1/{table}?{filters}",
        headers=_headers_app(cfg),
        json=patch,
        timeout=60,
    )
    if not resp.ok:
        raise RuntimeError(f"patch_failed table={table} http={resp.status_code} body={(resp.text or '')[:1200]}")


def storage_upload(cfg: SupabaseConfig, bucket: str, path: str, file_path: Path, content_type: str) -> str:
    # Upsert upload to storage
    object_path = f"{bucket}/{path.lstrip('/')}"
    url = f"{cfg.url}/storage/v1/object/{object_path}"

    with file_path.open("rb") as f:
        resp = requests.post(
            url,
            headers={
                "apikey": cfg.service_key,
                "Authorization": f"Bearer {cfg.service_key}",
                "Content-Type": content_type,
                "x-upsert": "true",
            },
            data=f,
            timeout=180,
        )

    if not resp.ok:
        raise RuntimeError(f"storage_upload_failed http={resp.status_code} body={(resp.text or '')[:900]}")

    # Public URL (bucket is public per step8 bucket creation)
    return f"{cfg.url}/storage/v1/object/public/{bucket}/{path.lstrip('/')}"


def download_to_temp(url: str) -> Path:
    cleaned = (url or "").strip()
    if not cleaned:
        raise ValueError("missing_input_url")

    resp = requests.get(cleaned, timeout=180)
    if resp.status_code >= 400:
        raise RuntimeError(f"download_failed http={resp.status_code}")

    tmp_dir = Path(tempfile.mkdtemp(prefix="videoasset_step8_"))
    dest = tmp_dir / f"input_{uuid.uuid4().hex}.bin"
    dest.write_bytes(resp.content)
    return dest


def run_ffmpeg_transcode_mp4(input_path: Path) -> Path:
    out = input_path.parent / "out_720p.mp4"
    cmd = [
        "ffmpeg",
        "-y",
        "-i",
        str(input_path),
        "-vf",
        "scale='min(1280,iw)':-2",
        "-c:v",
        "libx264",
        "-profile:v",
        "baseline",
        "-level",
        "3.1",
        "-preset",
        "veryfast",
        "-crf",
        "23",
        "-movflags",
        "+faststart",
        "-c:a",
        "aac",
        "-b:a",
        "128k",
        str(out),
    ]
    result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    if result.returncode != 0 or not out.exists():
        err = result.stderr.decode("utf-8", errors="ignore")
        raise RuntimeError(f"ffmpeg_transcode_failed: {err[:1200]}")
    return out


def run_ffmpeg_poster(input_path: Path) -> Path:
    out = input_path.parent / "poster.jpg"
    cmd = [
        "ffmpeg",
        "-y",
        "-i",
        str(input_path),
        "-ss",
        "0",
        "-vframes",
        "1",
        "-q:v",
        "2",
        str(out),
    ]
    result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    if result.returncode != 0 or not out.exists():
        err = result.stderr.decode("utf-8", errors="ignore")
        raise RuntimeError(f"ffmpeg_poster_failed: {err[:1200]}")
    return out


def write_rendition_row(
    cfg: SupabaseConfig,
    *,
    video_asset_id: str,
    rendition_key: str,
    kind: str,
    bucket: str,
    storage_path: str,
    public_url: str,
    width: Optional[int] = None,
    height: Optional[int] = None,
    codec: Optional[str] = None,
) -> None:
    row = {
        "video_asset_id": video_asset_id,
        "rendition_key": rendition_key,
        "kind": kind,
        "width": width,
        "height": height,
        "codec": codec,
        "storage_bucket": bucket,
        "storage_path": storage_path,
        "public_url_hint": public_url,
        "status": "ready",
    }
    # upsert by (video_asset_id, rendition_key)
    resp = requests.post(
        f"{cfg.url}/rest/v1/video_renditions",
        headers={
            **_headers_app(cfg),
            "Prefer": "resolution=merge-duplicates",
        },
        json=row,
        timeout=60,
    )
    if not resp.ok:
        raise RuntimeError(f"rendition_upsert_failed http={resp.status_code} body={(resp.text or '')[:1200]}")


def process_one_job(cfg: SupabaseConfig, worker_id: str) -> Dict[str, Any]:
    claim = call_rpc(
        cfg,
        "app_videoasset_claim_next_job",
        {"p_locked_by": worker_id, "p_job_types": ["generate_mp4", "generate_thumbs", "extract_metadata"]},
        timeout=60,
    )

    job = claim.get("job") if isinstance(claim, dict) else None
    if not job:
        return {"did_work": False}

    job_id = job.get("id")
    video_asset_id = job.get("video_asset_id")
    job_type = job.get("job_type")

    source = claim.get("source") if isinstance(claim, dict) else None
    input_url = claim.get("input_url") if isinstance(claim, dict) else None

    if isinstance(source, dict) and source.get("storage_bucket") and source.get("storage_path"):
        bucket = str(source.get("storage_bucket"))
        path = str(source.get("storage_path"))
        input_url = f"{cfg.url}/storage/v1/object/public/{bucket}/{path.lstrip('/')}"

    if not isinstance(input_url, str) or not input_url.strip():
        call_rpc(cfg, "app_videoasset_complete_job", {"p_job_id": job_id, "p_status": "failed", "p_error": "no_input_url"})
        return {"did_work": True, "job_id": job_id, "status": "failed", "error": "no_input_url"}

    tmp_input: Optional[Path] = None
    try:
        tmp_input = download_to_temp(input_url)

        out_bucket = "video-assets"
        base_prefix = f"renditions/{video_asset_id}"

        if job_type == "generate_mp4":
            out_mp4 = run_ffmpeg_transcode_mp4(tmp_input)
            storage_path = f"{base_prefix}/mp4_720p.mp4"
            public_url = storage_upload(cfg, out_bucket, storage_path, out_mp4, "video/mp4")
            write_rendition_row(
                cfg,
                video_asset_id=str(video_asset_id),
                rendition_key="mp4_720p",
                kind="mp4",
                bucket=out_bucket,
                storage_path=storage_path,
                public_url=public_url,
                codec="h264",
            )

        elif job_type == "generate_thumbs":
            poster = run_ffmpeg_poster(tmp_input)
            storage_path = f"{base_prefix}/poster.jpg"
            public_url = storage_upload(cfg, out_bucket, storage_path, poster, "image/jpeg")
            write_rendition_row(
                cfg,
                video_asset_id=str(video_asset_id),
                rendition_key="poster",
                kind="poster",
                bucket=out_bucket,
                storage_path=storage_path,
                public_url=public_url,
            )

            thumb_path = f"{base_prefix}/thumb.jpg"
            thumb_url = storage_upload(cfg, out_bucket, thumb_path, poster, "image/jpeg")
            write_rendition_row(
                cfg,
                video_asset_id=str(video_asset_id),
                rendition_key="thumb",
                kind="thumbnail",
                bucket=out_bucket,
                storage_path=thumb_path,
                public_url=thumb_url,
            )

        else:
            # extract_metadata is best-effort; keep simple for now
            pass

        call_rpc(cfg, "app_videoasset_complete_job", {"p_job_id": job_id, "p_status": "done", "p_error": None})
        return {"did_work": True, "job_id": job_id, "status": "done", "job_type": job_type, "video_asset_id": video_asset_id}

    except Exception as exc:
        err = str(exc)
        try:
            call_rpc(cfg, "app_videoasset_complete_job", {"p_job_id": job_id, "p_status": "failed", "p_error": err})
        except Exception:
            pass
        return {"did_work": True, "job_id": job_id, "status": "failed", "job_type": job_type, "error": err[:1200]}

    finally:
        if tmp_input is not None:
            try:
                tmp_dir = tmp_input.parent
                if tmp_input.exists():
                    tmp_input.unlink()
                # best-effort cleanup
                for p in tmp_dir.glob("*"):
                    try:
                        p.unlink()
                    except Exception:
                        pass
                try:
                    tmp_dir.rmdir()
                except Exception:
                    pass
            except Exception:
                pass


def main() -> int:
    cfg = get_supabase_service_config()
    worker_id = f"step8-worker-{uuid.uuid4().hex[:8]}"

    max_loops = int(os.environ.get("STEP8_MAX_LOOPS") or "50")
    sleep_s = float(os.environ.get("STEP8_SLEEP_S") or "0.2")

    events = []
    for _ in range(max_loops):
        ev = process_one_job(cfg, worker_id)
        events.append(ev)
        if not ev.get("did_work"):
            break
        time.sleep(sleep_s)

    print(json.dumps({"worker_id": worker_id, "events": events}, ensure_ascii=False, indent=2)[:9000])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

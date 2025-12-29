#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import subprocess
import time
from typing import Any, Dict, List, Optional

import requests

from supabase_auto_manager import SupabaseAutoManager


def run_sql(m: SupabaseAutoManager, sql: str) -> List[Dict[str, Any]]:
    sql_clean = (sql or "").strip()
    if sql_clean.endswith(";"):
        sql_clean = sql_clean[:-1].rstrip()
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    resp = requests.post(url, headers=m.headers, json={"p_sql": sql_clean}, timeout=180)
    resp.raise_for_status()
    data = resp.json()
    if isinstance(data, dict) and data.get("ok") and isinstance(data.get("rows"), list):
        return data["rows"]
    if isinstance(data, dict) and data.get("ok") and data.get("mode") == "exec":
        return []
    if isinstance(data, list):
        return data
    raise RuntimeError(f"admin_execute_sql_failed: {data}")


def main() -> int:
    m = SupabaseAutoManager()

    # Use the same service role config as the rest of the .windsurf tooling
    service_url = (m.url or "").strip().rstrip("/")
    service_key = (m.service_key or "").strip()
    if not service_url or not service_key:
        raise RuntimeError("supabase_auto_manager_missing_service_config")

    # 1) Pick a real existing public mp4 object (challenge-media) as a deterministic input source
    rows = run_sql(
        m,
        """
        SELECT name
        FROM storage.objects
        WHERE bucket_id = 'challenge-media'
          AND name ILIKE 'renders/%'
          AND name ILIKE '%.mp4'
        ORDER BY created_at DESC
        LIMIT 1;
        """.strip(),
    )
    if not rows:
        raise RuntimeError("no_challenge_media_mp4_found")

    src_path = rows[0]["name"]

    # 2) Create a new VideoAsset + source pointing to that object (no legacy touched)
    headers = {
        "apikey": service_key,
        "Authorization": f"Bearer {service_key}",
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Prefer": "return=representation",
        "Accept-Profile": "app",
        "Content-Profile": "app",
    }

    asset_resp = requests.post(
        f"{service_url}/rest/v1/video_assets",
        headers=headers,
        json={"owner_user_id": None, "origin": "step8_verify", "status": "uploaded"},
        timeout=60,
    )
    if not asset_resp.ok:
        raise RuntimeError(f"create_asset_failed http={asset_resp.status_code} body={(asset_resp.text or '')[:1200]}")
    asset_data = asset_resp.json()
    if not (isinstance(asset_data, list) and asset_data and isinstance(asset_data[0], dict) and asset_data[0].get("id")):
        raise RuntimeError("create_asset_unexpected_response")
    video_asset_id = str(asset_data[0]["id"])

    source_resp = requests.post(
        f"{service_url}/rest/v1/video_sources",
        headers=headers,
        json={
            "video_asset_id": video_asset_id,
            "storage_bucket": "challenge-media",
            "storage_path": src_path,
            "ingest_profile": "step8_verify",
        },
        timeout=60,
    )
    if not source_resp.ok:
        raise RuntimeError(f"create_source_failed http={source_resp.status_code} body={(source_resp.text or '')[:1200]}")

    source_data = source_resp.json()
    source_id: Optional[str] = None
    if isinstance(source_data, list) and source_data and isinstance(source_data[0], dict) and source_data[0].get("id"):
        source_id = str(source_data[0]["id"])

    # 3) Enqueue jobs (service_role RPC)
    resp = requests.post(
        f"{service_url}/rest/v1/rpc/app_videoasset_enqueue_processing",
        headers={
            "apikey": service_key,
            "Authorization": f"Bearer {service_key}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
        json={"p_video_asset_id": video_asset_id, "p_job_types": ["generate_mp4", "generate_thumbs"]},
        timeout=60,
    )
    if not resp.ok:
        raise RuntimeError(f"enqueue_failed http={resp.status_code} body={(resp.text or '')[:1000]}")

    # Debug: try claiming a job directly (and immediately release it back to queued if claimed)
    claim_resp = requests.post(
        f"{service_url}/rest/v1/rpc/app_videoasset_claim_next_job",
        headers={
            "apikey": service_key,
            "Authorization": f"Bearer {service_key}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
        json={"p_locked_by": "verify_step8", "p_job_types": ["generate_mp4", "generate_thumbs"]},
        timeout=60,
    )
    claim_body: Any
    try:
        claim_body = claim_resp.json()
    except Exception:
        claim_body = {"_raw": (claim_resp.text or "")[:1200]}

    # If we claimed a job, push it back to queued for the worker run
    claimed_job = claim_body.get("job") if isinstance(claim_body, dict) else None
    if isinstance(claimed_job, dict) and claimed_job.get("id"):
        job_id = str(claimed_job.get("id"))
        run_sql(
            m,
            f"""
            UPDATE app.video_processing_jobs
            SET status = 'queued', locked_at = NULL, locked_by = NULL
            WHERE id = '{job_id}'::uuid
            """.strip(),
        )

    # 4) Run worker locally (process queued jobs)
    env = dict(os.environ)
    env["STEP8_MAX_LOOPS"] = "20"
    env["STEP8_SLEEP_S"] = "0.2"

    worker = subprocess.run(
        ["python", ".windsurf/videoasset_worker_step8.py"],
        cwd=os.getcwd(),
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        check=False,
    )

    # 5) Verify: jobs done and renditions exist
    time.sleep(0.5)

    jobs = run_sql(
        m,
        f"""
        SELECT id::text, job_type, status, attempts, locked_by, locked_at, error, created_at, updated_at
        FROM app.video_processing_jobs
        WHERE video_asset_id = '{video_asset_id}'::uuid
        ORDER BY created_at ASC;
        """.strip(),
    )

    renditions = run_sql(
        m,
        f"""
        SELECT rendition_key, kind, status, storage_bucket, storage_path, public_url_hint
        FROM app.video_renditions
        WHERE video_asset_id = '{video_asset_id}'::uuid
        ORDER BY kind, rendition_key;
        """.strip(),
    )

    asset = run_sql(
        m,
        f"""
        SELECT id::text AS id, status, origin, created_at, updated_at
        FROM app.video_assets
        WHERE id = '{video_asset_id}'::uuid;
        """.strip(),
    )

    out = {
        "video_asset_id": video_asset_id,
        "source_id": source_id,
        "source": {"bucket": "challenge-media", "path": src_path},
        "debug_claim": {
            "http": claim_resp.status_code,
            "body": claim_body,
        },
        "worker_exit_code": worker.returncode,
        "worker_output": worker.stdout[-4000:],
        "asset": asset[0] if asset else None,
        "jobs": jobs,
        "renditions": renditions,
    }

    out_path = ".windsurf/logs/step8_verify_processing.json"
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)

    print(f"[OK] wrote {out_path}")
    print(json.dumps(out, ensure_ascii=False, indent=2)[:9000])

    ok = any(r.get("kind") == "mp4" and r.get("status") == "ready" for r in renditions)
    ok = ok and any(r.get("kind") in ("poster", "thumbnail") and r.get("status") == "ready" for r in renditions)
    ok = ok and all(j.get("status") in ("done", "failed") for j in jobs)

    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())

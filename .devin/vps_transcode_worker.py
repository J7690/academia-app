#!/usr/bin/env python3
"""
VPS Transcode Worker — runs on the Kamatera VPS.
Polls app.video_processing_jobs for 'transcode_resolution' jobs,
downloads source video, runs FFmpeg, uploads result to Supabase Storage,
updates rendition status.

Deploy: scp this file to VPS, run with cron or systemd.
Requires: ffmpeg, python3, requests
"""

import json
import os
import subprocess
import sys
import tempfile
import time
import requests

# --- Config ---
SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

HEADERS = {
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Content-Type": "application/json",
}

POLL_INTERVAL = 10  # seconds


def rpc(name, params=None):
    url = f"{SUPABASE_URL}/rest/v1/rpc/{name}"
    r = requests.post(url, headers=HEADERS, json=params or {}, timeout=60)
    return r.json()


def sql(query):
    return rpc("admin_execute_sql", {"p_sql": query.strip()})


def claim_job():
    """Claim the next queued transcode_resolution job."""
    result = sql("""
        UPDATE app.video_processing_jobs
        SET status = 'processing', locked_at = NOW(), locked_by = 'vps_worker', attempts = attempts + 1
        WHERE id = (
            SELECT id FROM app.video_processing_jobs
            WHERE job_type = 'transcode_resolution' AND status = 'queued'
            ORDER BY created_at ASC
            LIMIT 1
            FOR UPDATE SKIP LOCKED
        )
        RETURNING id, video_asset_id, payload::text
    """)
    if isinstance(result, dict) and result.get("ok") and result.get("mode") == "select":
        rows = result.get("rows", [])
        if rows:
            return rows[0]
    return None


def complete_job(job_id, success, error=None):
    status = "completed" if success else "failed"
    err_sql = f", error = '{error}'" if error else ", error = NULL"
    sql(f"""
        UPDATE app.video_processing_jobs
        SET status = '{status}', updated_at = NOW() {err_sql}
        WHERE id = '{job_id}'
    """)


def update_rendition(rendition_id, status, public_url=None, width=None):
    updates = [f"status = '{status}'"]
    if public_url:
        updates.append(f"public_url_hint = '{public_url}'")
    if width:
        updates.append(f"width = {width}")
    sql(f"""
        UPDATE app.video_renditions
        SET {', '.join(updates)}
        WHERE id = '{rendition_id}'
    """)


def download_file(url, dest_path):
    print(f"  Downloading: {url[:120]}...")
    r = requests.get(url, stream=True, timeout=120)
    r.raise_for_status()
    with open(dest_path, "wb") as f:
        for chunk in r.iter_content(chunk_size=8192):
            f.write(chunk)
    size_mb = os.path.getsize(dest_path) / 1024 / 1024
    print(f"  Downloaded: {size_mb:.1f} MB")


def upload_to_storage(bucket, path, file_path):
    """Upload file to Supabase Storage."""
    print(f"  Uploading to {bucket}/{path}...")
    url = f"{SUPABASE_URL}/storage/v1/object/{bucket}/{path}"
    with open(file_path, "rb") as f:
        r = requests.post(
            url,
            headers={
                "apikey": SERVICE_KEY,
                "Authorization": f"Bearer {SERVICE_KEY}",
                "Content-Type": "video/mp4",
                "x-upsert": "true",
            },
            data=f,
            timeout=300,
        )
    if r.status_code in (200, 201):
        public_url = f"{SUPABASE_URL}/storage/v1/object/public/{bucket}/{path}"
        print(f"  Uploaded OK: {public_url[:100]}...")
        return public_url
    else:
        print(f"  Upload FAILED: {r.status_code} {r.text[:200]}")
        return None


def run_ffmpeg(input_path, output_path, ffmpeg_args):
    """Run FFmpeg with the given args."""
    cmd = f'ffmpeg -y -i "{input_path}" {ffmpeg_args} "{output_path}"'
    print(f"  FFmpeg: {cmd[:200]}...")
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=600)
    if result.returncode != 0:
        print(f"  FFmpeg FAILED: {result.stderr[-500:]}")
        return False
    size_mb = os.path.getsize(output_path) / 1024 / 1024
    print(f"  FFmpeg OK: {size_mb:.1f} MB")
    return True


def process_job(job):
    job_id = job["id"]
    payload = json.loads(job["payload"]) if isinstance(job["payload"], str) else job["payload"]

    source_url = payload.get("source_url", "")
    output_bucket = payload.get("output_bucket", "video-assets")
    output_path = payload.get("output_path", "")
    rendition_id = payload.get("rendition_id", "")
    rendition_key = payload.get("rendition_key", "")
    target_height = payload.get("target_height", 480)
    target_bitrate = payload.get("target_bitrate", "800k")
    ffmpeg_args = payload.get("ffmpeg_args", "")

    print(f"\nProcessing job {job_id}: {rendition_key} ({target_height}p)")

    with tempfile.TemporaryDirectory(prefix="acad_transcode_") as tmpdir:
        input_file = os.path.join(tmpdir, "input.mp4")
        output_file = os.path.join(tmpdir, f"{rendition_key}.mp4")

        try:
            download_file(source_url, input_file)
        except Exception as e:
            print(f"  Download error: {e}")
            update_rendition(rendition_id, "failed")
            complete_job(job_id, False, str(e)[:200])
            return

        if not ffmpeg_args:
            ffmpeg_args = f'-vf "scale=-2:{target_height}" -c:v libx264 -preset fast -b:v {target_bitrate} -c:a aac -b:a 128k -movflags +faststart'

        if not run_ffmpeg(input_file, output_file, ffmpeg_args):
            update_rendition(rendition_id, "failed")
            complete_job(job_id, False, "ffmpeg_failed")
            return

        public_url = upload_to_storage(output_bucket, output_path, output_file)
        if not public_url:
            update_rendition(rendition_id, "failed")
            complete_job(job_id, False, "upload_failed")
            return

        # Probe width from output
        width = None
        try:
            probe = subprocess.run(
                f'ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "{output_file}"',
                shell=True, capture_output=True, text=True, timeout=30
            )
            width = int(probe.stdout.strip())
        except Exception:
            pass

        update_rendition(rendition_id, "ready", public_url, width)
        complete_job(job_id, True)
        print(f"  DONE: {rendition_key} -> {public_url[:80]}...")


def main():
    print("=== Academia VPS Transcode Worker ===")
    print(f"Polling every {POLL_INTERVAL}s for transcode_resolution jobs...")

    while True:
        try:
            job = claim_job()
            if job:
                process_job(job)
            else:
                time.sleep(POLL_INTERVAL)
        except KeyboardInterrupt:
            print("\nStopped.")
            break
        except Exception as e:
            print(f"Worker error: {e}")
            time.sleep(POLL_INTERVAL)


if __name__ == "__main__":
    main()

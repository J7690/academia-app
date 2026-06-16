"""
Deploy fixed video worker to Kamatera VPS.
Fixes:
1. Adds Accept-Profile/Content-Profile: app headers for REST API
2. Supports export_watermarked job type (download source, FFmpeg watermark, upload, create rendition)
3. Fixes column references (no started_at/finished_at)
4. Polls for both transcode_resolution AND export_watermarked jobs
"""
import paramiko
import textwrap

VPS_IP = "185.167.96.214"

WORKER_SCRIPT = r'''#!/usr/bin/env python3
"""Academia Video Worker v3 — supports transcode + export_watermarked"""
import json
import logging
import os
import subprocess
import sys
import time
import urllib.request
import urllib.error
import uuid

SUPABASE_URL = os.environ.get('SUPABASE_URL', '')
SERVICE_KEY = os.environ.get('SUPABASE_SERVICE_KEY', '')
POLL_INTERVAL = int(os.environ.get('POLL_INTERVAL', '10'))
WORK_DIR = '/tmp/academia_worker'
WORKER_ID = f'vps-{uuid.uuid4().hex[:8]}'
WATERMARK_LOGO = '/opt/academia-worker/ACADEMIA_logo1.png'

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[
        logging.FileHandler('/var/log/academia-video-worker.log'),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger('worker')

# REST API headers — use app schema
HEADERS = {
    'apikey': SERVICE_KEY,
    'Authorization': f'Bearer {SERVICE_KEY}',
    'Content-Type': 'application/json',
    'Accept-Profile': 'app',
    'Content-Profile': 'app',
    'Prefer': 'return=representation',
}

HEADERS_MINIMAL = {
    'apikey': SERVICE_KEY,
    'Authorization': f'Bearer {SERVICE_KEY}',
    'Content-Type': 'application/json',
    'Accept-Profile': 'app',
    'Content-Profile': 'app',
    'Prefer': 'return=minimal',
}

def api_get(path):
    url = f'{SUPABASE_URL}/rest/v1/{path}'
    req = urllib.request.Request(url, headers=HEADERS)
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        body = e.read().decode()[:200]
        log.error(f'GET {path}: HTTP {e.code} {body}')
        return None
    except Exception as e:
        log.error(f'GET {path}: {e}')
        return None

def api_patch(path, data):
    url = f'{SUPABASE_URL}/rest/v1/{path}'
    body = json.dumps(data).encode()
    req = urllib.request.Request(url, data=body, headers=HEADERS_MINIMAL, method='PATCH')
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return True
    except urllib.error.HTTPError as e:
        body = e.read().decode()[:200]
        log.error(f'PATCH {path}: HTTP {e.code} {body}')
        return False

def api_post(path, data):
    url = f'{SUPABASE_URL}/rest/v1/{path}'
    body = json.dumps(data).encode()
    req = urllib.request.Request(url, data=body, headers=HEADERS, method='POST')
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        body = e.read().decode()[:200]
        log.error(f'POST {path}: HTTP {e.code} {body}')
        return None

def upload_to_storage(bucket, path, filepath):
    url = f'{SUPABASE_URL}/storage/v1/object/{bucket}/{path}'
    with open(filepath, 'rb') as f:
        data = f.read()
    h = {
        'apikey': SERVICE_KEY,
        'Authorization': f'Bearer {SERVICE_KEY}',
        'Content-Type': 'video/mp4',
        'x-upsert': 'true',
    }
    req = urllib.request.Request(url, data=data, headers=h, method='POST')
    try:
        with urllib.request.urlopen(req, timeout=300) as resp:
            return resp.status in (200, 201)
    except urllib.error.HTTPError as e:
        log.error(f'Upload {bucket}/{path}: HTTP {e.code} {e.read().decode()[:200]}')
        return False

def download_file(url, dest):
    req = urllib.request.Request(url)
    try:
        with urllib.request.urlopen(req, timeout=300) as resp:
            with open(dest, 'wb') as f:
                while True:
                    chunk = resp.read(65536)
                    if not chunk:
                        break
                    f.write(chunk)
        return os.path.exists(dest) and os.path.getsize(dest) > 0
    except Exception as e:
        log.error(f'Download {url[:80]}: {e}')
        return False

def lock_job(job_id, attempts):
    now = time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())
    return api_patch(f'video_processing_jobs?id=eq.{job_id}', {
        'status': 'running',
        'locked_at': now,
        'locked_by': WORKER_ID,
        'attempts': attempts,
        'updated_at': now,
    })

def finish_job(job_id, success, error_msg=None):
    now = time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())
    data = {
        'status': 'done' if success else 'failed',
        'updated_at': now,
    }
    if error_msg:
        data['error'] = str(error_msg)[:500]
    api_patch(f'video_processing_jobs?id=eq.{job_id}', data)

def get_source_url(video_asset_id):
    """Get the public URL of the original source video for a video_asset."""
    sources = api_get(
        f'video_sources?video_asset_id=eq.{video_asset_id}&order=created_at.desc&limit=1'
    )
    if sources and len(sources) > 0:
        src = sources[0]
        # Try public_url_hint first
        hint = (src.get('public_url_hint') or '').strip()
        if hint:
            return hint
        # Build from bucket/path
        bucket = src.get('storage_bucket', '')
        path = src.get('storage_path', '')
        if bucket and path:
            return f'{SUPABASE_URL}/storage/v1/object/public/{bucket}/{path}'
    return None

# ═══════════════════════════════════════════════════════════════════
# JOB: transcode_resolution (existing logic)
# ═══════════════════════════════════════════════════════════════════
def process_transcode_job(job):
    job_id = job['id']
    payload = job.get('payload', {})
    if isinstance(payload, str):
        payload = json.loads(payload)

    source_url = payload.get('source_url', '')
    output_bucket = payload.get('output_bucket', 'video-assets')
    output_path = payload.get('output_path', '')
    ffmpeg_args = payload.get('ffmpeg_args', '')
    rendition_id = payload.get('rendition_id', '')
    rendition_key = payload.get('rendition_key', '')
    target_height = payload.get('target_height', 0)

    if not source_url or not output_path or not ffmpeg_args:
        return False, 'Missing source_url, output_path, or ffmpeg_args in payload'

    os.makedirs(WORK_DIR, exist_ok=True)
    src_file = os.path.join(WORK_DIR, f'src_{job_id}.mp4')
    out_file = os.path.join(WORK_DIR, f'out_{job_id}_{rendition_key}.mp4')

    try:
        log.info(f'Job {job_id}: downloading source...')
        if not download_file(source_url, src_file):
            return False, 'Failed to download source video'

        src_size = os.path.getsize(src_file)
        log.info(f'Job {job_id}: source {src_size/1024:.0f} KB')

        cmd = f'ffmpeg -y -i "{src_file}" {ffmpeg_args} "{out_file}"'
        log.info(f'Job {job_id}: FFmpeg -> {rendition_key}')
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=600)

        if result.returncode != 0:
            err_msg = result.stderr[-500:] if result.stderr else 'Unknown FFmpeg error'
            return False, f'FFmpeg error (code {result.returncode}): {err_msg}'

        if not os.path.exists(out_file) or os.path.getsize(out_file) == 0:
            return False, 'FFmpeg produced no output'

        out_size = os.path.getsize(out_file)
        log.info(f'Job {job_id}: output {out_size/1024:.0f} KB')

        log.info(f'Job {job_id}: uploading to {output_bucket}/{output_path}')
        if not upload_to_storage(output_bucket, output_path, out_file):
            return False, 'Upload to storage failed'

        public_url = f'{SUPABASE_URL}/storage/v1/object/public/{output_bucket}/{output_path}'
        if rendition_id:
            api_patch(
                f'video_renditions?id=eq.{rendition_id}',
                {'status': 'ready', 'public_url_hint': public_url, 'height': target_height}
            )

        log.info(f'Job {job_id}: done ({rendition_key})')
        return True, None

    finally:
        for f in [src_file, out_file]:
            try: os.remove(f)
            except: pass

# ═══════════════════════════════════════════════════════════════════
# JOB: export_watermarked
# Downloads source video, applies animated Academia watermark via FFmpeg,
# uploads result, creates video_rendition entry.
# ═══════════════════════════════════════════════════════════════════
def process_export_watermarked(job):
    job_id = job['id']
    video_asset_id = job.get('video_asset_id', '')

    if not video_asset_id:
        return False, 'Missing video_asset_id'

    # 1. Get source video URL
    source_url = get_source_url(video_asset_id)
    if not source_url:
        return False, 'No source video found for this asset'

    os.makedirs(WORK_DIR, exist_ok=True)
    src_file = os.path.join(WORK_DIR, f'wm_src_{job_id}.mp4')
    out_file = os.path.join(WORK_DIR, f'wm_out_{job_id}.mp4')

    try:
        # 2. Download source
        log.info(f'Job {job_id}: downloading source for watermark...')
        if not download_file(source_url, src_file):
            return False, 'Failed to download source video'

        src_size = os.path.getsize(src_file)
        log.info(f'Job {job_id}: source {src_size/1024:.0f} KB')

        # 3. Check if watermark logo exists
        if not os.path.exists(WATERMARK_LOGO):
            log.warning(f'Job {job_id}: watermark logo not found at {WATERMARK_LOGO}, copying from source')
            # Fallback: just copy source as-is (no watermark available)
            import shutil
            shutil.copy2(src_file, out_file)
        else:
            # 4. Apply animated watermark (TikTok-style: logo moves across screen)
            # Logo moves using sin/cos time-based expressions
            overlay_filter = (
                "[1:v]scale=80:80,format=rgba,colorchannelmixer=aa=0.5[wm];"
                "[0:v][wm]overlay="
                "'main_w/2+main_w/3*sin(t*0.8)-40':"
                "'main_h/2+main_h/4*cos(t*1.1)-40'"
                ":shortest=1[out]"
            )
            cmd = (
                f'ffmpeg -y -i "{src_file}" -i "{WATERMARK_LOGO}" '
                f'-filter_complex "{overlay_filter}" '
                f'-map "[out]" -map 0:a? '
                f'-c:v libx264 -preset fast -crf 23 '
                f'-c:a aac -b:a 128k '
                f'-movflags +faststart '
                f'"{out_file}"'
            )
            log.info(f'Job {job_id}: FFmpeg watermark...')
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=600)

            if result.returncode != 0:
                err_msg = result.stderr[-500:] if result.stderr else 'Unknown FFmpeg error'
                return False, f'FFmpeg watermark error: {err_msg}'

        if not os.path.exists(out_file) or os.path.getsize(out_file) == 0:
            return False, 'FFmpeg watermark produced no output'

        out_size = os.path.getsize(out_file)
        log.info(f'Job {job_id}: watermarked {out_size/1024:.0f} KB')

        # 5. Upload to storage
        output_bucket = 'video-assets'
        output_path = f'exports/{video_asset_id}/watermarked.mp4'
        log.info(f'Job {job_id}: uploading watermarked to {output_bucket}/{output_path}')
        if not upload_to_storage(output_bucket, output_path, out_file):
            return False, 'Upload watermarked video failed'

        public_url = f'{SUPABASE_URL}/storage/v1/object/public/{output_bucket}/{output_path}'

        # 6. Create or update video_rendition entry
        existing = api_get(
            f'video_renditions?video_asset_id=eq.{video_asset_id}&rendition_key=eq.export_watermarked&limit=1'
        )
        if existing and len(existing) > 0:
            api_patch(
                f'video_renditions?id=eq.{existing[0]["id"]}',
                {'status': 'ready', 'public_url_hint': public_url, 'storage_bucket': output_bucket, 'storage_path': output_path}
            )
        else:
            api_post('video_renditions', {
                'video_asset_id': video_asset_id,
                'rendition_key': 'export_watermarked',
                'kind': 'mp4',
                'status': 'ready',
                'storage_bucket': output_bucket,
                'storage_path': output_path,
                'public_url_hint': public_url,
            })

        log.info(f'Job {job_id}: export_watermarked done')
        return True, None

    finally:
        for f in [src_file, out_file]:
            try: os.remove(f)
            except: pass

# ═══════════════════════════════════════════════════════════════════
# MAIN POLL LOOP
# ═══════════════════════════════════════════════════════════════════
def poll_and_process():
    # Pick up queued jobs: export_watermarked, transcode_resolution, generate_mp4
    for job_type in ['export_watermarked', 'transcode_resolution', 'generate_mp4']:
        jobs = api_get(
            f'video_processing_jobs?status=eq.queued&job_type=eq.{job_type}&order=created_at.asc&limit=1'
        )
        if not jobs:
            continue

        job = jobs[0]
        job_id = job['id']
        payload = job.get('payload', {})

        # Skip empty payloads for transcode jobs (not for export_watermarked)
        if job_type != 'export_watermarked' and (not payload or payload == {}):
            log.warning(f'Job {job_id}: empty payload, marking failed')
            finish_job(job_id, False, 'Empty payload')
            return True

        log.info(f'Processing job {job_id} (type={job_type})')

        attempts = (job.get('attempts') or 0) + 1
        lock_job(job_id, attempts)

        try:
            if job_type == 'export_watermarked':
                success, error_msg = process_export_watermarked(job)
            else:
                success, error_msg = process_transcode_job(job)

            finish_job(job_id, success, error_msg)
            if success:
                log.info(f'Job {job_id}: SUCCESS')
            else:
                log.info(f'Job {job_id}: FAILED — {error_msg}')
            return True

        except Exception as e:
            log.error(f'Job {job_id}: exception: {e}')
            finish_job(job_id, False, str(e))
            return True

    return False

def main():
    log.info('=' * 50)
    log.info('Academia Video Worker v3 starting')
    log.info(f'Poll interval: {POLL_INTERVAL}s')
    log.info(f'Worker ID: {WORKER_ID}')
    log.info(f'Watermark logo: {WATERMARK_LOGO} (exists={os.path.exists(WATERMARK_LOGO)})')
    log.info('=' * 50)

    while True:
        try:
            had_work = poll_and_process()
            if not had_work:
                time.sleep(POLL_INTERVAL)
            else:
                time.sleep(1)
        except KeyboardInterrupt:
            log.info('Stopped')
            break
        except Exception as e:
            log.error(f'Unexpected: {e}')
            time.sleep(POLL_INTERVAL * 3)

if __name__ == '__main__':
    main()
'''

def deploy():
    print("Connecting to VPS...")
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(VPS_IP, username='root', password='Wenden@Koote2026', timeout=15)

    # 1. Backup old worker
    print("Backing up old worker...")
    ssh.exec_command("cp /opt/academia-worker/video_worker.py /opt/academia-worker/video_worker.py.bak", timeout=10)

    # 2. Upload new worker
    print("Uploading new worker...")
    sftp = ssh.open_sftp()
    with sftp.file('/opt/academia-worker/video_worker.py', 'w') as f:
        f.write(WORKER_SCRIPT)
    sftp.close()

    # 3. Upload watermark logo if not present
    print("Checking watermark logo...")
    _, stdout, _ = ssh.exec_command("test -f /opt/academia-worker/ACADEMIA_logo1.png && echo EXISTS || echo MISSING", timeout=10)
    logo_status = stdout.read().decode().strip()
    print(f"  Logo: {logo_status}")

    if logo_status == 'MISSING':
        print("  Uploading logo from assets...")
        try:
            sftp = ssh.open_sftp()
            sftp.put(
                r'c:\Users\fasop\AndroidStudioProjects\academia\academia_app\assets\ACADEMIA_logo1.png',
                '/opt/academia-worker/ACADEMIA_logo1.png'
            )
            sftp.close()
            print("  Logo uploaded!")
        except Exception as e:
            print(f"  Logo upload failed: {e}")

    # 4. Restart worker
    print("Restarting worker service...")
    _, stdout, stderr = ssh.exec_command("systemctl restart academia-video-worker && sleep 2 && systemctl is-active academia-video-worker", timeout=15)
    status = stdout.read().decode().strip()
    err = stderr.read().decode().strip()
    print(f"  Status: {status}")
    if err:
        print(f"  Stderr: {err}")

    # 5. Check latest logs
    print("\nLatest logs:")
    _, stdout, _ = ssh.exec_command("tail -10 /var/log/academia-video-worker.log", timeout=10)
    print(stdout.read().decode())

    ssh.close()
    print("DONE!")

if __name__ == '__main__':
    deploy()

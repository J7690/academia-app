"""Fix and redeploy the VPS worker with correct column names."""
import paramiko
import time
import requests
import json

VPS_IP = "185.167.96.214"
VPS_USER = "root"
VPS_PASS = "Wenden@Koote2026"

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

# First, mark old broken jobs as failed
H = {"apikey": SERVICE_KEY, "Authorization": f"Bearer {SERVICE_KEY}", "Content-Type": "application/json", "Accept-Profile": "app", "Content-Profile": "app", "Prefer": "return=minimal"}
print("Cleaning up old broken jobs with empty payloads...")
# Get queued jobs with empty payloads
r = requests.get(
    f"{SUPABASE_URL}/rest/v1/video_processing_jobs?status=eq.queued&payload=eq.{{}}",
    headers={**H, "Prefer": "return=representation"},
)
if r.status_code == 200:
    jobs = r.json()
    print(f"  Found {len(jobs)} jobs with empty payloads")
    for job in jobs:
        jid = job['id']
        requests.patch(
            f"{SUPABASE_URL}/rest/v1/video_processing_jobs?id=eq.{jid}",
            headers=H,
            json={"status": "failed", "error": "Legacy job with empty payload - cannot process"}
        )
        print(f"  Marked {jid} ({job.get('job_type')}) as failed")

# Now write corrected worker
WORKER_SCRIPT = r'''#!/usr/bin/env python3
"""
Academia Video Processing Worker v2
Polls Supabase video_processing_jobs, runs FFmpeg, uploads results.
Table schema: id, video_asset_id, job_type, status, attempts, locked_at, locked_by, payload, error, created_at, updated_at
"""
import os
import sys
import time
import json
import subprocess
import urllib.request
import urllib.error
import logging

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler('/var/log/academia-video-worker.log'),
    ]
)
log = logging.getLogger('video-worker')

SUPABASE_URL = os.environ.get('SUPABASE_URL', '')
SERVICE_KEY = os.environ.get('SUPABASE_SERVICE_KEY', '')
POLL_INTERVAL = 10
WORK_DIR = '/tmp/video_worker'
WORKER_ID = 'kamatera-vps-1'

HEADERS = {
    'apikey': SERVICE_KEY,
    'Authorization': f'Bearer {SERVICE_KEY}',
    'Content-Type': 'application/json',
    'Accept-Profile': 'app',
    'Content-Profile': 'app',
}

def api_get(path):
    url = f'{SUPABASE_URL}/rest/v1/{path}'
    req = urllib.request.Request(url, headers={**HEADERS, 'Prefer': 'return=representation'})
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.loads(resp.read())
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
    req = urllib.request.Request(url, data=body, headers={**HEADERS, 'Prefer': 'return=minimal'}, method='PATCH')
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return True
    except urllib.error.HTTPError as e:
        body = e.read().decode()[:200]
        log.error(f'PATCH {path}: HTTP {e.code} {body}')
        return False

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
    with urllib.request.urlopen(req, timeout=300) as resp:
        with open(dest, 'wb') as f:
            while True:
                chunk = resp.read(65536)
                if not chunk:
                    break
                f.write(chunk)
    return os.path.exists(dest) and os.path.getsize(dest) > 0

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
        # Download source
        log.info(f'Job {job_id}: downloading source...')
        if not download_file(source_url, src_file):
            return False, 'Failed to download source video'
        
        src_size = os.path.getsize(src_file)
        log.info(f'Job {job_id}: source {src_size/1024:.0f} KB')
        
        # Run FFmpeg
        cmd = f'ffmpeg -y -i "{src_file}" {ffmpeg_args} "{out_file}"'
        log.info(f'Job {job_id}: FFmpeg → {rendition_key}')
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=600)
        
        if result.returncode != 0:
            err_msg = result.stderr[-500:] if result.stderr else 'Unknown FFmpeg error'
            return False, f'FFmpeg error (code {result.returncode}): {err_msg}'
        
        if not os.path.exists(out_file) or os.path.getsize(out_file) == 0:
            return False, 'FFmpeg produced no output'
        
        out_size = os.path.getsize(out_file)
        log.info(f'Job {job_id}: output {out_size/1024:.0f} KB')
        
        # Upload
        log.info(f'Job {job_id}: uploading to {output_bucket}/{output_path}')
        if not upload_to_storage(output_bucket, output_path, out_file):
            return False, 'Upload to storage failed'
        
        # Update rendition
        public_url = f'{SUPABASE_URL}/storage/v1/object/public/{output_bucket}/{output_path}'
        if rendition_id:
            api_patch(
                f'video_renditions?id=eq.{rendition_id}',
                {'status': 'ready', 'file_size_bytes': out_size, 'public_url_hint': public_url, 'height': target_height}
            )
        
        log.info(f'Job {job_id}: ✅ done ({rendition_key})')
        return True, None
        
    finally:
        for f in [src_file, out_file]:
            try: os.remove(f)
            except: pass

def poll_and_process():
    # Only pick up transcode_resolution jobs with non-empty payloads
    jobs = api_get(
        "video_processing_jobs?status=eq.queued&job_type=eq.transcode_resolution&order=created_at.asc&limit=1"
    )
    
    if not jobs:
        return False
    
    job = jobs[0]
    job_id = job['id']
    payload = job.get('payload', {})
    
    # Skip empty payloads
    if not payload or payload == {}:
        log.warning(f'Job {job_id}: empty payload, marking failed')
        api_patch(f'video_processing_jobs?id=eq.{job_id}', {
            'status': 'failed', 'error': 'Empty payload'
        })
        return True
    
    log.info(f'Processing job {job_id} (type={job.get("job_type")})')
    
    # Lock the job
    now = time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())
    attempts = (job.get('attempts') or 0) + 1
    api_patch(f'video_processing_jobs?id=eq.{job_id}', {
        'status': 'running',
        'locked_at': now,
        'locked_by': WORKER_ID,
        'attempts': attempts,
        'updated_at': now,
    })
    
    try:
        success, error_msg = process_transcode_job(job)
        now2 = time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())
        api_patch(f'video_processing_jobs?id=eq.{job_id}', {
            'status': 'done' if success else 'failed',
            'error': error_msg,
            'updated_at': now2,
        })
        return True
        
    except Exception as e:
        log.error(f'Job {job_id}: exception: {e}')
        now2 = time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())
        api_patch(f'video_processing_jobs?id=eq.{job_id}', {
            'status': 'failed',
            'error': str(e)[:500],
            'updated_at': now2,
        })
        return True

def main():
    log.info('=' * 50)
    log.info('Academia Video Worker v2 starting')
    log.info(f'Poll interval: {POLL_INTERVAL}s')
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

print("\n" + "=" * 60)
print("Deploying fixed worker v2...")
print("=" * 60)

try:
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(VPS_IP, username=VPS_USER, password=VPS_PASS, timeout=15)
    print("  ✅ Connected")
    
    sftp = ssh.open_sftp()
    with sftp.open('/opt/academia-worker/video_worker.py', 'w') as f:
        f.write(WORKER_SCRIPT)
    sftp.close()
    print("  ✅ Worker v2 uploaded")
    
    ssh.exec_command("systemctl restart academia-video-worker")
    time.sleep(4)
    
    _, stdout, _ = ssh.exec_command("journalctl -u academia-video-worker --no-pager -n 15")
    logs = stdout.read().decode()
    for line in logs.strip().split('\n')[-15:]:
        print(f"    {line}")
    
    ssh.close()
    print("\n  ✅ Worker v2 deployed and running!")
except Exception as e:
    print(f"  ❌ {e}")

"""
Deploy a video processing worker on the Kamatera VPS.
This worker polls video_processing_jobs (status='queued'),
downloads source video, runs FFmpeg, uploads result, updates DB.
"""
import paramiko
import time

VPS_IP = "185.167.96.214"
VPS_USER = "root"
VPS_PASS = "Wenden@Koote2026"

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

WORKER_SCRIPT = r'''#!/usr/bin/env python3
"""
Academia Video Processing Worker
Polls Supabase video_processing_jobs, runs FFmpeg, uploads results.
Runs as a systemd service on the Kamatera VPS.
"""
import os
import sys
import time
import json
import subprocess
import urllib.request
import urllib.error
import tempfile
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

SUPABASE_URL = os.environ.get('SUPABASE_URL', 'PLACEHOLDER_URL')
SERVICE_KEY = os.environ.get('SUPABASE_SERVICE_KEY', 'PLACEHOLDER_KEY')
POLL_INTERVAL = 10  # seconds
WORK_DIR = '/tmp/video_worker'

HEADERS = {
    'apikey': SERVICE_KEY,
    'Authorization': f'Bearer {SERVICE_KEY}',
    'Content-Type': 'application/json',
    'Prefer': 'return=representation',
    'Accept-Profile': 'app',
    'Content-Profile': 'app',
}

def api_get(path):
    """GET request to Supabase REST API."""
    url = f'{SUPABASE_URL}/rest/v1/{path}'
    req = urllib.request.Request(url, headers=HEADERS)
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        log.error(f'GET {path}: HTTP {e.code} {e.read().decode()[:200]}')
        return None

def api_patch(path, data):
    """PATCH request to Supabase REST API."""
    url = f'{SUPABASE_URL}/rest/v1/{path}'
    body = json.dumps(data).encode()
    req = urllib.request.Request(url, data=body, headers={**HEADERS, 'Prefer': 'return=minimal'}, method='PATCH')
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return resp.status
    except urllib.error.HTTPError as e:
        log.error(f'PATCH {path}: HTTP {e.code} {e.read().decode()[:200]}')
        return None

def api_rpc(fn_name, params):
    """Call Supabase RPC."""
    url = f'{SUPABASE_URL}/rest/v1/rpc/{fn_name}'
    body = json.dumps(params).encode()
    h = {
        'apikey': SERVICE_KEY,
        'Authorization': f'Bearer {SERVICE_KEY}',
        'Content-Type': 'application/json',
    }
    req = urllib.request.Request(url, data=body, headers=h)
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        log.error(f'RPC {fn_name}: HTTP {e.code} {e.read().decode()[:200]}')
        return None

def upload_to_storage(bucket, path, filepath, content_type='video/mp4'):
    """Upload file to Supabase Storage."""
    url = f'{SUPABASE_URL}/storage/v1/object/{bucket}/{path}'
    with open(filepath, 'rb') as f:
        data = f.read()
    h = {
        'apikey': SERVICE_KEY,
        'Authorization': f'Bearer {SERVICE_KEY}',
        'Content-Type': content_type,
        'x-upsert': 'true',
    }
    req = urllib.request.Request(url, data=data, headers=h, method='POST')
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            return resp.status in (200, 201)
    except urllib.error.HTTPError as e:
        log.error(f'Upload {bucket}/{path}: HTTP {e.code} {e.read().decode()[:200]}')
        return False

def download_file(url, dest):
    """Download file from URL."""
    req = urllib.request.Request(url)
    with urllib.request.urlopen(req, timeout=120) as resp:
        with open(dest, 'wb') as f:
            while True:
                chunk = resp.read(65536)
                if not chunk:
                    break
                f.write(chunk)
    return os.path.exists(dest)

def process_job(job):
    """Process a single video processing job."""
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
        log.error(f'Job {job_id}: missing source_url/output_path/ffmpeg_args')
        return False
    
    os.makedirs(WORK_DIR, exist_ok=True)
    src_file = os.path.join(WORK_DIR, f'src_{job_id}.mp4')
    out_file = os.path.join(WORK_DIR, f'out_{job_id}_{rendition_key}.mp4')
    
    try:
        # 1. Download source
        log.info(f'Job {job_id}: downloading source from {source_url[:80]}...')
        if not download_file(source_url, src_file):
            log.error(f'Job {job_id}: failed to download source')
            return False
        
        src_size = os.path.getsize(src_file)
        log.info(f'Job {job_id}: source downloaded ({src_size/1024:.0f} KB)')
        
        # 2. Run FFmpeg
        cmd = f'ffmpeg -y -i "{src_file}" {ffmpeg_args} "{out_file}"'
        log.info(f'Job {job_id}: running FFmpeg → {rendition_key}')
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=300)
        
        if result.returncode != 0:
            log.error(f'Job {job_id}: FFmpeg failed: {result.stderr[-500:]}')
            return False
        
        if not os.path.exists(out_file):
            log.error(f'Job {job_id}: output file not created')
            return False
        
        out_size = os.path.getsize(out_file)
        log.info(f'Job {job_id}: FFmpeg OK ({out_size/1024:.0f} KB)')
        
        # 3. Upload to Supabase Storage
        log.info(f'Job {job_id}: uploading to {output_bucket}/{output_path}')
        if not upload_to_storage(output_bucket, output_path, out_file):
            log.error(f'Job {job_id}: upload failed')
            return False
        
        # 4. Get public URL
        public_url = f'{SUPABASE_URL}/storage/v1/object/public/{output_bucket}/{output_path}'
        
        # 5. Update rendition status
        if rendition_id:
            api_patch(
                f'video_renditions?id=eq.{rendition_id}',
                {
                    'status': 'ready',
                    'file_size_bytes': out_size,
                    'public_url_hint': public_url,
                    'height': target_height,
                }
            )
            log.info(f'Job {job_id}: rendition {rendition_key} marked ready')
        
        return True
        
    finally:
        # Cleanup
        for f in [src_file, out_file]:
            try:
                os.remove(f)
            except OSError:
                pass

def poll_and_process():
    """Poll for queued jobs and process them."""
    # Get next queued job (oldest first)
    jobs = api_get('video_processing_jobs?status=eq.queued&order=created_at.asc&limit=1')
    
    if not jobs:
        return False
    
    job = jobs[0]
    job_id = job['id']
    log.info(f'Processing job {job_id} (type={job.get("job_type")})')
    
    # Mark as running
    api_patch(f'video_processing_jobs?id=eq.{job_id}', {
        'status': 'running',
        'started_at': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
    })
    
    try:
        success = process_job(job)
        
        api_patch(f'video_processing_jobs?id=eq.{job_id}', {
            'status': 'done' if success else 'failed',
            'finished_at': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
            'error': None if success else 'Processing failed — check logs',
        })
        
        log.info(f'Job {job_id}: {"done" if success else "FAILED"}')
        return success
        
    except Exception as e:
        log.error(f'Job {job_id}: exception: {e}')
        api_patch(f'video_processing_jobs?id=eq.{job_id}', {
            'status': 'failed',
            'finished_at': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
            'error': str(e)[:500],
        })
        return False

def reset_stuck_jobs():
    """Reset jobs stuck in 'running' state (likely from crashed worker)."""
    stuck = api_get('video_processing_jobs?status=eq.running')
    if stuck:
        for job in stuck:
            log.warning(f'Resetting stuck job {job["id"]}')
            api_patch(f'video_processing_jobs?id=eq.{job["id"]}', {
                'status': 'queued',
                'error': 'Reset from stuck running state',
            })

def main():
    log.info('=' * 50)
    log.info('Academia Video Processing Worker starting')
    log.info(f'Supabase: {SUPABASE_URL[:40]}...')
    log.info(f'Poll interval: {POLL_INTERVAL}s')
    log.info('=' * 50)
    
    # Reset stuck jobs on startup
    reset_stuck_jobs()
    
    while True:
        try:
            had_work = poll_and_process()
            if not had_work:
                time.sleep(POLL_INTERVAL)
            else:
                time.sleep(1)  # Small delay between consecutive jobs
        except KeyboardInterrupt:
            log.info('Worker stopped by user')
            break
        except Exception as e:
            log.error(f'Unexpected error: {e}')
            time.sleep(POLL_INTERVAL * 3)

if __name__ == '__main__':
    main()
'''

SYSTEMD_SERVICE = f'''[Unit]
Description=Academia Video Processing Worker
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/academia-worker
ExecStart=/usr/bin/python3 /opt/academia-worker/video_worker.py
Restart=always
RestartSec=10
Environment=SUPABASE_URL={SUPABASE_URL}
Environment=SUPABASE_SERVICE_KEY={SERVICE_KEY}

[Install]
WantedBy=multi-user.target
'''

def ssh_cmd(ssh, cmd, label="", timeout=30):
    if label:
        print(f"\n  {label}")
    stdin, stdout, stderr = ssh.exec_command(cmd, timeout=timeout)
    out = stdout.read().decode('utf-8', errors='replace').strip()
    err = stderr.read().decode('utf-8', errors='replace').strip()
    if out:
        for line in out.split('\n')[:15]:
            print(f"    {line}")
    if err and not out:
        for line in err.split('\n')[:5]:
            print(f"    [stderr] {line}")
    return out

print("=" * 60)
print("Deploying Video Processing Worker to VPS")
print("=" * 60)

try:
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    print(f"  Connecting to {VPS_IP}...")
    ssh.connect(VPS_IP, username=VPS_USER, password=VPS_PASS, timeout=15)
    print("  ✅ Connected")
    
    # Create directory
    ssh_cmd(ssh, "mkdir -p /opt/academia-worker", "Creating worker directory")
    
    # Write worker script
    sftp = ssh.open_sftp()
    with sftp.open('/opt/academia-worker/video_worker.py', 'w') as f:
        f.write(WORKER_SCRIPT)
    print("  ✅ Worker script uploaded")
    
    # Write systemd service
    with sftp.open('/etc/systemd/system/academia-video-worker.service', 'w') as f:
        f.write(SYSTEMD_SERVICE)
    print("  ✅ Systemd service written")
    sftp.close()
    
    # Enable and start service
    ssh_cmd(ssh, "systemctl daemon-reload", "Reloading systemd")
    ssh_cmd(ssh, "systemctl enable academia-video-worker", "Enabling service")
    ssh_cmd(ssh, "systemctl restart academia-video-worker", "Starting worker")
    
    time.sleep(3)
    
    # Check status
    ssh_cmd(ssh, "systemctl status academia-video-worker --no-pager | head -20", "Worker status")
    
    # Check logs
    ssh_cmd(ssh, "journalctl -u academia-video-worker --no-pager -n 15", "Recent logs")
    
    ssh.close()
    print("\n  ✅ Worker deployed and running!")
    
except Exception as e:
    print(f"\n  ❌ Error: {e}")

print("\n🏁 Done.")

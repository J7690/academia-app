#!/usr/bin/env python3
"""
Phase 3: Deploy videoasset_worker + FFmpeg on Kamatera VPS.
Steps:
1. Install FFmpeg
2. Install Python3 + pip + dependencies (httpx, python-dotenv)
3. Upload videoasset_worker.py and studio_video_renderer.py
4. Create .env with Supabase credentials
5. Create systemd service
6. Start service
7. Verify
"""
import paramiko
import os
import sys
from pathlib import Path

SERVER_IP = "185.167.97.144"
SERVER_USER = "root"
SERVER_PASS = "Nexiomgroup@Academia0"

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

WORKER_DIR = "/opt/video-worker"

# Local paths
BASE_DIR = Path(__file__).resolve().parent.parent
BACKEND_DIR = BASE_DIR / "academia_bobodo_backend"
WORKER_PY = BACKEND_DIR / "videoasset_worker.py"
RENDERER_PY = BACKEND_DIR / "studio_video_renderer.py"


def section(title):
    print(f"\n{'=' * 60}\n {title}\n{'=' * 60}")


def ssh_exec(client, cmd, timeout=120):
    print(f"  $ {cmd}")
    stdin, stdout, stderr = client.exec_command(cmd, timeout=timeout)
    exit_code = stdout.channel.recv_exit_status()
    out = stdout.read().decode("utf-8", errors="replace").strip()
    err = stderr.read().decode("utf-8", errors="replace").strip()
    if out:
        # Limit output to avoid flooding console
        if len(out) > 2000:
            print(f"  {out[:2000]}...")
        else:
            print(f"  {out}")
    if err and exit_code != 0:
        print(f"  (stderr) {err[:500]}")
    return exit_code, out


def upload_file(sftp, local_path, remote_path):
    print(f"  Uploading {local_path.name} -> {remote_path}")
    sftp.put(str(local_path), remote_path)


def main():
    section("1. CONNEXION SSH")
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        client.connect(SERVER_IP, username=SERVER_USER, password=SERVER_PASS, timeout=15)
        print(f"  Connecté à {SERVER_IP}")
    except Exception as e:
        print(f"  ÉCHEC: {e}")
        return

    # 1. Install FFmpeg
    section("2. INSTALLER FFMPEG")
    ssh_exec(client, "apt-get update -qq")
    code, _ = ssh_exec(client, "apt-get install -y ffmpeg", timeout=300)
    if code != 0:
        print("  ERREUR: Installation FFmpeg échouée!")
        return
    ssh_exec(client, "ffmpeg -version 2>&1 | head -3")

    # 2. Install Python deps
    section("3. INSTALLER PYTHON + DÉPENDANCES")
    ssh_exec(client, "apt-get install -y python3 python3-pip python3-venv -qq", timeout=120)
    ssh_exec(client, f"mkdir -p {WORKER_DIR}")
    ssh_exec(client, f"python3 -m venv {WORKER_DIR}/venv")
    ssh_exec(client, f"{WORKER_DIR}/venv/bin/pip install --quiet httpx python-dotenv")

    # 3. Upload worker files
    section("4. UPLOAD DES FICHIERS WORKER")
    sftp = client.open_sftp()
    upload_file(sftp, WORKER_PY, f"{WORKER_DIR}/videoasset_worker.py")
    upload_file(sftp, RENDERER_PY, f"{WORKER_DIR}/studio_video_renderer.py")

    # The renderer imports fastapi/pydantic which we don't need for worker mode.
    # Create a minimal shim that only exposes the FFmpeg functions.
    # Actually, let's check if the worker's imports from studio_video_renderer work
    # without fastapi. It only imports the _run_ffmpeg_transcode_* functions.
    # The module-level code in studio_video_renderer.py does `from fastapi import ...`
    # which would crash. Let's install fastapi too (it's lightweight).
    ssh_exec(client, f"{WORKER_DIR}/venv/bin/pip install --quiet fastapi pydantic")

    sftp.close()

    # 4. Create .env
    section("5. CRÉER .ENV")
    env_content = f"""SUPABASE_URL={SUPABASE_URL}
SUPABASE_SERVICE_KEY={SERVICE_KEY}
VIDEO_ASSET_BUCKET=video-assets
WORKER_LOOP=true
WORKER_INTERVAL_SECONDS=5
WORKER_MAX_JOBS=3
WATERMARK_LOGO_PATH={WORKER_DIR}/academia.png
"""
    ssh_exec(client, f"cat > {WORKER_DIR}/.env << 'ENVEOF'\n{env_content}ENVEOF")

    # Upload watermark logo if available
    logo_path = BASE_DIR / "academia_app" / "assets" / "images" / "academia.png"
    if logo_path.exists():
        sftp = client.open_sftp()
        upload_file(sftp, logo_path, f"{WORKER_DIR}/academia.png")
        sftp.close()
    else:
        print(f"  Logo non trouvé à {logo_path}, watermark utilisera un placeholder")
        # Create a dummy 1px PNG to avoid crash
        ssh_exec(client, f"python3 -c \"import base64; open('{WORKER_DIR}/academia.png','wb').write(base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=='))\"")

    # 5. Create systemd service
    section("6. CRÉER SERVICE SYSTEMD")
    service_content = f"""[Unit]
Description=Academia Video Asset Worker
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory={WORKER_DIR}
ExecStart={WORKER_DIR}/venv/bin/python {WORKER_DIR}/videoasset_worker.py
EnvironmentFile={WORKER_DIR}/.env
Environment=WORKER_LOOP=true
Environment=WORKER_INTERVAL_SECONDS=5
Environment=WORKER_MAX_JOBS=3
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
"""
    ssh_exec(client, f"cat > /etc/systemd/system/video-worker.service << 'SVCEOF'\n{service_content}SVCEOF")

    # 6. Enable and start
    section("7. DÉMARRER LE SERVICE")
    ssh_exec(client, "systemctl daemon-reload")
    ssh_exec(client, "systemctl enable video-worker")
    ssh_exec(client, "systemctl start video-worker")

    # 7. Verify
    section("8. VÉRIFICATION")
    import time
    time.sleep(5)
    ssh_exec(client, "systemctl status video-worker --no-pager")
    ssh_exec(client, "journalctl -u video-worker --no-pager -n 30")
    ssh_exec(client, "ffmpeg -version 2>&1 | head -1")
    ssh_exec(client, f"ls -la {WORKER_DIR}/")

    client.close()
    print("\n" + "=" * 60)
    print(" DÉPLOIEMENT TERMINÉ")
    print("=" * 60)


if __name__ == "__main__":
    main()

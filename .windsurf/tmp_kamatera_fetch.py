#!/usr/bin/env python3
"""Fetch full Kamatera whiteboard worker files for inspection."""
import paramiko
from pathlib import Path

HOST = "185.167.97.144"
USER = "root"
PASS = "Nexiomgroup@Academia0"
REMOTE_FILES = [
    "/opt/whiteboard-worker/whiteboard_ffmpeg_assembler.py",
    "/opt/whiteboard-worker/whiteboard_render_worker.py",
    "/opt/whiteboard-worker/whiteboard_upload_renderer.py",
    "/opt/whiteboard-worker/whiteboard_png_renderer.py",
]
LOCAL_DIR = Path("C:/Users/fasop/AndroidStudioProjects/academia/.windsurf/kamatera_snapshot")
LOCAL_DIR.mkdir(parents=True, exist_ok=True)

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(HOST, username=USER, password=PASS, timeout=20)

for remote in REMOTE_FILES:
    sftp = ssh.open_sftp()
    local = LOCAL_DIR / Path(remote).name
    sftp.get(remote, str(local))
    print(f"saved {local}")
    sftp.close()

ssh.close()

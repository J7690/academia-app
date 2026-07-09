#!/usr/bin/env python3
"""MISSION D31.2 — Passer total_duration_ms depuis le worker vers l'assembleur."""
import paramiko
from pathlib import Path

HOST = "185.167.97.144"
USER = "root"
PASS = "Nexiomgroup@Academia0"
REMOTE_WORKER = "/opt/whiteboard-worker/whiteboard_render_worker.py"
LOCAL_DIR = Path("C:/Users/fasop/AndroidStudioProjects/academia/.windsurf/kamatera_snapshot_d31_2")


def ssh_read_file(remote_path):
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(HOST, username=USER, password=PASS, timeout=20)
    sftp = ssh.open_sftp()
    with sftp.file(remote_path, 'r') as f:
        content = f.read().decode('utf-8')
    sftp.close()
    ssh.close()
    return content


def ssh_write_file(remote_path, content):
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(HOST, username=USER, password=PASS, timeout=20)
    sftp = ssh.open_sftp()
    with sftp.file(remote_path, 'w') as f:
        f.write(content.encode('utf-8'))
    sftp.close()
    ssh.close()


content = ssh_read_file(REMOTE_WORKER)

old_call = "mp4_path = assemble_pngs_to_mp4(png_paths, temp_path, durations_ms)"
new_call = "mp4_path = assemble_pngs_to_mp4(png_paths, temp_path, durations_ms, total_duration_ms=duration_ms)"
content = content.replace(old_call, new_call)

ssh_write_file(REMOTE_WORKER, content)
(LOCAL_DIR / "whiteboard_render_worker.py").write_text(content, encoding='utf-8')
print("Worker updated to pass total_duration_ms")

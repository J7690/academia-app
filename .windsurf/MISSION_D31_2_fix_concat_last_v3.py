#!/usr/bin/env python3
"""MISSION D31.2 — Correction v3 du concat demuxer : supprimer toute référence au last file."""
import paramiko
from pathlib import Path

HOST = "185.167.97.144"
USER = "root"
PASS = "Nexiomgroup@Academia0"
REMOTE_ASSEMBLER = "/opt/whiteboard-worker/whiteboard_ffmpeg_assembler.py"
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


content = ssh_read_file(REMOTE_ASSEMBLER)
lines = content.splitlines(keepends=True)

# Remove any line containing "last = str(png_paths[-1])" or "file '{last}'"
new_lines = []
for line in lines:
    if "last = str(png_paths[-1])" in line:
        continue
    if "f.write(f\"file '{last}'\\n\")" in line or "f.write(f\"file '{last}'" in line:
        continue
    new_lines.append(line)

content = "".join(new_lines)
ssh_write_file(REMOTE_ASSEMBLER, content)
(LOCAL_DIR / "whiteboard_ffmpeg_assembler.py").write_text(content, encoding='utf-8')
print("Assembler fixed: all last-file references removed")

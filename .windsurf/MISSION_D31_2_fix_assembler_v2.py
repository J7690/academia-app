#!/usr/bin/env python3
"""MISSION D31.2 — Correction v2 de la boucle concat par lignes."""
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

# Lines 30-35 (1-indexed) = indices 29-34 (0-indexed) are the concat loop body to replace
new_lines = [
    "    # Fallback: if no durations provided or mismatch, use 5s per scene (legacy behavior)\n",
    "    if durations_ms is None or len(durations_ms) != len(png_paths):\n",
    "        durations_ms = [5000] * len(png_paths)\n",
    "    with open(concat_file, \"w\") as f:\n",
    "        for p, d in zip(png_paths, durations_ms):\n",
    "            safe = str(p).replace(\"'\", \"'\\\\\\''\")\n",
    "            f.write(f\"file '{safe}'\\n\")\n",
    "            f.write(f\"duration {d / 1000.0}\\n\")\n",
    "        last = str(png_paths[-1]).replace(\"'\", \"'\\\\\\''\")\n",
    "        f.write(f\"file '{last}'\\n\")\n",
]

# Replace indices 29-34 (lines 30-35) with new block
lines[29:35] = new_lines

content = "".join(lines)
ssh_write_file(REMOTE_ASSEMBLER, content)
(LOCAL_DIR / "whiteboard_ffmpeg_assembler.py").write_text(content, encoding='utf-8')
print("Assembler fixed on Kamatera and local snapshot updated")

#!/usr/bin/env python3
"""MISSION D31.2 — Correction immédiate de la boucle concat (le remplacement précédent a échoué)."""
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

# Replace the broken concat block
old_block = """    # C1: concat demuxer avec duree explicite par scene
    concat_file = output_dir / "concat.txt"
    with open(concat_file, "w") as f:
        for p in png_paths:
            safe = str(p).replace("'", "'\\''")
            f.write(f"file '{safe}'\n")
            f.write(f"duration {SECONDS_PER_SCENE}\n")
        last = str(png_paths[-1]).replace("'", "'\\''")
        f.write(f"file '{last}'\n")
"""

new_block = """    # C1: concat demuxer avec duree explicite par scene
    concat_file = output_dir / "concat.txt"
    # Fallback: if no durations provided or mismatch, use 5s per scene (legacy behavior)
    if durations_ms is None or len(durations_ms) != len(png_paths):
        durations_ms = [5000] * len(png_paths)
    with open(concat_file, "w") as f:
        for p, d in zip(png_paths, durations_ms):
            safe = str(p).replace("'", "'\\''")
            f.write(f"file '{safe}'\n")
            f.write(f"duration {d / 1000.0}\n")
        last = str(png_paths[-1]).replace("'", "'\\''")
        f.write(f"file '{last}'\n")
"""

if old_block not in content:
    raise RuntimeError("Old block not found in assembler file")

content = content.replace(old_block, new_block)

ssh_write_file(REMOTE_ASSEMBLER, content)
(LOCAL_DIR / "whiteboard_ffmpeg_assembler.py").write_text(content, encoding='utf-8')
print("Assembler fixed on Kamatera and local snapshot updated")

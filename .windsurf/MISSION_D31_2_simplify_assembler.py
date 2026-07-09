#!/usr/bin/env python3
"""MISSION D31.2 — Simplification : l'assembleur calcule total_duration_s depuis durations_ms."""
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

# Remove total_duration_ms from signature
old_sig = "def assemble_pngs_to_mp4(png_paths: List[Path], output_dir: Path, durations_ms: Optional[List[int]] = None, total_duration_ms: Optional[int] = None) -> Path:"
new_sig = "def assemble_pngs_to_mp4(png_paths: List[Path], output_dir: Path, durations_ms: Optional[List[int]] = None) -> Path:"
content = content.replace(old_sig, new_sig)

# Simplify total_duration_s calculation
old_calc = """    # Compute total duration for -t parameter
    total_duration_s = (total_duration_ms if total_duration_ms is not None else sum(durations_ms)) / 1000.0
    with open(concat_file, \"w\") as f:
"""
new_calc = """    # Compute total duration for -t parameter
    total_duration_s = sum(durations_ms) / 1000.0
    with open(concat_file, \"w\") as f:
"""
content = content.replace(old_calc, new_calc)

ssh_write_file(REMOTE_ASSEMBLER, content)
(LOCAL_DIR / "whiteboard_ffmpeg_assembler.py").write_text(content, encoding='utf-8')
print("Assembler simplified")

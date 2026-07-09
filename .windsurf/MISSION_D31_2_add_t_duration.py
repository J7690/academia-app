#!/usr/bin/env python3
"""MISSION D31.2 — Ajout de -t pour forcer la durée exacte du MP4."""
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

# Add total_duration_ms parameter to signature
old_sig = "def assemble_pngs_to_mp4(png_paths: List[Path], output_dir: Path, durations_ms: Optional[List[int]] = None) -> Path:"
new_sig = "def assemble_pngs_to_mp4(png_paths: List[Path], output_dir: Path, durations_ms: Optional[List[int]] = None, total_duration_ms: Optional[int] = None) -> Path:"
content = content.replace(old_sig, new_sig)

# After fallback, compute total_duration_s
old_fallback = """    # Fallback: if no durations provided or mismatch, use 5s per scene (legacy behavior)
    if durations_ms is None or len(durations_ms) != len(png_paths):
        durations_ms = [5000] * len(png_paths)
    with open(concat_file, "w") as f:
"""
new_fallback = """    # Fallback: if no durations provided or mismatch, use 5s per scene (legacy behavior)
    if durations_ms is None or len(durations_ms) != len(png_paths):
        durations_ms = [5000] * len(png_paths)
    # Compute total duration for -t parameter
    total_duration_s = (total_duration_ms if total_duration_ms is not None else sum(durations_ms)) / 1000.0
    with open(concat_file, "w") as f:
"""
content = content.replace(old_fallback, new_fallback)

# Replace -shortest with -t total_duration_s (keep -shortest as safety)
old_shortest = "        # Terminer quand la video se termine\n        \"-shortest\","
new_shortest = "        # Terminer exactement a la duree totale du storyboard\n        \"-t\", str(total_duration_s),\n        \"-shortest\","
content = content.replace(old_shortest, new_shortest)

ssh_write_file(REMOTE_ASSEMBLER, content)
(LOCAL_DIR / "whiteboard_ffmpeg_assembler.py").write_text(content, encoding='utf-8')
print("Assembler updated with -t duration")

#!/usr/bin/env python3
"""MISSION D31.2 — Correction de l'ordre de duration_ms dans le worker."""
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

# Reorder: compute duration_ms before assembler call
old_block = """            # Extract scene durations from storyboard
            storyboard = storyboard_json if isinstance(storyboard_json, dict) else {}
            scenes = storyboard.get("scenes", [])
            durations_ms = [s.get("duration_ms", 5000) for s in scenes]
            if len(durations_ms) != len(png_paths):
                logger.warning(f"[whiteboard_render_worker] Duration mismatch: {len(durations_ms)} durations vs {len(png_paths)} PNGs; falling back to 5s per scene")
                durations_ms = None
            
            # Assembler les PNGs en MP4
            logger.info(f"[whiteboard_render_worker] Assembling MP4 for job {job_id}")
            mp4_path = assemble_pngs_to_mp4(png_paths, temp_path, durations_ms, total_duration_ms=duration_ms)

            # Uploader le MP4
            logger.info(f"[whiteboard_render_worker] Uploading MP4 for job {job_id}")
            video_url = await upload_mp4_to_storage(mp4_path, job_id)
            
            # Calculer la durée totale à partir du storyboard
            if durations_ms is not None:
                duration_ms = sum(durations_ms)
            else:
                # Fallback legacy: estimate 5 seconds per scene
                duration_ms = len(scenes) * 5000
"""

new_block = """            # Extract scene durations from storyboard
            storyboard = storyboard_json if isinstance(storyboard_json, dict) else {}
            scenes = storyboard.get("scenes", [])
            durations_ms = [s.get("duration_ms", 5000) for s in scenes]
            if len(durations_ms) != len(png_paths):
                logger.warning(f"[whiteboard_render_worker] Duration mismatch: {len(durations_ms)} durations vs {len(png_paths)} PNGs; falling back to 5s per scene")
                durations_ms = None
            
            # Calculer la durée totale à partir du storyboard (avant l'assembleur)
            if durations_ms is not None:
                duration_ms = sum(durations_ms)
            else:
                # Fallback legacy: estimate 5 seconds per scene
                duration_ms = len(scenes) * 5000
            
            # Assembler les PNGs en MP4
            logger.info(f"[whiteboard_render_worker] Assembling MP4 for job {job_id}")
            mp4_path = assemble_pngs_to_mp4(png_paths, temp_path, durations_ms, total_duration_ms=duration_ms)

            # Uploader le MP4
            logger.info(f"[whiteboard_render_worker] Uploading MP4 for job {job_id}")
            video_url = await upload_mp4_to_storage(mp4_path, job_id)
"""

if old_block not in content:
    raise RuntimeError("Old block not found in worker file")

content = content.replace(old_block, new_block)
ssh_write_file(REMOTE_WORKER, content)
(LOCAL_DIR / "whiteboard_render_worker.py").write_text(content, encoding='utf-8')
print("Worker fixed: duration_ms computed before assembler call")

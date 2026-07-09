import paramiko

host = '185.167.97.144'
user = 'root'
pwd = 'Nexiomgroup@Academia0'

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect(host, username=user, password=pwd, timeout=30)

new_assembler = '''"""
Whiteboard FFmpeg Assembler - Phase C.3 (fixed)
Assemblage de PNGs en MP4 — chaque PNG dure SECONDS_PER_SCENE secondes
"""

from pathlib import Path
from typing import List
import subprocess
import tempfile
import os

SECONDS_PER_SCENE = 5  # durée de chaque slide en secondes


def assemble_pngs_to_mp4(png_paths: List[Path], output_dir: Path) -> Path:
    """
    Assemble des PNGs en MP4.
    Chaque PNG est affiché pendant SECONDS_PER_SCENE secondes.
    """
    if not png_paths:
        raise ValueError("No PNGs provided")

    for png_path in png_paths:
        if not png_path.exists():
            raise FileNotFoundError(f"PNG not found: {png_path}")

    mp4_path = output_dir / "output.mp4"

    # Créer un fichier concat pour ffmpeg
    # Chaque entrée : durée = SECONDS_PER_SCENE secondes
    concat_file = output_dir / "concat.txt"
    with open(concat_file, "w") as f:
        for png_path in png_paths:
            f.write(f"file '{png_path}'\\n")
            f.write(f"duration {SECONDS_PER_SCENE}\\n")
        # Répéter le dernier frame pour éviter le tronquage FFmpeg
        if png_paths:
            f.write(f"file '{png_paths[-1]}'\\n")

    cmd = [
        "ffmpeg",
        "-y",
        "-f", "concat",
        "-safe", "0",
        "-i", str(concat_file),
        "-vf", "fps=30,scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:(ow-iw)/2:(oh-ih)/2",
        "-c:v", "libx264",
        "-pix_fmt", "yuv420p",
        "-preset", "fast",
        "-crf", "23",
        "-movflags", "+faststart",
        str(mp4_path),
    ]

    result = subprocess.run(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )

    if result.returncode != 0:
        stderr_text = result.stderr.decode("utf-8", errors="ignore")
        raise RuntimeError(f"FFmpeg error (code {result.returncode}): {stderr_text[:4000]}")

    if not mp4_path.exists():
        raise RuntimeError(f"MP4 not created: {mp4_path}")

    return mp4_path
'''

# Écrire le nouveau fichier
sftp = client.open_sftp()
with sftp.open('/opt/whiteboard-worker/whiteboard_ffmpeg_assembler.py', 'w') as f:
    f.write(new_assembler)
sftp.close()
print("Fichier écrit sur Kamatera")

# Tester immédiatement
test_script = '''
cd /opt/whiteboard-worker
python3 -c "
import json, tempfile
from pathlib import Path
from whiteboard_png_renderer import render_storyboard_to_pngs
from whiteboard_ffmpeg_assembler import assemble_pngs_to_mp4

storyboard = {
  'scenes': [
    {'id': 'sc1', 'title': 'Test scene 1', 'order': 0, 'duration_ms': 5000,
     'blocks': [{'id': 'b1', 'type': 'paragraph', 'content': 'Introduction aux derivees', 'order': 0, 'visible': True}]},
    {'id': 'sc2', 'title': 'Test scene 2', 'order': 1, 'duration_ms': 5000,
     'blocks': [{'id': 'b2', 'type': 'definition', 'content': 'La derivee mesure la variation', 'order': 0, 'visible': True}]}
  ],
  'renderer': 'notebook', 'theme': 'notebook'
}

with tempfile.TemporaryDirectory() as tmp:
    p = Path(tmp)
    pngs = render_storyboard_to_pngs(storyboard, p)
    print('PNGs generated:', len(pngs))
    for pp in pngs:
        print('  PNG:', pp.name, 'size:', pp.stat().st_size if pp.exists() else 'MISSING')
    mp4 = assemble_pngs_to_mp4(pngs, p)
    print('MP4 size:', mp4.stat().st_size, 'bytes')
    print('SUCCESS' if mp4.stat().st_size > 50000 else 'STILL TOO SMALL')
" 2>&1
'''
_, stdout, stderr = client.exec_command(test_script)
out = stdout.read().decode(errors='replace')
err = stderr.read().decode(errors='replace')
print("TEST OUTPUT:", out)
if err.strip():
    print("STDERR:", err[:500])

client.close()

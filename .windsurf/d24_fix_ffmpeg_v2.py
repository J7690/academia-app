import paramiko

host = '185.167.97.144'
user = 'root'
pwd = 'Nexiomgroup@Academia0'

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect(host, username=user, password=pwd, timeout=30)

new_assembler = r'''"""
Whiteboard FFmpeg Assembler - Phase C.3 v3
Assemblage de PNGs en MP4 via concat demuxer.
moov placé en premier (+faststart), durée correcte.
"""

from pathlib import Path
from typing import List
import subprocess
import os

SECONDS_PER_SCENE = 5  # durée de chaque slide en secondes
FPS = 24


def assemble_pngs_to_mp4(png_paths: List[Path], output_dir: Path) -> Path:
    if not png_paths:
        raise ValueError("No PNGs provided")

    for p in png_paths:
        if not p.exists():
            raise FileNotFoundError(f"PNG not found: {p}")

    # Étape 1 : fichier concat
    concat_file = output_dir / "concat.txt"
    with open(concat_file, "w") as f:
        for p in png_paths:
            # Échapper les apostrophes dans le chemin
            safe = str(p).replace("'", "'\\''")
            f.write(f"file '{safe}'\n")
            f.write(f"duration {SECONDS_PER_SCENE}\n")
        # Répéter le dernier PNG pour éviter la troncature du dernier frame
        last = str(png_paths[-1]).replace("'", "'\\''")
        f.write(f"file '{last}'\n")

    # Étape 2 : sortie temporaire (moov à la fin)
    tmp_mp4 = output_dir / "output_tmp.mp4"
    mp4_path = output_dir / "output.mp4"

    cmd_encode = [
        "ffmpeg", "-y",
        "-f", "concat",
        "-safe", "0",
        "-i", str(concat_file),
        "-vf", f"scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:(ow-iw)/2:(oh-ih)/2,setsar=1",
        "-c:v", "libx264",
        "-profile:v", "baseline",   # profile Baseline = compatibilité max Android
        "-level", "3.1",
        "-pix_fmt", "yuv420p",
        "-r", str(FPS),
        "-preset", "fast",
        "-crf", "28",
        str(tmp_mp4),
    ]

    r = subprocess.run(cmd_encode, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    if r.returncode != 0:
        raise RuntimeError(f"FFmpeg encode error: {r.stderr.decode(errors='ignore')[:3000]}")

    # Étape 3 : faststart (déplacer moov en tête)
    cmd_fast = [
        "ffmpeg", "-y",
        "-i", str(tmp_mp4),
        "-c", "copy",
        "-movflags", "+faststart",
        str(mp4_path),
    ]
    r2 = subprocess.run(cmd_fast, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    if r2.returncode != 0:
        raise RuntimeError(f"FFmpeg faststart error: {r2.stderr.decode(errors='ignore')[:3000]}")

    # Nettoyage
    tmp_mp4.unlink(missing_ok=True)

    if not mp4_path.exists():
        raise RuntimeError(f"MP4 not created: {mp4_path}")

    return mp4_path
'''

sftp = client.open_sftp()
with sftp.open('/opt/whiteboard-worker/whiteboard_ffmpeg_assembler.py', 'w') as f:
    f.write(new_assembler)
sftp.close()
print("Fichier déployé sur Kamatera")

# Test immédiat
_, stdout, stderr = client.exec_command('''cd /opt/whiteboard-worker && python3 << 'PYEOF'
import tempfile, struct
from pathlib import Path
from whiteboard_png_renderer import render_storyboard_to_pngs
from whiteboard_ffmpeg_assembler import assemble_pngs_to_mp4

storyboard = {
  "scenes": [
    {"id": "sc1", "title": "Test", "order": 0, "duration_ms": 5000,
     "blocks": [{"id": "b1", "type": "paragraph", "content": "Bonjour", "order": 0, "visible": True}]},
    {"id": "sc2", "title": "Scene 2", "order": 1, "duration_ms": 5000,
     "blocks": [{"id": "b2", "type": "definition", "content": "Definition test", "order": 0, "visible": True}]}
  ],
  "renderer": "notebook", "theme": "notebook"
}

p = Path("/tmp/d24testv2")
p.mkdir(exist_ok=True)
pngs = render_storyboard_to_pngs(storyboard, p)
mp4 = assemble_pngs_to_mp4(pngs, p)
data = mp4.read_bytes()
print(f"SIZE={mp4.stat().st_size}")

# Vérifier ordre des atoms
import struct as st
offset = 0
atoms = []
while offset < len(data) - 8:
    sz = st.unpack(">I", data[offset:offset+4])[0]
    nm = data[offset+4:offset+8].decode("ascii", errors="?")
    atoms.append(nm)
    if sz == 0 or sz < 8: break
    offset += sz
    if offset > 500000: break
print(f"ATOMS={','.join(atoms)}")
print(f"MOOV_BEFORE_MDAT={'moov' in atoms and atoms.index('moov') < atoms.index('mdat') if 'mdat' in atoms else 'no mdat'}")

# Durée
mvhd = data.find(b"mvhd")
if mvhd > 0:
    ts = st.unpack(">I", data[mvhd+4+8:mvhd+4+12])[0]
    dur = st.unpack(">I", data[mvhd+4+12:mvhd+4+16])[0]
    print(f"DURATION={dur/ts:.1f}s (ts={ts} dur={dur})")
PYEOF
''')
out = stdout.read().decode(errors='replace')
err = stderr.read().decode(errors='replace')
print("TEST:", out)
if err.strip():
    print("ERR:", err[:300])

client.close()

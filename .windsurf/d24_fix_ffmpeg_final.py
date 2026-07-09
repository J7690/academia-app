import paramiko

host = '185.167.97.144'
user = 'root'
pwd = 'Nexiomgroup@Academia0'

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect(host, username=user, password=pwd, timeout=30)

new_assembler = r'''"""
Whiteboard FFmpeg Assembler - Phase C.3 v4 FINAL
- Concat demuxer : 5s par scène
- Profile Baseline level 3.1 (compatibilité Android max)
- Color metadata BT.709 explicite (fix ExoPlayer "Unset color space" crash)
- moov avant mdat via faststart en 2 passes
"""

from pathlib import Path
from typing import List
import subprocess

SECONDS_PER_SCENE = 5
FPS = 24


def assemble_pngs_to_mp4(png_paths: List[Path], output_dir: Path) -> Path:
    if not png_paths:
        raise ValueError("No PNGs provided")

    for p in png_paths:
        if not p.exists():
            raise FileNotFoundError(f"PNG not found: {p}")

    # Fichier concat
    concat_file = output_dir / "concat.txt"
    with open(concat_file, "w") as f:
        for p in png_paths:
            safe = str(p).replace("'", "'\\''")
            f.write(f"file '{safe}'\n")
            f.write(f"duration {SECONDS_PER_SCENE}\n")
        # Répéter le dernier frame pour éviter troncature
        last = str(png_paths[-1]).replace("'", "'\\''")
        f.write(f"file '{last}'\n")

    tmp_mp4 = output_dir / "output_tmp.mp4"
    mp4_path = output_dir / "output.mp4"

    # Passe 1 : encodage avec métadonnées couleur BT.709 complètes
    cmd_encode = [
        "ffmpeg", "-y",
        "-f", "concat",
        "-safe", "0",
        "-i", str(concat_file),
        # Scale + padding portrait + définir espace couleur BT.709
        "-vf", (
            "scale=1080:1920:force_original_aspect_ratio=decrease,"
            "pad=1080:1920:(ow-iw)/2:(oh-ih)/2:color=white,"
            "setsar=1,"
            "format=yuv420p"
        ),
        "-c:v", "libx264",
        "-profile:v", "baseline",
        "-level", "3.1",
        "-pix_fmt", "yuv420p",
        "-r", str(FPS),
        "-preset", "fast",
        "-crf", "28",
        # Métadonnées couleur explicites — fix ExoPlayer "Unset color space"
        "-colorspace", "bt709",
        "-color_primaries", "bt709",
        "-color_trc", "bt709",
        "-color_range", "tv",
        str(tmp_mp4),
    ]

    r = subprocess.run(cmd_encode, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    if r.returncode != 0:
        err = r.stderr.decode(errors='ignore')
        raise RuntimeError(f"FFmpeg encode error (code {r.returncode}): {err[:3000]}")

    # Passe 2 : faststart — déplacer moov avant mdat
    cmd_fast = [
        "ffmpeg", "-y",
        "-i", str(tmp_mp4),
        "-c", "copy",
        "-movflags", "+faststart",
        str(mp4_path),
    ]
    r2 = subprocess.run(cmd_fast, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    if r2.returncode != 0:
        err2 = r2.stderr.decode(errors='ignore')
        raise RuntimeError(f"FFmpeg faststart error: {err2[:3000]}")

    tmp_mp4.unlink(missing_ok=True)

    if not mp4_path.exists():
        raise RuntimeError(f"MP4 not created: {mp4_path}")

    return mp4_path
'''

sftp = client.open_sftp()
with sftp.open('/opt/whiteboard-worker/whiteboard_ffmpeg_assembler.py', 'w') as f:
    f.write(new_assembler)
sftp.close()
print("✅ whiteboard_ffmpeg_assembler.py déployé")

# Validation immédiate via ffprobe
_, stdout, _ = client.exec_command('''cd /opt/whiteboard-worker && python3 << 'PYEOF'
import tempfile, subprocess, json
from pathlib import Path
from whiteboard_png_renderer import render_storyboard_to_pngs
from whiteboard_ffmpeg_assembler import assemble_pngs_to_mp4

storyboard = {
  "scenes": [
    {"id": "sc1", "title": "Les derivees", "order": 0, "duration_ms": 5000,
     "blocks": [
       {"id": "b1", "type": "title", "content": "Introduction aux derivees", "order": 0, "visible": True},
       {"id": "b2", "type": "paragraph", "content": "La derivee mesure le taux de variation d une fonction.", "order": 1, "visible": True}
     ]},
    {"id": "sc2", "title": "Definition", "order": 1, "duration_ms": 5000,
     "blocks": [
       {"id": "b3", "type": "definition", "content": "f prime(x) = lim h->0 (f(x+h)-f(x))/h", "order": 0, "visible": True}
     ]}
  ],
  "renderer": "notebook", "theme": "notebook"
}

p = Path("/tmp/d24final")
p.mkdir(exist_ok=True)
pngs = render_storyboard_to_pngs(storyboard, p)
print(f"PNGs: {len(pngs)}")
mp4 = assemble_pngs_to_mp4(pngs, p)
print(f"MP4 size: {mp4.stat().st_size} bytes")

# ffprobe
r = subprocess.run(
    ["ffprobe", "-v", "quiet", "-print_format", "json",
     "-show_streams", "-show_format", str(mp4)],
    capture_output=True, text=True
)
info = json.loads(r.stdout)
fmt = info.get("format", {})
streams = info.get("streams", [])
print(f"duration: {fmt.get('duration')}s")
for s in streams:
    print(f"codec={s.get('codec_name')} profile={s.get('profile')} level={s.get('level')}")
    print(f"size={s.get('width')}x{s.get('height')} pix_fmt={s.get('pix_fmt')}")
    print(f"color_space={s.get('color_space')} color_transfer={s.get('color_transfer')} color_primaries={s.get('color_primaries')}")
    print(f"color_range={s.get('color_range')}")

# Vérifier ordre atoms
import struct as st
data = mp4.read_bytes()
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
moov_ok = 'moov' in atoms and 'mdat' in atoms and atoms.index('moov') < atoms.index('mdat')
print(f"MOOV_BEFORE_MDAT={moov_ok}")
print("SUCCESS" if moov_ok else "FAIL: moov not before mdat")
PYEOF
''')
out = stdout.read().decode(errors='replace')
print(out)
client.close()

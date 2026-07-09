#!/usr/bin/env python3
import paramiko, sys, time
from datetime import datetime

# Fix encodage Windows console
sys.stdout.reconfigure(encoding='utf-8')

KAMATERA = dict(hostname="185.167.97.144", username="root", password="Nexiomgroup@Academia0", timeout=20)

def ssh(c, cmd, label=""):
    if label:
        print(f"\n{'='*60}\n{label}\n{'='*60}")
    _, o, e = c.exec_command(cmd, timeout=120)
    out = o.read().decode(errors='replace')
    err = e.read().decode(errors='replace')
    if out.strip(): print(out[:6000])
    if err.strip(): print(f"[STDERR] {err[:800]}")
    return out

print(f"D.24 CORRECTIONS v5 - {datetime.now().isoformat()}")

ASSEMBLER_CODE = r'''"""
Whiteboard FFmpeg Assembler - v5 CONFORMITE D.24
C1: concat demuxer, 5s par scene
C2: moov avant mdat (2 passes faststart)
C3: H264 Constrained Baseline level 3.1 (0 B-frames)
C4: Color metadata BT.709 complet
"""
from pathlib import Path
from typing import List
import subprocess

SECONDS_PER_SCENE = 5
FPS = 30


def assemble_pngs_to_mp4(png_paths: List[Path], output_dir: Path) -> Path:
    if not png_paths:
        raise ValueError("No PNGs provided")

    for p in png_paths:
        if not p.exists():
            raise FileNotFoundError(f"PNG not found: {p}")

    concat_file = output_dir / "concat.txt"
    with open(concat_file, "w") as f:
        for p in png_paths:
            safe = str(p).replace("'", "'\\''")
            f.write(f"file '{safe}'\n")
            f.write(f"duration {SECONDS_PER_SCENE}\n")
        last = str(png_paths[-1]).replace("'", "'\\''")
        f.write(f"file '{last}'\n")

    tmp_mp4 = output_dir / "output_tmp.mp4"
    mp4_path = output_dir / "output.mp4"

    cmd_encode = [
        "ffmpeg", "-y",
        "-f", "concat",
        "-safe", "0",
        "-i", str(concat_file),
        "-vf", (
            "scale=1080:1920:force_original_aspect_ratio=decrease,"
            "pad=1080:1920:(ow-iw)/2:(oh-ih)/2:color=white,"
            "setsar=1,"
            "format=yuv420p"
        ),
        "-c:v", "libx264",
        "-profile:v", "baseline",
        "-level:v", "3.1",
        "-pix_fmt", "yuv420p",
        "-r", str(FPS),
        "-g", str(FPS * 2),
        "-preset", "fast",
        "-crf", "28",
        "-colorspace", "bt709",
        "-color_primaries", "bt709",
        "-color_trc", "bt709",
        "-color_range", "tv",
        str(tmp_mp4),
    ]

    r = subprocess.run(cmd_encode, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    if r.returncode != 0:
        err = r.stderr.decode(errors="ignore")
        raise RuntimeError(f"FFmpeg encode error ({r.returncode}): {err[:3000]}")

    cmd_fast = [
        "ffmpeg", "-y",
        "-i", str(tmp_mp4),
        "-c", "copy",
        "-movflags", "+faststart",
        str(mp4_path),
    ]
    r2 = subprocess.run(cmd_fast, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    if r2.returncode != 0:
        err2 = r2.stderr.decode(errors="ignore")
        raise RuntimeError(f"FFmpeg faststart error: {err2[:3000]}")

    tmp_mp4.unlink(missing_ok=True)

    if not mp4_path.exists():
        raise RuntimeError(f"MP4 not created: {mp4_path}")

    return mp4_path
'''

c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect(**KAMATERA)
print("SSH OK")

# Ecrire assembler v5
sftp = c.open_sftp()
with sftp.open('/opt/whiteboard-worker/whiteboard_ffmpeg_assembler.py', 'w') as f:
    f.write(ASSEMBLER_CODE)
sftp.close()
print("whiteboard_ffmpeg_assembler.py v5 ecrit")

# Supprimer pycache
ssh(c, "rm -rf /opt/whiteboard-worker/__pycache__ && echo 'pycache supprime'", "Suppression __pycache__")

# Redemarrer worker
ssh(c, "systemctl restart whiteboard-worker && sleep 4 && systemctl is-active whiteboard-worker && echo 'WORKER ACTIF'",
    "Redemarrage worker systemd")

# Verification contenu deploye
ssh(c, "grep -n 'FPS\\|SECONDS\\|profile\\|level\\|colorspace\\|faststart\\|v5\\|C1\\|C2\\|C3\\|C4' /opt/whiteboard-worker/whiteboard_ffmpeg_assembler.py",
    "Verification parametres deployes")

# Test complet 3 scenes
print("\n" + "="*60)
print("TEST PRODUCTION : 3 scenes = 15s attendues")
print("="*60)

ssh(c, r'''python3 << 'PYEOF'
import subprocess, json
from pathlib import Path
from whiteboard_png_renderer import render_storyboard_to_pngs
from whiteboard_ffmpeg_assembler import assemble_pngs_to_mp4, FPS, SECONDS_PER_SCENE

print(f"Config: FPS={FPS}, SECONDS_PER_SCENE={SECONDS_PER_SCENE}")

storyboard = {
  "scenes": [
    {"id": "s1", "title": "Scene 1", "order": 0, "duration_ms": 5000,
     "blocks": [{"id": "b1", "type": "title", "content": "Derivees - Scene 1", "order": 0, "visible": True}]},
    {"id": "s2", "title": "Scene 2", "order": 1, "duration_ms": 5000,
     "blocks": [{"id": "b2", "type": "paragraph", "content": "Definition et proprietes", "order": 0, "visible": True}]},
    {"id": "s3", "title": "Scene 3", "order": 2, "duration_ms": 5000,
     "blocks": [{"id": "b3", "type": "definition", "content": "f prime(x) = lim (f(x+h)-f(x))/h", "order": 0, "visible": True}]},
  ],
  "renderer": "notebook", "theme": "notebook"
}

p = Path("/tmp/d24_v5")
p.mkdir(exist_ok=True)
pngs = render_storyboard_to_pngs(storyboard, p)
print(f"PNGs: {len(pngs)}")

mp4 = assemble_pngs_to_mp4(pngs, p)
print(f"Taille MP4: {mp4.stat().st_size} bytes")

r = subprocess.run(
    ["ffprobe", "-v", "quiet", "-print_format", "json", "-show_streams", "-show_format", str(mp4)],
    capture_output=True, text=True
)
info = json.loads(r.stdout)
fmt = info["format"]
st  = info["streams"][0]

dur     = float(fmt["duration"])
profile = st.get("profile","?")
level   = st.get("level","?")
bframes = st.get("has_b_frames","?")
fps     = st.get("r_frame_rate","?")
cs      = st.get("color_space","NON DEFINI")
ct      = st.get("color_transfer","NON DEFINI")
cp      = st.get("color_primaries","NON DEFINI")
cr      = st.get("color_range","NON DEFINI")

# Atoms
data = mp4.read_bytes()
off, atoms = 0, []
while off < len(data)-8:
    sz = int.from_bytes(data[off:off+4],'big')
    nm = data[off+4:off+8].decode('ascii',errors='?')
    atoms.append(nm)
    if sz < 8: break
    off += sz
    if off > 500000: break

moov_ok = 'moov' in atoms and 'mdat' in atoms and atoms.index('moov') < atoms.index('mdat')

print("="*50)
print(f"DUREE          : {dur:.3f}s  (attendu ~15s)")
print(f"PROFILE        : {profile} (attendu: Constrained Baseline)")
print(f"LEVEL          : {level} (attendu: 31)")
print(f"B-FRAMES       : {bframes} (attendu: 0)")
print(f"FPS            : {fps} (attendu: 30/1)")
print(f"COLOR_SPACE    : {cs}")
print(f"COLOR_TRANSFER : {ct}")
print(f"COLOR_PRIMARIES: {cp}")
print(f"COLOR_RANGE    : {cr}")
print(f"ATOMS          : {','.join(atoms)}")
print(f"MOOV AVANT MDAT: {moov_ok}")
print("="*50)

ok = dur >= 14 and moov_ok and str(level) == "31" and int(bframes) == 0
print("RESULTAT: SUCCES" if ok else "RESULTAT: ECHEC")
PYEOF
''', "")

# Test 9 scenes (comme le render 15d0b7ed - 9 scenes)
ssh(c, r'''python3 << 'PYEOF'
import subprocess, json
from pathlib import Path
from whiteboard_png_renderer import render_storyboard_to_pngs
from whiteboard_ffmpeg_assembler import assemble_pngs_to_mp4

scenes = []
for i in range(9):
    scenes.append({
        "id": f"s{i}", "title": f"Scene {i+1}", "order": i, "duration_ms": 5000,
        "blocks": [{"id": f"b{i}", "type": "paragraph",
                    "content": f"Contenu scene {i+1} - derivees d une fonction", "order": 0, "visible": True}]
    })

storyboard = {"scenes": scenes, "renderer": "notebook", "theme": "notebook"}

p = Path("/tmp/d24_v5_9sc")
p.mkdir(exist_ok=True)
pngs = render_storyboard_to_pngs(storyboard, p)
mp4  = assemble_pngs_to_mp4(pngs, p)

r = subprocess.run(
    ["ffprobe","-v","quiet","-print_format","json","-show_format",str(mp4)],
    capture_output=True, text=True
)
fmt = json.loads(r.stdout)["format"]
dur = float(fmt["duration"])
sz  = mp4.stat().st_size

print(f"9 scenes | duree={dur:.2f}s (attendu=45s) | taille={sz} bytes")
print("OK" if dur >= 44 else f"ECHEC: dur={dur}")
PYEOF
''', "Test 9 scenes (meme config que render 15d0b7ed - attendu 45s)")

# Logs worker post-restart
ssh(c, "journalctl -u whiteboard-worker --no-pager -n 15 2>/dev/null | tail -15",
    "Logs worker post-restart")

c.close()
print("\nD.24 corrections terminees.")

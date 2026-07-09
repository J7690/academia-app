#!/usr/bin/env python3
"""
D.24 FIX v6 - Correction colorspace SMPTE170M vs BT709
Cause: FFmpeg injecte silencieusement un filtre scale (smpte170m) sur les PNGs sans profil couleur
Solution (Canva Engineering / ExoPlayer issue tracker):
  Utiliser le filtre colorspace avec conversion explicite sRGB -> BT709
  ET forcer -x264-params colorprim=bt709:transfer=bt709:colormatrix=bt709
"""
import paramiko, sys
sys.stdout.reconfigure(encoding='utf-8')

KAMATERA = dict(hostname="185.167.97.144", username="root", password="Nexiomgroup@Academia0", timeout=20)

def ssh(c, cmd, label=""):
    if label: print(f"\n{'='*60}\n{label}\n{'='*60}")
    _, o, e = c.exec_command(cmd, timeout=120)
    out = o.read().decode(errors='replace')
    err = e.read().decode(errors='replace')
    if out.strip(): print(out[:6000])
    if err.strip(): print(f"[STDERR] {err[:500]}")
    return out

# Assembler v6 : correction colorspace SMPTE170M -> BT709 pure
ASSEMBLER_V6 = r'''"""
Whiteboard FFmpeg Assembler - v6 CORRECTION D.24
CAUSE: PNG sans profil couleur -> FFmpeg injecte scale(smpte170m) -> conflit BT709+SMPTE170M -> ExoPlayer crash
FIX:
  - Filtre colorspace explicite: conversion sRGB->BT709 avec gamma
  - -x264-params pour forcer le tagging BT709 pur dans le bitstream H264
  - Toutes les corrections precedentes maintenues (C1-C5)
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

    # C1: concat demuxer avec duree explicite
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

    # v6: FIX colorspace
    # Le filtre colorspace convertit explicitement sRGB -> BT709 avec gamma
    # Cela empeche FFmpeg d'injecter silencieusement le scale avec smpte170m
    cmd_encode = [
        "ffmpeg", "-y",
        "-f", "concat",
        "-safe", "0",
        "-i", str(concat_file),
        "-vf", (
            # 1. Scale + pad (reste inchange)
            "scale=1080:1920:force_original_aspect_ratio=decrease,"
            "pad=1080:1920:(ow-iw)/2:(oh-ih)/2:color=white,"
            "setsar=1,"
            # 2. Conversion couleur EXPLICITE sRGB -> BT709
            # itrc=srgb: declare que la source est sRGB (PNG)
            # all=bt709: cible BT709
            # Cela evite le scale auto avec smpte170m
            "colorspace=all=bt709:iall=bt709:itrc=srgb,"
            # 3. Format final YUV420P
            "format=yuv420p"
        ),
        "-c:v", "libx264",
        "-profile:v", "baseline",   # C3: Baseline = 0 B-frames
        "-level:v", "3.1",          # C3: level 3.1
        "-pix_fmt", "yuv420p",
        "-r", str(FPS),
        "-g", str(FPS * 2),
        "-preset", "fast",
        "-crf", "28",
        # Metadata couleur niveau conteneur
        "-colorspace", "bt709",
        "-color_primaries", "bt709",
        "-color_trc", "bt709",
        "-color_range", "tv",
        # v6: Forcer le tagging BT709 pur dans le bitstream H264 (x264 VUI)
        # Cela garantit que ExoPlayer voit BT709 partout, sans SMPTE170M
        "-x264-params", "colorprim=bt709:transfer=bt709:colormatrix=bt709:fullrange=0",
        str(tmp_mp4),
    ]

    r = subprocess.run(cmd_encode, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    if r.returncode != 0:
        err = r.stderr.decode(errors="ignore")
        raise RuntimeError(f"FFmpeg encode error ({r.returncode}): {err[:3000]}")

    # C2: moov avant mdat (faststart)
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

TEST_V6 = r'''#!/usr/bin/env python3
import subprocess, json, sys
from pathlib import Path
sys.path.insert(0, '/opt/whiteboard-worker')
from whiteboard_png_renderer import render_storyboard_to_pngs
from whiteboard_ffmpeg_assembler import assemble_pngs_to_mp4, FPS, SECONDS_PER_SCENE

print(f"CONFIG: FPS={FPS} SECONDS_PER_SCENE={SECONDS_PER_SCENE}")

storyboard = {
  "scenes": [
    {"id": "s1", "title": "Scene 1", "order": 0, "duration_ms": 5000,
     "blocks": [{"id": "b1", "type": "title", "content": "Test v6 - BT709 pur", "order": 0, "visible": True}]},
    {"id": "s2", "title": "Scene 2", "order": 1, "duration_ms": 5000,
     "blocks": [{"id": "b2", "type": "paragraph", "content": "Correction colorspace sRGB vers BT709", "order": 0, "visible": True}]},
    {"id": "s3", "title": "Scene 3", "order": 2, "duration_ms": 5000,
     "blocks": [{"id": "b3", "type": "definition", "content": "ExoPlayer: plus de SMPTE 170M", "order": 0, "visible": True}]},
  ],
  "renderer": "notebook", "theme": "notebook"
}

p = Path("/tmp/d24_v6_test")
p.mkdir(exist_ok=True)
pngs = render_storyboard_to_pngs(storyboard, p)
print(f"PNGs: {len(pngs)}")

mp4 = assemble_pngs_to_mp4(pngs, p)
print(f"Taille: {mp4.stat().st_size} bytes")

r = subprocess.run(
    ["ffprobe", "-v", "quiet", "-print_format", "json", "-show_streams", "-show_format", str(mp4)],
    capture_output=True, text=True
)
info = json.loads(r.stdout)
fmt = info["format"]
st  = info["streams"][0]

dur  = float(fmt["duration"])
cs   = st.get("color_space","NON DEFINI")
ct   = st.get("color_transfer","NON DEFINI")
cp   = st.get("color_primaries","NON DEFINI")
cr   = st.get("color_range","NON DEFINI")
prof = st.get("profile","?")
lev  = st.get("level","?")
bfr  = st.get("has_b_frames","?")

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

print("="*60)
print(f"  DUREE          : {dur:.3f}s  OK={dur>=14}")
print(f"  PROFILE        : {prof}")
print(f"  LEVEL          : {lev} OK={str(lev)=='31'}")
print(f"  B-FRAMES       : {bfr} OK={str(bfr)=='0'}")
print(f"  COLOR_SPACE    : {cs} OK={cs=='bt709'}")
print(f"  COLOR_TRANSFER : {ct} OK={ct=='bt709'}")
print(f"  COLOR_PRIMARIES: {cp} OK={cp=='bt709'}")
print(f"  COLOR_RANGE    : {cr}")
print(f"  ATOMS          : {','.join(atoms)}")
print(f"  MOOV<MDAT      : {moov_ok}")
print("="*60)

checks = [dur>=14, str(lev)=='31', str(bfr)=='0', moov_ok, cs=='bt709', ct=='bt709', cp=='bt709']
fails = [i for i,ok in enumerate(checks) if not ok]
labels = ["dur>=14","level=31","b-frames=0","moov<mdat","cs=bt709","ct=bt709","cp=bt709"]

if not fails:
    print("RESULTAT v6: SUCCES COMPLET - BT709 pur, 0 SMPTE170M")
else:
    print(f"RESULTAT v6: ECHEC - {[labels[i] for i in fails]}")

# Verif bitstream: chercher smpte170m dans les infos detaillees
r2 = subprocess.run(
    ["ffprobe", "-v", "verbose", "-show_streams", str(mp4)],
    capture_output=True, text=True
)
if "smpte170m" in r2.stdout.lower() or "smpte170m" in r2.stderr.lower():
    print("ATTENTION: smpte170m encore present dans le bitstream!")
else:
    print("OK: Aucune trace de smpte170m dans le bitstream")
'''

c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect(**KAMATERA)
print("SSH OK")

# Deployer assembler v6
sftp = c.open_sftp()
with sftp.open('/opt/whiteboard-worker/whiteboard_ffmpeg_assembler.py', 'w') as f:
    f.write(ASSEMBLER_V6)
with sftp.open('/tmp/d24_test_v6.py', 'w') as f:
    f.write(TEST_V6)
sftp.close()
print("Assembler v6 deploye")

# Supprimer pycache
ssh(c, "rm -rf /opt/whiteboard-worker/__pycache__ && echo 'pycache supprime'", "Nettoyage pycache")

# Verif que colorspace filter est disponible dans FFmpeg
ssh(c, "ffmpeg -filters 2>/dev/null | grep -i colorspace | head -5", "Verification filtre colorspace disponible")

# Redemarrer worker
ssh(c, "systemctl restart whiteboard-worker && sleep 3 && systemctl is-active whiteboard-worker && echo 'WORKER ACTIF'",
    "Redemarrage worker v6")

# Test v6
ssh(c, "cd /opt/whiteboard-worker && python3 /tmp/d24_test_v6.py", "TEST v6 - Validation BT709 pur")

# Logs
ssh(c, "journalctl -u whiteboard-worker --no-pager -n 8 2>/dev/null | tail -8", "Logs worker v6")

c.close()
print("\nv6 deploye. Relance un render depuis l'app.")

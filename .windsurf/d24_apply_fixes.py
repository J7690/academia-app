#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
MISSION D.24 - APPLICATION DES CORRECTIONS
C1: Concat demuxer avec duration 5s par scene
C2: moov avant mdat (faststart 2 passes)
C3: Profile Baseline level 3.1
C4: Color space BT.709 complet
C5: Redemarrage worker
"""
import paramiko, json, struct, requests, time
from datetime import datetime

KAMATERA = dict(hostname="185.167.97.144", username="root", password="Nexiomgroup@Academia0", timeout=20)
SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SKEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": SKEY, "Authorization": f"Bearer {SKEY}", "Content-Type": "application/json"}

SEP = "=" * 60

def s(t): print(f"\n{SEP}\n{t}\n{SEP}")

def ssh(c, cmd, label=""):
    if label: s(label)
    _, o, e = c.exec_command(cmd, timeout=90)
    out = o.read().decode(errors='replace')
    err = e.read().decode(errors='replace')
    if out.strip(): print(out[:5000])
    if err.strip(): print(f"[STDERR] {err[:800]}")
    return out

print(f"D.24 CORRECTIONS - {datetime.now().isoformat()}")

# -------------------------------------------------------
# ASSEMBLER FINAL CONFORME (C1+C2+C3+C4)
# -------------------------------------------------------
ASSEMBLER_CODE = '''"""
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
FPS = 30   # conforme cahier des charges (30fps)


def assemble_pngs_to_mp4(png_paths: List[Path], output_dir: Path) -> Path:
    if not png_paths:
        raise ValueError("No PNGs provided")

    for p in png_paths:
        if not p.exists():
            raise FileNotFoundError(f"PNG not found: {p}")

    # C1 : concat demuxer avec duree explicite par scene
    concat_file = output_dir / "concat.txt"
    with open(concat_file, "w") as f:
        for p in png_paths:
            safe = str(p).replace("\\\\", "/")
            f.write(f"file \\'{safe}\\'\\n")
            f.write(f"duration {SECONDS_PER_SCENE}\\n")
        # Repeter le dernier frame (fix troncature derniere scene)
        last = str(png_paths[-1]).replace("\\\\", "/")
        f.write(f"file \\'{last}\\'\\n")

    tmp_mp4 = output_dir / "output_tmp.mp4"
    mp4_path = output_dir / "output.mp4"

    # Passe 1 : encodage
    # C3: Constrained Baseline level 3.1 => 0 B-frames, ref=1
    # C4: metadata couleur BT.709 explicite
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
        "-profile:v", "baseline",   # C3: Baseline => pas de B-frames
        "-level:v", "3.1",          # C3: level 3.1
        "-pix_fmt", "yuv420p",
        "-r", str(FPS),
        "-g", str(FPS * 2),         # GOP = 2 secondes
        "-preset", "fast",
        "-crf", "28",
        # C4: metadata couleur BT.709
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

    # Passe 2 : C2: moov avant mdat (faststart)
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

# Ecrire le nouveau whiteboard_ffmpeg_assembler.py
sftp = c.open_sftp()
with sftp.open('/opt/whiteboard-worker/whiteboard_ffmpeg_assembler.py', 'w') as f:
    f.write(ASSEMBLER_CODE)
sftp.close()
print("whiteboard_ffmpeg_assembler.py deploye (v5 D.24)")

# C5 : Redemarrer le worker pour vider le __pycache__
s("C5 : Redemarrage du worker systemd")
ssh(c, "systemctl restart whiteboard-worker && sleep 3 && systemctl status whiteboard-worker --no-pager | head -20",
    "Restart + status")

# Vider le pycache
ssh(c, "rm -rf /opt/whiteboard-worker/__pycache__ && echo 'pycache vide'",
    "Suppression __pycache__")

# Verifier le contenu deploye
ssh(c, "head -10 /opt/whiteboard-worker/whiteboard_ffmpeg_assembler.py && echo '...' && grep 'FPS\\|SECONDS\\|profile\\|level\\|colorspace\\|faststart' /opt/whiteboard-worker/whiteboard_ffmpeg_assembler.py",
    "Verification contenu deploye")

# Test rapide : generer un MP4 de test et ffprobe
ssh(c, '''python3 << 'PYEOF'
import subprocess, json, struct
from pathlib import Path
from whiteboard_png_renderer import render_storyboard_to_pngs
from whiteboard_ffmpeg_assembler import assemble_pngs_to_mp4

storyboard = {
  "scenes": [
    {"id": "s1", "title": "Scene 1", "order": 0, "duration_ms": 5000,
     "blocks": [{"id": "b1", "type": "title", "content": "Test D24 - Scene 1", "order": 0, "visible": True}]},
    {"id": "s2", "title": "Scene 2", "order": 1, "duration_ms": 5000,
     "blocks": [{"id": "b2", "type": "paragraph", "content": "Correction appliquee - v5", "order": 0, "visible": True}]},
    {"id": "s3", "title": "Scene 3", "order": 2, "duration_ms": 5000,
     "blocks": [{"id": "b3", "type": "definition", "content": "15 secondes attendues", "order": 0, "visible": True}]},
  ],
  "renderer": "notebook", "theme": "notebook"
}

p = Path("/tmp/d24_v5_test")
p.mkdir(exist_ok=True)
pngs = render_storyboard_to_pngs(storyboard, p)
print(f"PNGs generes: {len(pngs)}")
mp4 = assemble_pngs_to_mp4(pngs, p)
print(f"MP4 taille: {mp4.stat().st_size} bytes")

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
for st in streams:
    print(f"codec={st.get('codec_name')} profile={st.get('profile')} level={st.get('level')}")
    print(f"resolution={st.get('width')}x{st.get('height')} pix_fmt={st.get('pix_fmt')}")
    print(f"has_b_frames={st.get('has_b_frames')} nb_frames={st.get('nb_frames')}")
    print(f"color_space={st.get('color_space')} color_transfer={st.get('color_transfer')} color_primaries={st.get('color_primaries')}")
    print(f"color_range={st.get('color_range')} r_frame_rate={st.get('r_frame_rate')}")

# Verif atoms
data = mp4.read_bytes()
offset = 0
atoms = []
while offset < len(data) - 8:
    sz = int.from_bytes(data[offset:offset+4], 'big')
    nm = data[offset+4:offset+8].decode('ascii', errors='?')
    atoms.append(nm)
    if sz < 8: break
    offset += sz
    if offset > 500000: break
print(f"ATOMS: {','.join(atoms)}")
moov_ok = 'moov' in atoms and 'mdat' in atoms and atoms.index('moov') < atoms.index('mdat')
print(f"MOOV_AVANT_MDAT: {moov_ok}")

# Verdict
dur = float(fmt.get('duration', 0))
expected = 3 * 5  # 3 scenes x 5s
ok = dur >= expected - 1
print(f"DUREE OK: {ok} ({dur:.2f}s, attendu ~{expected}s)")
print("=== TEST V5 : SUCCES ===" if ok and moov_ok else "=== TEST V5 : ECHEC ===")
PYEOF
''', "Test MP4 v5 complet (3 scenes = 15s attendues)")

# Logs worker apres restart
ssh(c, "sleep 5 && journalctl -u whiteboard-worker --no-pager -n 20 2>/dev/null | tail -20",
    "Logs worker apres redemarrage")

c.close()
print("\nCorrections appliquees. Worker redémarre avec v5 D.24.")

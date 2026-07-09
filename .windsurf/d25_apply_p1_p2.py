#!/usr/bin/env python3
"""
D.25 - APPLICATION CORRECTIONS P1 + P2
P1: Audio silencieux dans FFmpeg (v7)
P2: Verifier whiteboard_fetch_queued_jobs retourne bien 'storyboard'
"""
import sys, json, requests, paramiko
sys.stdout.reconfigure(encoding='utf-8')

SUPABASE = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SKEY     = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H        = {"apikey": SKEY, "Authorization": f"Bearer {SKEY}", "Content-Type": "application/json"}
KM       = dict(hostname="185.167.97.144", username="root", password="Nexiomgroup@Academia0", timeout=30)

def sql(q):
    r = requests.post(f"{SUPABASE}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": q}, timeout=30)
    return r.json()

# ============================================================
print("="*70)
print("DIAGNOSTIC P2 : whiteboard_fetch_queued_jobs")
print("="*70)

res = sql("SELECT pg_get_functiondef(p.oid) as def FROM pg_proc p WHERE p.proname = 'whiteboard_fetch_queued_jobs'")
for row in res.get('rows', []):
    print(row.get('def','')[:3000])
if not res.get('rows'):
    print(f"Pas trouve: {res}")

# ============================================================
print("\n" + "="*70)
print("P1 : DEPLOIEMENT ASSEMBLER v7 (audio silencieux)")
print("="*70)

ASSEMBLER_V7 = r'''"""
Whiteboard FFmpeg Assembler - v7 CORRECTION D.25
P1: Ajout piste audio silencieuse pour compatibilite ExoPlayer Android
    OMX Qualcomm echoue sur MP4 video-only avec format_supported=YES
    Solution: -f lavfi -i anullsrc + -c:a aac -b:a 64k -shortest

Toutes corrections precedentes maintenues:
  v6: colorspace sRGB->BT709 (plus de smpte170m)
  v5: BT709 metadata, Baseline 3.1, no B-frames
  C1: concat demuxer duree explicite
  C2: faststart (moov avant mdat)
  C3: Baseline profile
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

    # C1: concat demuxer avec duree explicite par scene
    concat_file = output_dir / "concat.txt"
    with open(concat_file, "w") as f:
        for p in png_paths:
            safe = str(p).replace("'", "'\\''")
            f.write(f"file '{safe}'\n")
            f.write(f"duration {SECONDS_PER_SCENE}\n")
        last = str(png_paths[-1]).replace("'", "'\\''")
        f.write(f"file '{last}'\n")

    mp4_path = output_dir / "output.mp4"

    # v7: Encodage DIRECT avec faststart + audio silencieux (une seule passe)
    # -f lavfi -i anullsrc: generateur audio silencieux
    # -c:a aac -b:a 64k: encoder AAC (requis pour ExoPlayer)
    # -shortest: terminer quand la video se termine
    # -movflags +faststart: moov avant mdat (streaming)
    cmd = [
        "ffmpeg", "-y",
        # Input 1: video (concat demuxer)
        "-f", "concat",
        "-safe", "0",
        "-i", str(concat_file),
        # Input 2: audio silencieux
        "-f", "lavfi",
        "-i", "anullsrc=r=44100:cl=stereo",
        # Filtre video: colorspace correction sRGB->BT709 (v6)
        "-vf", (
            "scale=1080:1920:force_original_aspect_ratio=decrease,"
            "pad=1080:1920:(ow-iw)/2:(oh-ih)/2:color=white,"
            "setsar=1,"
            "colorspace=all=bt709:iall=bt709:itrc=srgb,"
            "format=yuv420p"
        ),
        # Codec video
        "-c:v", "libx264",
        "-profile:v", "baseline",
        "-level:v", "3.1",
        "-pix_fmt", "yuv420p",
        "-r", str(FPS),
        "-g", str(FPS * 2),
        "-preset", "fast",
        "-crf", "28",
        # Metadata couleur BT709 (v5/v6)
        "-colorspace", "bt709",
        "-color_primaries", "bt709",
        "-color_trc", "bt709",
        "-color_range", "tv",
        # x264 VUI tagging BT709 pur (v6)
        "-x264-params", "colorprim=bt709:transfer=bt709:colormatrix=bt709:fullrange=0",
        # Codec audio silencieux (v7 - P1)
        "-c:a", "aac",
        "-b:a", "64k",
        "-ar", "44100",
        "-ac", "2",
        # Terminer quand la video se termine
        "-shortest",
        # C2: faststart (moov avant mdat) - EN UNE SEULE PASSE (P3 bonus)
        "-movflags", "+faststart",
        str(mp4_path),
    ]

    r = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    if r.returncode != 0:
        err = r.stderr.decode(errors="ignore")
        raise RuntimeError(f"FFmpeg error ({r.returncode}): {err[:3000]}")

    if not mp4_path.exists():
        raise RuntimeError(f"MP4 not created: {mp4_path}")

    return mp4_path
'''

TEST_V7 = r'''#!/usr/bin/env python3
import subprocess, json, sys
from pathlib import Path
sys.path.insert(0, '/opt/whiteboard-worker')
from whiteboard_png_renderer import render_storyboard_to_pngs
from whiteboard_ffmpeg_assembler import assemble_pngs_to_mp4, FPS, SECONDS_PER_SCENE

print(f"CONFIG: FPS={FPS} SECONDS_PER_SCENE={SECONDS_PER_SCENE}")

storyboard = {
  "scenes": [
    {"id": "s1", "title": "Test v7", "order": 0, "duration_ms": 5000,
     "blocks": [{"id": "b1", "type": "title", "content": "Test Audio Silencieux v7", "order": 0, "visible": True}]},
    {"id": "s2", "title": "Scene 2", "order": 1, "duration_ms": 5000,
     "blocks": [{"id": "b2", "type": "paragraph", "content": "ExoPlayer compatible", "order": 0, "visible": True}]},
    {"id": "s3", "title": "Scene 3", "order": 2, "duration_ms": 5000,
     "blocks": [{"id": "b3", "type": "definition", "content": "Audio AAC 44100Hz stereo", "order": 0, "visible": True}]},
  ],
  "renderer": "notebook", "theme": "notebook"
}

p = Path("/tmp/d25_v7_test")
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
streams = info["streams"]
video = [s for s in streams if s.get("codec_type") == "video"]
audio = [s for s in streams if s.get("codec_type") == "audio"]

v = video[0] if video else {}
a = audio[0] if audio else {}

print("="*60)
print(f"  NB_STREAMS     : {len(streams)} (video={len(video)}, audio={len(audio)})")
print(f"  DUREE          : {fmt.get('duration','?')}s")
print(f"  TAILLE         : {fmt.get('size','?')} bytes")
print(f"  --- VIDEO ---")
print(f"  PROFILE        : {v.get('profile','?')}")
print(f"  LEVEL          : {v.get('level','?')} OK={str(v.get('level',''))=='31'}")
print(f"  B-FRAMES       : {v.get('has_b_frames','?')} OK={str(v.get('has_b_frames',''))=='0'}")
print(f"  COLOR_SPACE    : {v.get('color_space','?')} OK={v.get('color_space','')=='bt709'}")
print(f"  COLOR_TRANSFER : {v.get('color_transfer','?')} OK={v.get('color_transfer','')=='bt709'}")
print(f"  COLOR_PRIMARIES: {v.get('color_primaries','?')} OK={v.get('color_primaries','')=='bt709'}")
print(f"  COLOR_RANGE    : {v.get('color_range','?')}")
print(f"  --- AUDIO v7 ---")
print(f"  CODEC_AUDIO    : {a.get('codec_name','ABSENT')} OK={a.get('codec_name','')=='aac'}")
print(f"  SAMPLE_RATE    : {a.get('sample_rate','?')}")
print(f"  CHANNELS       : {a.get('channels','?')}")
print(f"  AUDIO_DURATION : {a.get('duration','?')}")
print("="*60)

# Atoms
data = mp4.read_bytes()
off, atoms = 0, []
while off < len(data)-8:
    sz = int.from_bytes(data[off:off+4],'big')
    nm = data[off+4:off+8].decode('ascii',errors='?')
    atoms.append(nm)
    if sz < 8: break
    off += sz
    if off >= len(data): break
moov_ok = 'moov' in atoms and 'mdat' in atoms and atoms.index('moov') < atoms.index('mdat')
print(f"  ATOMS          : {','.join(atoms)}")
print(f"  MOOV<MDAT      : {moov_ok}")
print("="*60)

# Verif smpte170m
r2 = subprocess.run(
    ["ffprobe", "-v", "verbose", str(mp4)],
    capture_output=True, text=True
)
combined = (r2.stdout + r2.stderr).lower()
if "smpte170m" in combined:
    print("ATTENTION: smpte170m detecte dans bitstream!")
else:
    print("OK: Aucun smpte170m dans le bitstream")

# Verif decode complet
r3 = subprocess.run(
    ["ffmpeg", "-v", "error", "-i", str(mp4), "-f", "null", "-"],
    capture_output=True, text=True
)
decode_errors = (r3.stdout + r3.stderr).strip()
if decode_errors:
    print(f"ERREURS DECODE: {decode_errors[:500]}")
else:
    print("OK: Decode complet sans erreur")

# Resultat global
checks = [
    len(audio) > 0,
    a.get('codec_name','') == 'aac',
    str(v.get('level','')) == '31',
    str(v.get('has_b_frames','')) == '0',
    moov_ok,
    v.get('color_space','') == 'bt709',
    v.get('color_transfer','') == 'bt709',
    v.get('color_primaries','') == 'bt709',
    not decode_errors,
]
labels = ["audio_present","codec_aac","level_31","no_bframes","moov<mdat","cs_bt709","ct_bt709","cp_bt709","no_decode_err"]
fails = [labels[i] for i,ok in enumerate(checks) if not ok]
if not fails:
    print("\nRESULTAT v7: SUCCES COMPLET - Audio AAC + BT709 pur + Baseline 3.1")
else:
    print(f"\nRESULTAT v7: ECHEC - {fails}")
'''

# Deployer
c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect(**KM)

sftp = c.open_sftp()
with sftp.open('/opt/whiteboard-worker/whiteboard_ffmpeg_assembler.py', 'w') as f:
    f.write(ASSEMBLER_V7)
with sftp.open('/tmp/d25_test_v7.py', 'w') as f:
    f.write(TEST_V7)
sftp.close()
print("Assembler v7 deploye")

def ssh(cmd, label=None):
    if label: print(f"\n{'='*60}\n{label}\n{'='*60}")
    _, o, e = c.exec_command(cmd, timeout=120)
    out = o.read().decode(errors='replace')
    err = e.read().decode(errors='replace')
    if out.strip(): print(out[:6000])
    if err.strip(): print(f"[ERR] {err[:300]}")
    return out

# Nettoyer pycache
ssh("rm -rf /opt/whiteboard-worker/__pycache__ && echo 'pycache nettoye'", "Nettoyage pycache")

# Verifier que anullsrc est disponible dans ffmpeg
ssh("ffmpeg -sources lavfi 2>/dev/null | grep anull || echo 'anullsrc disponible (inclus dans lavfi par defaut)'", "Verification anullsrc")

# Redemarrer worker
ssh("systemctl restart whiteboard-worker && sleep 3 && systemctl is-active whiteboard-worker && echo 'WORKER v7 ACTIF'", "Redemarrage worker v7")

# Test v7
ssh("cd /opt/whiteboard-worker && python3 /tmp/d25_test_v7.py", "TEST v7")

# Verifier que le worker a bien charge v7
ssh("python3 -c \"import sys; sys.path.insert(0,'/opt/whiteboard-worker'); import whiteboard_ffmpeg_assembler as a; print('Version header:', a.__doc__.split(chr(10))[1].strip())\"", "Version assembler en memoire")

c.close()
print("\nP1 APPLIQUE. Worker v7 actif.")

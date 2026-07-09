#!/usr/bin/env python3
import paramiko, sys
sys.stdout.reconfigure(encoding='utf-8')

KAMATERA = dict(hostname="185.167.97.144", username="root", password="Nexiomgroup@Academia0", timeout=20)

def ssh(c, cmd, label=""):
    if label: print(f"\n{'='*60}\n{label}\n{'='*60}")
    _, o, e = c.exec_command(cmd, timeout=120)
    out = o.read().decode(errors='replace')
    err = e.read().decode(errors='replace')
    if out.strip(): print(out[:6000])
    if err.strip(): print(f"[STDERR] {err[:1000]}")
    return out

c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect(**KAMATERA)
print("SSH OK")

# Ecrire le script de test dans /opt/whiteboard-worker/
TEST_SCRIPT = r'''#!/usr/bin/env python3
import subprocess, json, sys
from pathlib import Path
sys.path.insert(0, '/opt/whiteboard-worker')
from whiteboard_png_renderer import render_storyboard_to_pngs
from whiteboard_ffmpeg_assembler import assemble_pngs_to_mp4, FPS, SECONDS_PER_SCENE

print(f"CONFIG: FPS={FPS} SECONDS_PER_SCENE={SECONDS_PER_SCENE}")

# Test 1: 3 scenes = 15s
storyboard_3 = {
  "scenes": [
    {"id": "s1", "title": "Scene 1", "order": 0, "duration_ms": 5000,
     "blocks": [{"id": "b1", "type": "title", "content": "Test D24 - Scene 1", "order": 0, "visible": True}]},
    {"id": "s2", "title": "Scene 2", "order": 1, "duration_ms": 5000,
     "blocks": [{"id": "b2", "type": "paragraph", "content": "Correction D.24 appliquee", "order": 0, "visible": True}]},
    {"id": "s3", "title": "Scene 3", "order": 2, "duration_ms": 5000,
     "blocks": [{"id": "b3", "type": "definition", "content": "Baseline level 3.1 - 30fps", "order": 0, "visible": True}]},
  ],
  "renderer": "notebook", "theme": "notebook"
}

p3 = Path("/tmp/d24_test_3sc")
p3.mkdir(exist_ok=True)
pngs = render_storyboard_to_pngs(storyboard_3, p3)
print(f"PNGs generes: {len(pngs)}")
mp4 = assemble_pngs_to_mp4(pngs, p3)
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
fps_r   = st.get("r_frame_rate","?")
cs      = st.get("color_space","NON DEFINI")
ct      = st.get("color_transfer","NON DEFINI")
cp      = st.get("color_primaries","NON DEFINI")
cr      = st.get("color_range","NON DEFINI")
nb_f    = st.get("nb_frames","?")

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

print("="*55)
print(f"  TEST 3 SCENES (attendu: 15s, Baseline, moov<mdat)")
print("="*55)
print(f"  DUREE          : {dur:.3f}s  | OK={dur >= 14}")
print(f"  PROFILE        : {profile}")
print(f"  LEVEL          : {level}    | OK={str(level)=='31'}")
print(f"  B-FRAMES       : {bframes}  | OK={str(bframes)=='0'}")
print(f"  FPS            : {fps_r}")
print(f"  NB_FRAMES      : {nb_f}")
print(f"  COLOR_SPACE    : {cs}")
print(f"  COLOR_TRANSFER : {ct}")
print(f"  COLOR_PRIMARIES: {cp}")
print(f"  COLOR_RANGE    : {cr}")
print(f"  ATOMS          : {','.join(atoms)}")
print(f"  MOOV_AVANT_MDAT: {moov_ok}")
print("="*55)

checks = [
    dur >= 14,
    str(level) == "31",
    str(bframes) == "0",
    moov_ok,
    cs == "bt709",
]
fails = [i for i,ok in enumerate(checks) if not ok]
if not fails:
    print("  RESULTAT GLOBAL: SUCCES - MP4 conforme Android")
else:
    labels = ["duree>=14s","level=31","b-frames=0","moov<mdat","color_space=bt709"]
    print(f"  RESULTAT: ECHEC - fails: {[labels[i] for i in fails]}")
'''

sftp = c.open_sftp()
with sftp.open('/tmp/d24_test_v5.py', 'w') as f:
    f.write(TEST_SCRIPT)
sftp.close()

ssh(c, "cd /opt/whiteboard-worker && python3 /tmp/d24_test_v5.py", "TEST V5 - Validation complete")

# Test 9 scenes
TEST_9SC = r'''#!/usr/bin/env python3
import subprocess, json, sys
from pathlib import Path
sys.path.insert(0, '/opt/whiteboard-worker')
from whiteboard_png_renderer import render_storyboard_to_pngs
from whiteboard_ffmpeg_assembler import assemble_pngs_to_mp4

scenes = [
    {"id": f"s{i}", "title": f"Scene {i+1}", "order": i, "duration_ms": 5000,
     "blocks": [{"id": f"b{i}", "type": "paragraph",
                 "content": f"Derivees - scene {i+1}/9", "order": 0, "visible": True}]}
    for i in range(9)
]
storyboard = {"scenes": scenes, "renderer": "notebook", "theme": "notebook"}

p = Path("/tmp/d24_test_9sc")
p.mkdir(exist_ok=True)
pngs = render_storyboard_to_pngs(storyboard, p)
mp4  = assemble_pngs_to_mp4(pngs, p)

r = subprocess.run(["ffprobe","-v","quiet","-print_format","json","-show_format",str(mp4)],
                   capture_output=True, text=True)
fmt = json.loads(r.stdout)["format"]
dur = float(fmt["duration"])
sz  = mp4.stat().st_size

print(f"9 scenes | duree={dur:.2f}s (attendu ~45s) | taille={sz} bytes")
print("SUCCES" if dur >= 44 else f"ECHEC: dur={dur:.2f}s")
'''
sftp = c.open_sftp()
with sftp.open('/tmp/d24_test_9sc.py', 'w') as f:
    f.write(TEST_9SC)
sftp.close()

ssh(c, "cd /opt/whiteboard-worker && python3 /tmp/d24_test_9sc.py", "TEST 9 scenes (=meme cas que 15d0b7ed, attendu 45s)")

# Verif worker actif et propre
ssh(c, "systemctl status whiteboard-worker --no-pager | grep -E 'Active|Main PID|Tasks'", "Status worker final")
ssh(c, "journalctl -u whiteboard-worker --no-pager -n 5 2>/dev/null | tail -5", "Derniers logs worker")

c.close()
print("\nVerification v5 terminee.")

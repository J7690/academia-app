#!/usr/bin/env python3
"""
MISSION D.25 - COLLECTE FORENSIQUE COMPLÈTE
Phases 1, 2, 3 — données runtime uniquement
"""
import sys, json, requests, paramiko
sys.stdout.reconfigure(encoding='utf-8')

SUPABASE = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SKEY     = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H        = {"apikey": SKEY, "Authorization": f"Bearer {SKEY}", "Content-Type": "application/json"}
KM       = dict(hostname="185.167.97.144", username="root", password="Nexiomgroup@Academia0", timeout=30)
RENDER_ID = "ad74ed9e-2133-4c79-9a84-29b33d9d8fb3"

def sql(q):
    r = requests.post(f"{SUPABASE}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": q}, timeout=30)
    return r.json()

def ssh(c, cmd, timeout=120):
    _, o, e = c.exec_command(cmd, timeout=timeout)
    out = o.read().decode(errors='replace')
    err = e.read().decode(errors='replace')
    return out, err

c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect(**KM)

results = {}

# ============================================================
# PHASE 1A : Storyboard metadata
# ============================================================
print(">>> PHASE 1A: Storyboard scenes metadata")
res = sql(f"""
SELECT
    wr.id as render_id,
    wr.project_id,
    wr.status,
    wr.video_url,
    wr.duration_ms as render_duration_ms,
    wp.storyboard_json
FROM app.whiteboard_renders wr
JOIN app.whiteboard_projects wp ON wr.project_id = wp.id
WHERE wr.id = '{RENDER_ID}'
""")
rows = res.get('rows', [])
if rows:
    row = rows[0]
    sj = row.get('storyboard_json', {})
    if isinstance(sj, str): sj = json.loads(sj)
    scenes = sj.get('scenes', [])
    results['render_id'] = row.get('render_id')
    results['project_id'] = row.get('project_id')
    results['status'] = row.get('status')
    results['video_url'] = row.get('video_url', '')
    results['render_duration_ms'] = row.get('render_duration_ms')
    results['scenes'] = scenes
    results['storyboard_renderer'] = sj.get('renderer')
    results['storyboard_theme'] = sj.get('theme')
    results['storyboard_narration'] = sj.get('narration_mode')
    print(f"  render_id    : {results['render_id']}")
    print(f"  project_id   : {results['project_id']}")
    print(f"  nb_scenes    : {len(scenes)}")
    print(f"  renderer     : {results['storyboard_renderer']}")
    print(f"  narration    : {results['storyboard_narration']}")
    print(f"  duration_ms  : {results['render_duration_ms']}")
    total_ms = sum(s.get('duration_ms', 0) for s in scenes)
    print(f"  total_duration_ms storyboard: {total_ms}")
    results['total_ms_storyboard'] = total_ms
    print(f"\n  Scenes detail:")
    cumul = 0
    for s in scenes:
        dmx = s.get('duration_ms', 0)
        cumul += dmx
        blocks = s.get('blocks', [])
        btypes = [b.get('type','?') for b in blocks]
        print(f"    scene_id={s.get('id','?')[:8]} order={s.get('order')} dur={dmx}ms cumul={cumul}ms blocks={btypes}")
else:
    print(f"  Render non trouve: {res}")

# ============================================================
# PHASE 1B : ffprobe complet (format + streams + frames)
# ============================================================
print("\n>>> PHASE 1B: ffprobe -show_format + -show_streams + -show_frames")
video_url = results.get('video_url','')

out_ffprobe, _ = ssh(c, f"""
curl -s -o /tmp/d25_audit.mp4 '{video_url}'
echo "=== SHOW_FORMAT ==="
ffprobe -v quiet -print_format json -show_format /tmp/d25_audit.mp4 2>/dev/null
echo "=== SHOW_STREAMS ==="
ffprobe -v quiet -print_format json -show_streams /tmp/d25_audit.mp4 2>/dev/null
echo "=== SHOW_FRAMES_COUNT ==="
ffprobe -v quiet -print_format json -show_frames -select_streams v /tmp/d25_audit.mp4 2>/dev/null | python3 -c "
import json,sys
d=json.load(sys.stdin)
frames=d.get('frames',[])
print(json.dumps({'nb_frames_counted': len(frames), 'first_frame': frames[0] if frames else {}, 'last_frame': frames[-1] if frames else {}}))
"
echo "=== SHOW_AUDIO_FRAMES ==="
ffprobe -v quiet -print_format json -show_frames -select_streams a /tmp/d25_audit.mp4 2>/dev/null | python3 -c "
import json,sys
d=json.load(sys.stdin)
frames=d.get('frames',[])
print(json.dumps({'nb_audio_frames': len(frames), 'first': frames[0] if frames else {}, 'last': frames[-1] if frames else {}}))
"
echo "=== ATOMS ==="
python3 -c "
data = open('/tmp/d25_audit.mp4','rb').read()
off, atoms = 0, []
while off < len(data)-8:
    sz = int.from_bytes(data[off:off+4],'big')
    nm = data[off+4:off+8].decode('ascii',errors='?')
    atoms.append({'name':nm,'offset':off,'size':sz})
    if sz < 8: break
    off += sz
    if off >= len(data): break
import json; print(json.dumps(atoms))
"
echo "=== FILE_SIZE ==="
stat -c '%s' /tmp/d25_audit.mp4
echo "=== VERBOSE_PROBE ==="
ffprobe -v verbose /tmp/d25_audit.mp4 2>&1 | head -30
""")

# Parse sections
sections = {}
cur = None
buf = []
for line in out_ffprobe.split('\n'):
    if line.startswith('=== ') and line.endswith(' ==='):
        if cur: sections[cur] = '\n'.join(buf).strip()
        cur = line[4:-4]
        buf = []
    else:
        buf.append(line)
if cur: sections[cur] = '\n'.join(buf).strip()

# Format
fmt = {}
if 'SHOW_FORMAT' in sections:
    try:
        d = json.loads(sections['SHOW_FORMAT'])
        fmt = d.get('format', {})
        results['fmt'] = fmt
        print(f"  duration      : {fmt.get('duration')}s")
        print(f"  size          : {fmt.get('size')} bytes")
        print(f"  bit_rate      : {fmt.get('bit_rate')} bps")
        print(f"  nb_streams    : {fmt.get('nb_streams')}")
        print(f"  format_name   : {fmt.get('format_name')}")
    except Exception as ex:
        print(f"  fmt parse err: {ex}")

# Streams
streams = []
if 'SHOW_STREAMS' in sections:
    try:
        d = json.loads(sections['SHOW_STREAMS'])
        streams = d.get('streams', [])
        results['streams'] = streams
        vs = [s for s in streams if s.get('codec_type')=='video']
        as_ = [s for s in streams if s.get('codec_type')=='audio']
        v = vs[0] if vs else {}
        a = as_[0] if as_ else {}
        results['video_stream'] = v
        results['audio_stream'] = a
        print(f"\n  === VIDEO STREAM ===")
        print(f"  codec         : {v.get('codec_name')} {v.get('profile')} level={v.get('level')}")
        print(f"  resolution    : {v.get('width')}x{v.get('height')}")
        print(f"  pix_fmt       : {v.get('pix_fmt')}")
        print(f"  fps (r_frame) : {v.get('r_frame_rate')}")
        print(f"  fps (avg)     : {v.get('avg_frame_rate')}")
        print(f"  nb_frames     : {v.get('nb_frames')}")
        print(f"  duration      : {v.get('duration')}s")
        print(f"  duration_ts   : {v.get('duration_ts')}")
        print(f"  time_base     : {v.get('time_base')}")
        print(f"  has_b_frames  : {v.get('has_b_frames')}")
        print(f"  bit_rate      : {v.get('bit_rate')}")
        print(f"  color_space   : {v.get('color_space')}")
        print(f"  color_transfer: {v.get('color_transfer')}")
        print(f"  color_prim    : {v.get('color_primaries')}")
        print(f"  color_range   : {v.get('color_range')}")
        print(f"\n  === AUDIO STREAM ===")
        if a:
            print(f"  codec         : {a.get('codec_name')}")
            print(f"  sample_rate   : {a.get('sample_rate')}")
            print(f"  channels      : {a.get('channels')}")
            print(f"  channel_layout: {a.get('channel_layout')}")
            print(f"  nb_frames     : {a.get('nb_frames')}")
            print(f"  duration      : {a.get('duration')}s")
            print(f"  duration_ts   : {a.get('duration_ts')}")
            print(f"  time_base     : {a.get('time_base')}")
            print(f"  bit_rate      : {a.get('bit_rate')}")
        else:
            print(f"  ABSENT")
    except Exception as ex:
        print(f"  streams parse err: {ex}")

# Frames
if 'SHOW_FRAMES_COUNT' in sections:
    try:
        d = json.loads(sections['SHOW_FRAMES_COUNT'])
        results['frames'] = d
        print(f"\n  === FRAMES COMPTÉS ===")
        print(f"  nb_frames_counted: {d.get('nb_frames_counted')}")
        first = d.get('first_frame', {})
        last  = d.get('last_frame', {})
        print(f"  first_frame pts : {first.get('pkt_pts_time')} pkt_dts={first.get('pkt_dts_time')}")
        print(f"  last_frame  pts : {last.get('pkt_pts_time')} pkt_dts={last.get('pkt_dts_time')}")
    except Exception as ex:
        print(f"  frames parse err: {ex}")

if 'SHOW_AUDIO_FRAMES' in sections:
    try:
        d = json.loads(sections['SHOW_AUDIO_FRAMES'])
        results['audio_frames'] = d
        print(f"\n  === AUDIO FRAMES ===")
        print(f"  nb_audio_frames: {d.get('nb_audio_frames')}")
    except Exception as ex:
        print(f"  audio frames err: {ex}")

# Atoms
if 'ATOMS' in sections:
    try:
        atoms = json.loads(sections['ATOMS'])
        results['atoms'] = atoms
        print(f"\n  === ATOMS ===")
        for a_ in atoms:
            print(f"  [{a_.get('name')}] offset={a_.get('offset')} size={a_.get('size')}")
    except: pass

# File size
if 'FILE_SIZE' in sections:
    fsz = sections['FILE_SIZE'].strip()
    results['file_size'] = fsz
    print(f"\n  File size: {fsz} bytes")

# Verbose
if 'VERBOSE_PROBE' in sections:
    results['verbose_probe'] = sections['VERBOSE_PROBE']
    print(f"\n  === VERBOSE (extrait) ===")
    print(sections['VERBOSE_PROBE'][:800])

# ============================================================
# PHASE 1C : Durée théorique vs réelle
# ============================================================
print("\n>>> PHASE 1C: Durée théorique vs réelle")
scenes = results.get('scenes', [])
total_ms = results.get('total_ms_storyboard', 0)
dur_container = float(fmt.get('duration', 0) or 0)
v = results.get('video_stream', {})
dur_video_stream = float(v.get('duration', 0) or 0)
nb_frames = int(v.get('nb_frames', 0) or 0)
nb_frames_counted = results.get('frames', {}).get('nb_frames_counted', 0)
fps = 30  # attendu

dur_attendue = total_ms / 1000.0
dur_theorique_frames = nb_frames / fps if fps > 0 else 0
ecart_container = dur_container - dur_attendue
ecart_stream = dur_video_stream - dur_attendue
ecart_frames = dur_theorique_frames - dur_attendue

results['dur_attendue'] = dur_attendue
results['dur_container'] = dur_container
results['dur_video_stream'] = dur_video_stream
results['dur_theorique_frames'] = dur_theorique_frames
results['ecart_container'] = ecart_container

print(f"  Durée attendue (storyboard) : {dur_attendue:.3f}s  ({total_ms}ms / {len(scenes)} scènes)")
print(f"  Durée container ffprobe     : {dur_container:.6f}s  écart={ecart_container:+.6f}s")
print(f"  Durée stream vidéo ffprobe  : {dur_video_stream:.6f}s  écart={ecart_stream:+.6f}s")
print(f"  Durée théorique (frames/fps): {dur_theorique_frames:.3f}s  ({nb_frames}f÷{fps})")
print(f"  Frames comptés réels        : {nb_frames_counted}")

if abs(ecart_container) < 0.1:
    print(f"  VERDICT DURÉE : CONFORME (écart < 0.1s)")
else:
    print(f"  VERDICT DURÉE : NON CONFORME (écart={ecart_container:+.3f}s)")

# ============================================================
# PHASE 2 : Audit pistes audio - FFmpeg command forensique
# ============================================================
print("\n>>> PHASE 2: Audit forensique pistes audio + FFmpeg command")

out_audio, _ = ssh(c, """
echo "=== ASSEMBLER_CODE ==="
cat /opt/whiteboard-worker/whiteboard_ffmpeg_assembler.py
echo "=== WORKER_CODE ==="
cat /opt/whiteboard-worker/whiteboard_render_worker.py | head -150
echo "=== LAST_FFMPEG_CMD ==="
grep -r 'ffmpeg' /opt/whiteboard-worker/*.py 2>/dev/null | grep -v '.pyc'
echo "=== RECENT_FFMPEG_PROCESSES ==="
ps aux | grep ffmpeg | grep -v grep
echo "=== RECENT_WORKER_LOGS ==="
journalctl -u whiteboard-worker --no-pager -n 50 2>/dev/null
""")

sections2 = {}
cur = None
buf = []
for line in out_audio.split('\n'):
    if line.startswith('=== ') and line.endswith(' ==='):
        if cur: sections2[cur] = '\n'.join(buf).strip()
        cur = line[4:-4]
        buf = []
    else:
        buf.append(line)
if cur: sections2[cur] = '\n'.join(buf).strip()

results['assembler_code'] = sections2.get('ASSEMBLER_CODE','')
results['worker_code']    = sections2.get('WORKER_CODE','')
results['worker_logs']    = sections2.get('RECENT_WORKER_LOGS','')

print(f"\n  === ASSEMBLER CODE (extrait FFmpeg cmd) ===")
assembler = sections2.get('ASSEMBLER_CODE','')
# Extraire les lignes avec ffmpeg/aac/audio
for ln in assembler.split('\n'):
    lln = ln.strip()
    if any(k in lln.lower() for k in ['ffmpeg','aac','audio','-c:a','-an','anullsrc','-i ','-map','lavfi','shortest']):
        print(f"  {lln}")

print(f"\n  === WORKER CODE (extrait) ===")
worker = sections2.get('WORKER_CODE','')
for ln in worker.split('\n'):
    lln = ln.strip()
    if any(k in lln.lower() for k in ['assemble','ffmpeg','audio','png','render','upload']):
        print(f"  {lln}")

print(f"\n  === LOGS WORKER (derniers 20 lignes) ===")
logs = sections2.get('RECENT_WORKER_LOGS','')
print('\n'.join(logs.split('\n')[-20:]))

# ============================================================
# PHASE 3 : Chaîne complète Kamatera
# ============================================================
print("\n>>> PHASE 3: Chaîne complète Kamatera")

out_chain, _ = ssh(c, """
echo "=== WORKER_FILES ==="
ls -la /opt/whiteboard-worker/
echo "=== WORKER_FULL ==="
cat /opt/whiteboard-worker/whiteboard_render_worker.py
echo "=== RENDERER_CODE ==="
cat /opt/whiteboard-worker/whiteboard_png_renderer.py | head -100
echo "=== PYCACHE ==="
ls -la /opt/whiteboard-worker/__pycache__/ 2>/dev/null || echo "No pycache"
echo "=== SERVICE_FILE ==="
cat /etc/systemd/system/whiteboard-worker.service 2>/dev/null
echo "=== CHECKSUMS ==="
md5sum /opt/whiteboard-worker/*.py
echo "=== PYTHON_VERSION ==="
python3 --version
python3 -c "import PIL; print('Pillow:', PIL.__version__)"
echo "=== FFMPEG_VERSION ==="
ffmpeg -version 2>&1 | head -3
""")

sections3 = {}
cur = None
buf = []
for line in out_chain.split('\n'):
    if line.startswith('=== ') and line.endswith(' ==='):
        if cur: sections3[cur] = '\n'.join(buf).strip()
        cur = line[4:-4]
        buf = []
    else:
        buf.append(line)
if cur: sections3[cur] = '\n'.join(buf).strip()

results['worker_files']   = sections3.get('WORKER_FILES','')
results['worker_full']    = sections3.get('WORKER_FULL','')
results['renderer_code']  = sections3.get('RENDERER_CODE','')
results['checksums']      = sections3.get('CHECKSUMS','')
results['python_version'] = sections3.get('PYTHON_VERSION','')
results['ffmpeg_version'] = sections3.get('FFMPEG_VERSION','')
results['service_file']   = sections3.get('SERVICE_FILE','')

print(f"\n  Worker files:\n{results['worker_files']}")
print(f"\n  Checksums:\n{results['checksums']}")
print(f"\n  Python: {results['python_version']}")
print(f"  FFmpeg: {results['ffmpeg_version']}")

c.close()

# Sauvegarder toutes les données brutes
import pathlib
out_path = pathlib.Path(r'C:\Users\fasop\AndroidStudioProjects\academia\.windsurf\d25_raw_data.json')
with open(out_path, 'w', encoding='utf-8') as f:
    # Filtrer les très gros champs pour le JSON
    export = {k: v for k, v in results.items() if k not in ('assembler_code','worker_full','renderer_code','verbose_probe')}
    json.dump(export, f, ensure_ascii=False, indent=2)
print(f"\n  Données brutes sauvegardées: {out_path}")

# Sauvegarder les codes sources séparément
for key in ('assembler_code','worker_full','renderer_code','worker_logs'):
    p = pathlib.Path(rf'C:\Users\fasop\AndroidStudioProjects\academia\.windsurf\d25_src_{key}.txt')
    with open(p, 'w', encoding='utf-8') as f:
        f.write(results.get(key,''))
    print(f"  Code sauvegardé: {p.name}")

print("\n>>> COLLECTE TERMINÉE")

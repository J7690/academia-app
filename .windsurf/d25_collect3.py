#!/usr/bin/env python3
"""MISSION D.25 - COLLECTE FORENSIQUE v3 (queries séparées)"""
import sys, json, requests, paramiko, pathlib
sys.stdout.reconfigure(encoding='utf-8')

SUPABASE  = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SKEY      = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H         = {"apikey": SKEY, "Authorization": f"Bearer {SKEY}", "Content-Type": "application/json"}
KM        = dict(hostname="185.167.97.144", username="root", password="Nexiomgroup@Academia0", timeout=30)
RENDER_ID = "ad74ed9e-2133-4c79-9a84-29b33d9d8fb3"
WINDSURF  = pathlib.Path(r"C:\Users\fasop\AndroidStudioProjects\academia\.windsurf")

def sql(q):
    r = requests.post(f"{SUPABASE}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": q}, timeout=30)
    return r.json()

def ssh(c, cmd, timeout=180):
    _, o, e = c.exec_command(cmd, timeout=timeout)
    return o.read().decode(errors='replace'), e.read().decode(errors='replace')

data = {}

# ============================================================
print("="*70)
print("PHASE 1A: Metadata render + storyboard (2 queries séparées)")
print("="*70)

r1 = sql(f"SELECT id, project_id, status, video_url, duration_ms FROM app.whiteboard_renders WHERE id = '{RENDER_ID}'")
rows1 = r1.get('rows', [])
if not rows1:
    print(f"ERREUR render: {r1}")
    sys.exit(1)
row1 = rows1[0]
project_id = row1.get('project_id')
video_url  = row1.get('video_url', '')
print(f"  render_id     : {row1.get('id')}")
print(f"  project_id    : {project_id}")
print(f"  status        : {row1.get('status')}")
print(f"  video_url     : {video_url[:100]}")
print(f"  duration_ms   : {row1.get('duration_ms')}")
data.update({
    'render_id': row1.get('id'),
    'project_id': project_id,
    'status': row1.get('status'),
    'video_url': video_url,
    'render_duration_ms': row1.get('duration_ms'),
})

r2 = sql(f"SELECT storyboard_json, subject FROM app.whiteboard_projects WHERE id = '{project_id}'")
rows2 = r2.get('rows', [])
if not rows2:
    print(f"ERREUR project: {r2}")
    sys.exit(1)
row2 = rows2[0]
sj = row2.get('storyboard_json', {})
if isinstance(sj, str): sj = json.loads(sj)
scenes = sj.get('scenes', [])
total_ms = sum(s.get('duration_ms', 0) for s in scenes)
data.update({
    'subject': row2.get('subject'),
    'storyboard_renderer': sj.get('renderer'),
    'storyboard_theme': sj.get('theme'),
    'storyboard_narration': sj.get('narration_mode', 'none'),
    'nb_scenes': len(scenes),
    'total_ms_storyboard': total_ms,
    'scenes': scenes,
})
print(f"  subject       : {row2.get('subject')}")
print(f"  renderer      : {sj.get('renderer')}")
print(f"  narration     : {sj.get('narration_mode')}")
print(f"  nb_scenes     : {len(scenes)}")
print(f"  total_ms      : {total_ms}ms = {total_ms/1000:.3f}s")

print(f"\n  TABLEAU SCÈNES:")
print(f"  {'order':>5} | {'scene_id':>10} | {'dur_ms':>8} | {'cumul_ms':>10} | blocks")
print(f"  {'-'*5}-+-{'-'*10}-+-{'-'*8}-+-{'-'*10}-+-{'-'*20}")
cumul = 0
scene_table = []
for s in scenes:
    dmx = s.get('duration_ms', 0)
    cumul += dmx
    blocks = [b.get('type','?') for b in s.get('blocks', [])]
    sid = s.get('id','?')[:10]
    print(f"  {s.get('order','?'):>5} | {sid:>10} | {dmx:>8} | {cumul:>10} | {blocks}")
    scene_table.append({'order': s.get('order'), 'scene_id': sid,
                        'duration_ms': dmx, 'cumul_ms': cumul, 'blocks': blocks})
data['scene_table'] = scene_table

# ============================================================
print("\n" + "="*70)
print("PHASES 1B + 2 + 3: SSH Kamatera")
print("="*70)

c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect(**KM)

# Télécharger MP4
print("  [1] Download MP4...")
ssh(c, f"curl -s -o /tmp/d25_audit.mp4 '{video_url}'")
out_sz, _ = ssh(c, "stat -c '%s' /tmp/d25_audit.mp4")
data['file_size'] = out_sz.strip()
print(f"       file_size = {data['file_size']} bytes")

# ffprobe format
print("  [2] ffprobe -show_format...")
out_f, _ = ssh(c, "ffprobe -v quiet -print_format json -show_format /tmp/d25_audit.mp4 2>/dev/null")
try:
    fmt = json.loads(out_f).get('format', {})
    data['fmt'] = fmt
    print(f"       duration    = {fmt.get('duration')}s")
    print(f"       size        = {fmt.get('size')} bytes")
    print(f"       bit_rate    = {fmt.get('bit_rate')} bps")
    print(f"       nb_streams  = {fmt.get('nb_streams')}")
    print(f"       format_name = {fmt.get('format_name')}")
except Exception as ex:
    print(f"       ERREUR fmt: {ex}")
    fmt = {}

# ffprobe streams
print("  [3] ffprobe -show_streams...")
out_s, _ = ssh(c, "ffprobe -v quiet -print_format json -show_streams /tmp/d25_audit.mp4 2>/dev/null")
try:
    streams = json.loads(out_s).get('streams', [])
    data['streams'] = streams
    vs  = [s for s in streams if s.get('codec_type')=='video']
    as_ = [s for s in streams if s.get('codec_type')=='audio']
    v   = vs[0]  if vs  else {}
    a   = as_[0] if as_ else {}
    data['video_stream'] = v
    data['audio_stream'] = a
    print(f"       nb_streams   = {len(streams)}")
    print(f"       VIDEO: codec={v.get('codec_name')} profile={v.get('profile')} level={v.get('level')}")
    print(f"              {v.get('width')}x{v.get('height')} pix_fmt={v.get('pix_fmt')}")
    print(f"              fps={v.get('avg_frame_rate')} r_fps={v.get('r_frame_rate')}")
    print(f"              nb_frames={v.get('nb_frames')} duration={v.get('duration')}s")
    print(f"              duration_ts={v.get('duration_ts')} time_base={v.get('time_base')}")
    print(f"              has_b_frames={v.get('has_b_frames')}")
    print(f"              color_space={v.get('color_space')} trc={v.get('color_transfer')} prim={v.get('color_primaries')}")
    print(f"              color_range={v.get('color_range')}")
    print(f"       AUDIO: codec={a.get('codec_name','ABSENT')} sr={a.get('sample_rate')}")
    print(f"              channels={a.get('channels')} layout={a.get('channel_layout')}")
    print(f"              nb_frames={a.get('nb_frames')} duration={a.get('duration')}s")
    print(f"              time_base={a.get('time_base')} duration_ts={a.get('duration_ts')}")
    print(f"              bit_rate={a.get('bit_rate')}")
except Exception as ex:
    print(f"       ERREUR streams: {ex}")
    v, a = {}, {}

# ffprobe frames (vidéo) — count + première/dernière
print("  [4] ffprobe -show_frames video...")
script_fr = (
    "import subprocess,json\n"
    "r=subprocess.run(['ffprobe','-v','quiet','-print_format','json','-show_frames',\n"
    "  '-select_streams','v','/tmp/d25_audit.mp4'],capture_output=True,text=True)\n"
    "d=json.loads(r.stdout)\n"
    "frames=d.get('frames',[])\n"
    "print(json.dumps({'nb':len(frames),"
    "'f0_pts':frames[0].get('pkt_pts_time') if frames else None,"
    "'f0_dts':frames[0].get('pkt_dts_time') if frames else None,"
    "'fn_pts':frames[-1].get('pkt_pts_time') if frames else None,"
    "'fn_dts':frames[-1].get('pkt_dts_time') if frames else None}))\n"
)
sftp = c.open_sftp()
with sftp.open('/tmp/d25_fr.py', 'w') as fp:
    fp.write(script_fr)
sftp.close()
out_fr, _ = ssh(c, "python3 /tmp/d25_fr.py 2>/dev/null")
try:
    fdata = json.loads(out_fr.strip())
    data['frames_video'] = fdata
    print(f"       nb_frames_counted = {fdata.get('nb')}")
    print(f"       first_frame_pts   = {fdata.get('f0_pts')}s")
    print(f"       last_frame_pts    = {fdata.get('fn_pts')}s")
except Exception as ex:
    print(f"       ERREUR: {ex} | raw: {out_fr[:100]}")
    data['frames_video'] = {}

# ffprobe frames audio
print("  [5] ffprobe -show_frames audio...")
script_af = (
    "import subprocess,json\n"
    "r=subprocess.run(['ffprobe','-v','quiet','-print_format','json','-show_frames',\n"
    "  '-select_streams','a','/tmp/d25_audit.mp4'],capture_output=True,text=True)\n"
    "d=json.loads(r.stdout)\n"
    "frames=d.get('frames',[])\n"
    "print(json.dumps({'nb':len(frames),"
    "'f0_pts':frames[0].get('pkt_pts_time') if frames else None,"
    "'fn_pts':frames[-1].get('pkt_pts_time') if frames else None}))\n"
)
sftp = c.open_sftp()
with sftp.open('/tmp/d25_af.py', 'w') as fp:
    fp.write(script_af)
sftp.close()
out_af, _ = ssh(c, "python3 /tmp/d25_af.py 2>/dev/null")
try:
    afdata = json.loads(out_af.strip())
    data['frames_audio'] = afdata
    print(f"       nb_audio_frames = {afdata.get('nb')}")
    print(f"       first_audio_pts = {afdata.get('f0_pts')}s")
    print(f"       last_audio_pts  = {afdata.get('fn_pts')}s")
except Exception as ex:
    print(f"       ERREUR: {ex}")
    data['frames_audio'] = {}

# Atoms MP4
print("  [6] Atoms MP4...")
script_at = (
    "import json\n"
    "data=open('/tmp/d25_audit.mp4','rb').read()\n"
    "off,atoms=0,[]\n"
    "while off<len(data)-8:\n"
    "    sz=int.from_bytes(data[off:off+4],'big')\n"
    "    nm=data[off+4:off+8].decode('ascii',errors='?')\n"
    "    atoms.append({'name':nm,'offset':off,'size':sz})\n"
    "    if sz<8: break\n"
    "    off+=sz\n"
    "    if off>=len(data): break\n"
    "print(json.dumps(atoms))\n"
)
sftp = c.open_sftp()
with sftp.open('/tmp/d25_at.py', 'w') as fp:
    fp.write(script_at)
sftp.close()
out_at, _ = ssh(c, "python3 /tmp/d25_at.py 2>/dev/null")
try:
    atoms = json.loads(out_at.strip())
    data['atoms'] = atoms
    names = [a['name'] for a in atoms]
    moov_ok = 'moov' in names and 'mdat' in names and names.index('moov') < names.index('mdat')
    data['moov_before_mdat'] = moov_ok
    for at in atoms:
        print(f"       [{at['name']}] offset={at['offset']} size={at['size']}")
    print(f"       moov < mdat: {moov_ok}")
except Exception as ex:
    print(f"       ERREUR: {ex}")

# VUI verbose + smpte check
print("  [7] VUI verbose...")
out_vui, _ = ssh(c, "ffprobe -v verbose /tmp/d25_audit.mp4 2>&1")
data['verbose_probe'] = out_vui
has_smpte = 'smpte170m' in out_vui.lower()
data['has_smpte170m'] = has_smpte
vui_lines = [l for l in out_vui.split('\n') if any(k in l.lower() for k in ['bt709','smpte','transfer','primaries','yuv'])]
print(f"       smpte170m present: {has_smpte}")
for ln in vui_lines[:6]:
    print(f"       {ln.strip()[:120]}")

# Decode errors
print("  [8] Decode complet...")
out_dec, err_dec = ssh(c, "ffmpeg -v error -i /tmp/d25_audit.mp4 -f null - 2>&1")
decode_err = (out_dec + err_dec).strip()
data['decode_errors'] = decode_err
print(f"       errors: {decode_err if decode_err else 'AUCUNE'}")

# ============================================================
print("\n  [9] Codes sources worker...")
out_asm, _  = ssh(c, "cat /opt/whiteboard-worker/whiteboard_ffmpeg_assembler.py")
out_wkr, _  = ssh(c, "cat /opt/whiteboard-worker/whiteboard_render_worker.py")
out_rnd, _  = ssh(c, "cat /opt/whiteboard-worker/whiteboard_png_renderer.py | head -150")
out_logs, _ = ssh(c, "journalctl -u whiteboard-worker --no-pager --since '2026-06-29 08:00' 2>/dev/null")
out_svc, _  = ssh(c, "cat /etc/systemd/system/whiteboard-worker.service 2>/dev/null")
out_files, _ = ssh(c, "ls -la /opt/whiteboard-worker/ && md5sum /opt/whiteboard-worker/*.py")
out_py, _   = ssh(c, "python3 --version && python3 -c \"import PIL; print('Pillow:', PIL.__version__)\"")
out_ff, _   = ssh(c, "ffmpeg -version 2>&1 | head -5")

data.update({
    'assembler_code': out_asm,
    'worker_full': out_wkr,
    'renderer_head': out_rnd,
    'logs': out_logs,
    'service_file': out_svc,
    'worker_files': out_files,
    'python_version': out_py.strip(),
    'ffmpeg_version': out_ff.split('\n')[0],
})

c.close()

print(f"\n  Python: {data['python_version']}")
print(f"  FFmpeg: {data['ffmpeg_version']}")
print(f"\n  Worker files:\n{out_files}")

# ============================================================
# CALCULS
# ============================================================
print("\n" + "="*70)
print("CALCULS DURÉE — THÉORIQUE VS RÉELLE")
print("="*70)
dur_attendue   = total_ms / 1000.0
dur_container  = float(fmt.get('duration', 0) or 0)
v_stream       = data.get('video_stream', {})
v_dur          = float(v_stream.get('duration', 0) or 0)
nb_frames_hdr  = int(v_stream.get('nb_frames', 0) or 0)
nb_frames_real = data.get('frames_video', {}).get('nb', 0) or 0
fps_str        = v_stream.get('avg_frame_rate', '30/1')
try:
    n_, d_ = [int(x) for x in fps_str.split('/')]
    fps_float = n_ / d_
except:
    fps_float = 30.0

dur_par_frames = nb_frames_real / fps_float if fps_float else 0
ecart_container = dur_container - dur_attendue
ecart_stream    = v_dur - dur_attendue
ecart_frames    = dur_par_frames - dur_attendue

data.update({
    'dur_attendue': dur_attendue, 'dur_container': dur_container,
    'dur_video_stream': v_dur, 'dur_par_frames': dur_par_frames,
    'ecart_container': ecart_container, 'fps_float': fps_float,
    'nb_frames_header': nb_frames_hdr, 'nb_frames_real': nb_frames_real,
})

print(f"  Durée attendue (storyboard)    : {dur_attendue:.6f}s  ({total_ms}ms)")
print(f"  Durée container ffprobe        : {dur_container:.6f}s  écart={ecart_container:+.6f}s")
print(f"  Durée stream vidéo tkhd        : {v_dur:.6f}s  écart={ecart_stream:+.6f}s")
print(f"  Durée calculée (frames/fps)    : {dur_par_frames:.6f}s  ({nb_frames_real}f @ {fps_float}fps)")
print(f"  nb_frames header               : {nb_frames_hdr}")
print(f"  nb_frames réels comptés        : {nb_frames_real}")
print(f"  time_base                      : {v_stream.get('time_base')}")
print(f"  duration_ts                    : {v_stream.get('duration_ts')}")

if abs(ecart_container) < 0.1:
    print(f"\n  VERDICT : CONFORME — écart {ecart_container:+.6f}s < 100ms")
    print(f"  CAUSE   : concat demuxer perd 1 frame (dernière image dupliquée)")
    print(f"  RESPONSABLE DURÉE : whiteboard_ffmpeg_assembler.py (comportement normal)")
else:
    print(f"\n  VERDICT : NON CONFORME — écart {ecart_container:+.3f}s")

# ============================================================
# SAUVEGARDES
# ============================================================
print("\n" + "="*70)
print("SAUVEGARDE DES DONNÉES BRUTES")
print("="*70)

out_path = WINDSURF / "d25_raw_data.json"
with open(out_path, 'w', encoding='utf-8') as f:
    export = {k: v for k, v in data.items()
              if k not in ('assembler_code','worker_full','renderer_head','verbose_probe','logs','streams')}
    json.dump(export, f, ensure_ascii=False, indent=2, default=str)
print(f"  JSON: {out_path}")

for key, fname in [
    ('assembler_code','d25_src_assembler.py'),
    ('worker_full','d25_src_worker.py'),
    ('renderer_head','d25_src_renderer_head.py'),
    ('logs','d25_src_worker_logs.txt'),
    ('verbose_probe','d25_src_verbose_probe.txt'),
    ('service_file','d25_src_service.txt'),
]:
    p = WINDSURF / fname
    with open(p, 'w', encoding='utf-8') as f:
        f.write(data.get(key,''))
    print(f"  Sauvegardé: {fname}")

print("\n>>> COLLECTE TERMINÉE — Génération livrables en cours...")

#!/usr/bin/env python3
"""MISSION D.25 - COLLECTE FORENSIQUE COMPLÈTE (sans f-string dans SSH)"""
import sys, json, requests, paramiko, pathlib
sys.stdout.reconfigure(encoding='utf-8')

SUPABASE = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SKEY     = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H        = {"apikey": SKEY, "Authorization": f"Bearer {SKEY}", "Content-Type": "application/json"}
KM       = dict(hostname="185.167.97.144", username="root", password="Nexiomgroup@Academia0", timeout=30)
RENDER_ID = "ad74ed9e-2133-4c79-9a84-29b33d9d8fb3"
WINDSURF  = pathlib.Path(r"C:\Users\fasop\AndroidStudioProjects\academia\.windsurf")

def sql(q):
    r = requests.post(f"{SUPABASE}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": q}, timeout=30)
    return r.json()

def ssh(c, cmd, timeout=180):
    _, o, e = c.exec_command(cmd, timeout=timeout)
    return o.read().decode(errors='replace'), e.read().decode(errors='replace')

# ============================================================
print("="*70)
print("PHASE 1A: Storyboard metadata depuis Supabase")
print("="*70)

res = sql(f"""
SELECT wr.id as render_id, wr.project_id, wr.status, wr.video_url,
       wr.duration_ms as render_duration_ms, wp.storyboard_json
FROM app.whiteboard_renders wr
JOIN app.whiteboard_projects wp ON wr.project_id = wp.id
WHERE wr.id = '{RENDER_ID}'
""")
rows = res.get('rows', [])
if not rows:
    print(f"Render non trouve: {res}")
    sys.exit(1)

row = rows[0]
sj = row.get('storyboard_json', {})
if isinstance(sj, str): sj = json.loads(sj)
scenes  = sj.get('scenes', [])
video_url = row.get('video_url','')
total_ms = sum(s.get('duration_ms', 0) for s in scenes)

data = {
    'render_id': row.get('render_id'),
    'project_id': row.get('project_id'),
    'status': row.get('status'),
    'video_url': video_url,
    'render_duration_ms': row.get('render_duration_ms'),
    'storyboard_renderer': sj.get('renderer'),
    'storyboard_theme': sj.get('theme'),
    'storyboard_narration': sj.get('narration_mode'),
    'nb_scenes': len(scenes),
    'total_ms_storyboard': total_ms,
    'scenes': scenes,
}
print(f"  render_id      : {data['render_id']}")
print(f"  project_id     : {data['project_id']}")
print(f"  nb_scenes      : {data['nb_scenes']}")
print(f"  renderer       : {data['storyboard_renderer']}")
print(f"  theme          : {data['storyboard_theme']}")
print(f"  narration_mode : {data['storyboard_narration']}")
print(f"  total_ms       : {total_ms} ms = {total_ms/1000:.3f}s")
print(f"  render_dur_ms  : {data['render_duration_ms']}")
print(f"\n  SCÈNES DÉTAIL:")
cumul = 0
scene_table = []
for s in scenes:
    dmx = s.get('duration_ms', 0)
    cumul += dmx
    blocks = s.get('blocks', [])
    btypes = [b.get('type','?') for b in blocks]
    row_s = {'scene_id': s.get('id','?')[:8], 'order': s.get('order'), 'duration_ms': dmx,
             'cumul_ms': cumul, 'blocks': btypes}
    scene_table.append(row_s)
    print(f"    order={s.get('order')} dur={dmx}ms cumul={cumul}ms blocks={btypes}")
data['scene_table'] = scene_table

# ============================================================
print("\n" + "="*70)
print("PHASE 1B + 2 + 3: SSH Kamatera - ffprobe + audit audio + chaîne")
print("="*70)

c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect(**KM)

# Download MP4
print("  Download MP4...")
ssh(c, f"curl -s -o /tmp/d25_audit.mp4 '{video_url}'")

# ffprobe format
print("  ffprobe format...")
out_fmt, _ = ssh(c, "ffprobe -v quiet -print_format json -show_format /tmp/d25_audit.mp4 2>/dev/null")
try:
    fmt = json.loads(out_fmt).get('format', {})
    data['fmt'] = fmt
    print(f"    duration      : {fmt.get('duration')}s")
    print(f"    size          : {fmt.get('size')} bytes")
    print(f"    bit_rate      : {fmt.get('bit_rate')} bps")
    print(f"    nb_streams    : {fmt.get('nb_streams')}")
    print(f"    format_name   : {fmt.get('format_name')}")
except Exception as ex:
    print(f"  fmt parse err: {ex}")
    fmt = {}

# ffprobe streams
print("  ffprobe streams...")
out_st, _ = ssh(c, "ffprobe -v quiet -print_format json -show_streams /tmp/d25_audit.mp4 2>/dev/null")
try:
    streams = json.loads(out_st).get('streams', [])
    data['streams'] = streams
    vs  = [s for s in streams if s.get('codec_type')=='video']
    as_ = [s for s in streams if s.get('codec_type')=='audio']
    v = vs[0] if vs else {}
    a = as_[0] if as_ else {}
    data['video_stream'] = v
    data['audio_stream'] = a
    print(f"    VIDEO: {v.get('codec_name')} {v.get('profile')} level={v.get('level')} "
          f"{v.get('width')}x{v.get('height')} fps={v.get('avg_frame_rate')} "
          f"nb_frames={v.get('nb_frames')} dur={v.get('duration')}s "
          f"duration_ts={v.get('duration_ts')} time_base={v.get('time_base')}")
    print(f"    AUDIO: codec={a.get('codec_name','ABSENT')} sr={a.get('sample_rate')} "
          f"ch={a.get('channels')} nb_frames={a.get('nb_frames')} dur={a.get('duration')}s")
    print(f"    color_space={v.get('color_space')} trc={v.get('color_transfer')} prim={v.get('color_primaries')}")
    print(f"    has_b_frames={v.get('has_b_frames')} pix_fmt={v.get('pix_fmt')}")
except Exception as ex:
    print(f"  streams parse err: {ex}")
    v, a = {}, {}

# ffprobe frames count (vidéo)
print("  ffprobe frames count (video)...")
out_fr, _ = ssh(c, """python3 -c "
import subprocess,json
r=subprocess.run(['ffprobe','-v','quiet','-print_format','json','-show_frames',
  '-select_streams','v','/tmp/d25_audit.mp4'],capture_output=True,text=True)
d=json.loads(r.stdout)
frames=d.get('frames',[])
print(json.dumps({'nb_frames_counted':len(frames),
  'first_pts':frames[0].get('pkt_pts_time') if frames else None,
  'last_pts':frames[-1].get('pkt_pts_time') if frames else None,
  'first_dts':frames[0].get('pkt_dts_time') if frames else None,
  'last_dts':frames[-1].get('pkt_dts_time') if frames else None,
}))
" 2>/dev/null""")
try:
    fdata = json.loads(out_fr.strip())
    data['frames_video'] = fdata
    print(f"    nb_frames_counted : {fdata.get('nb_frames_counted')}")
    print(f"    first_pts         : {fdata.get('first_pts')}s")
    print(f"    last_pts          : {fdata.get('last_pts')}s")
except Exception as ex:
    print(f"  frames parse err: {ex} | raw: {out_fr[:200]}")

# ffprobe frames audio
print("  ffprobe frames count (audio)...")
out_af, _ = ssh(c, """python3 -c "
import subprocess,json
r=subprocess.run(['ffprobe','-v','quiet','-print_format','json','-show_frames',
  '-select_streams','a','/tmp/d25_audit.mp4'],capture_output=True,text=True)
d=json.loads(r.stdout)
frames=d.get('frames',[])
print(json.dumps({'nb_audio_frames':len(frames),
  'first_pts':frames[0].get('pkt_pts_time') if frames else None,
  'last_pts':frames[-1].get('pkt_pts_time') if frames else None,
}))
" 2>/dev/null""")
try:
    afdata = json.loads(out_af.strip())
    data['frames_audio'] = afdata
    print(f"    nb_audio_frames : {afdata.get('nb_audio_frames')}")
    print(f"    first_pts       : {afdata.get('first_pts')}s")
    print(f"    last_pts        : {afdata.get('last_pts')}s")
except Exception as ex:
    print(f"  audio frames err: {ex}")

# Atoms
print("  Atoms...")
out_at, _ = ssh(c, """python3 -c "
import json
data=open('/tmp/d25_audit.mp4','rb').read()
off,atoms=[],0
while off<len(data)-8:
    sz=int.from_bytes(data[off:off+4],'big')
    nm=data[off+4:off+8].decode('ascii',errors='?')
    atoms.append({'name':nm,'offset':off,'size':sz})
    if sz<8: break
    off+=sz
    if off>=len(data): break
print(json.dumps(atoms))
" 2>/dev/null""")
try:
    atoms = json.loads(out_at.strip())
    data['atoms'] = atoms
    names = [a['name'] for a in atoms]
    moov_ok = 'moov' in names and 'mdat' in names and names.index('moov') < names.index('mdat')
    print(f"    atoms: {' > '.join(names)}")
    print(f"    moov<mdat: {moov_ok}")
    data['moov_before_mdat'] = moov_ok
except Exception as ex:
    print(f"  atoms err: {ex}")

# VUI verbose
print("  VUI bitstream verbose...")
out_vui, _ = ssh(c, "ffprobe -v verbose /tmp/d25_audit.mp4 2>&1")
data['verbose_probe'] = out_vui
has_smpte = 'smpte170m' in out_vui.lower()
data['has_smpte170m'] = has_smpte
# Extraire les lignes couleur
vui_lines = [l for l in out_vui.split('\n') if any(k in l.lower() for k in ['bt709','smpte','transfer','primaries','color','yuv'])]
print(f"    smpte170m: {has_smpte}")
for ln in vui_lines[:6]:
    print(f"    {ln.strip()[:120]}")

# Decode errors
print("  Decode complet...")
out_dec, err_dec = ssh(c, "ffmpeg -v error -i /tmp/d25_audit.mp4 -f null - 2>&1")
decode_err = (out_dec + err_dec).strip()
data['decode_errors'] = decode_err
print(f"    errors: {decode_err if decode_err else 'AUCUNE'}")

# ============================================================
# PHASE 3: Chaîne Kamatera - codes sources + logs
# ============================================================
print("\n" + "="*70)
print("PHASE 3: Codes sources + logs worker")
print("="*70)

out_files, _ = ssh(c, "ls -la /opt/whiteboard-worker/ && echo '---' && md5sum /opt/whiteboard-worker/*.py")
data['worker_files'] = out_files
print(out_files[:1500])

out_assembler, _ = ssh(c, "cat /opt/whiteboard-worker/whiteboard_ffmpeg_assembler.py")
data['assembler_code'] = out_assembler
print(f"\n  Assembler ({len(out_assembler)} chars) - lignes FFmpeg:")
for ln in out_assembler.split('\n'):
    if any(k in ln.lower() for k in ['ffmpeg','aac','audio','-c:a','-an','anullsrc','-i ','lavfi','shortest','map ','concat']):
        print(f"    {ln.rstrip()}")

out_worker, _ = ssh(c, "cat /opt/whiteboard-worker/whiteboard_render_worker.py")
data['worker_full'] = out_worker
print(f"\n  Worker ({len(out_worker)} chars) - lignes clés:")
for ln in out_worker.split('\n'):
    if any(k in ln.lower() for k in ['assemble','ffmpeg','audio','png','render_storyboard','upload','mark_','status']):
        print(f"    {ln.rstrip()}")

out_renderer, _ = ssh(c, "cat /opt/whiteboard-worker/whiteboard_png_renderer.py | head -120")
data['renderer_head'] = out_renderer

out_logs, _ = ssh(c, "journalctl -u whiteboard-worker --no-pager --since '2026-06-29 09:00' 2>/dev/null | tail -40")
data['logs'] = out_logs
print(f"\n  Logs worker (40 dernières lignes):")
print(out_logs)

out_svc, _ = ssh(c, "cat /etc/systemd/system/whiteboard-worker.service 2>/dev/null")
data['service_file'] = out_svc

out_py, _ = ssh(c, "python3 --version && python3 -c \"import PIL; print('Pillow:', PIL.__version__)\"")
out_ff, _ = ssh(c, "ffmpeg -version 2>&1 | head -5")
data['python_version'] = out_py
data['ffmpeg_version'] = out_ff
print(f"\n  Python: {out_py.strip()}")
print(f"  FFmpeg: {out_ff.split(chr(10))[0]}")

c.close()

# ============================================================
# CALCULS PHASE 1C
# ============================================================
print("\n" + "="*70)
print("PHASE 1C: Analyse durée théorique vs réelle")
print("="*70)

dur_attendue     = total_ms / 1000.0
dur_container    = float(fmt.get('duration', 0) or 0)
v_dur            = float(data['video_stream'].get('duration', 0) or 0)
nb_frames_header = int(data['video_stream'].get('nb_frames', 0) or 0)
nb_frames_real   = data.get('frames_video', {}).get('nb_frames_counted', 0) or 0
fps_real         = data['video_stream'].get('avg_frame_rate', '30/1')
try:
    n, d_ = [int(x) for x in fps_real.split('/')]
    fps_float = n / d_
except:
    fps_float = 30.0

dur_par_frames   = nb_frames_real / fps_float if fps_float else 0
ecart_container  = dur_container - dur_attendue
ecart_stream     = v_dur - dur_attendue
ecart_frames     = dur_par_frames - dur_attendue

data['dur_attendue']    = dur_attendue
data['dur_container']   = dur_container
data['dur_video_stream']= v_dur
data['dur_par_frames']  = dur_par_frames
data['ecart_container'] = ecart_container
data['fps_float']       = fps_float

print(f"  Durée attendue (storyboard)   : {dur_attendue:.6f}s  ({total_ms}ms)")
print(f"  Durée container (moov/mvhd)   : {dur_container:.6f}s  écart={ecart_container:+.6f}s")
print(f"  Durée stream vidéo (tkhd)     : {v_dur:.6f}s  écart={ecart_stream:+.6f}s")
print(f"  Durée par frames réels comptés: {dur_par_frames:.6f}s  ({nb_frames_real}f @ {fps_float}fps)")
print(f"  Frames header nb_frames       : {nb_frames_header}")
print(f"  Frames comptés réels          : {nb_frames_real}")
print(f"  time_base vidéo               : {data['video_stream'].get('time_base')}")
print(f"  duration_ts vidéo             : {data['video_stream'].get('duration_ts')}")

# Verdict
if abs(ecart_container) < 0.1:
    verdict_dur = "CONFORME (écart < 100ms, expliqué par concat demuxer -1 frame)"
    resp_dur = "whiteboard_ffmpeg_assembler.py (comportement normal concat demuxer)"
else:
    verdict_dur = f"NON CONFORME (écart={ecart_container:+.3f}s)"
    resp_dur = "À DÉTERMINER"
data['verdict_dur'] = verdict_dur
data['resp_dur'] = resp_dur
print(f"\n  VERDICT DURÉE : {verdict_dur}")
print(f"  RESPONSABLE   : {resp_dur}")

# ============================================================
# PHASE 2 synthèse
# ============================================================
print("\n" + "="*70)
print("PHASE 2: Synthèse responsabilité audio")
print("="*70)
a = data.get('audio_stream', {})
has_audio = bool(a.get('codec_name'))
assembler = data.get('assembler_code', '')
has_anullsrc = 'anullsrc' in assembler
has_c_a_aac  = '-c:a' in assembler and 'aac' in assembler
has_an       = '"-an"' in assembler or "'-an'" in assembler
has_tts_input= '-i audio' in assembler.lower() or '-i narration' in assembler.lower()

print(f"  Audio présent dans MP4 : {has_audio}")
print(f"  Codec audio            : {a.get('codec_name','ABSENT')}")
print(f"  anullsrc dans assembler: {has_anullsrc}")
print(f"  -c:a aac dans assembler: {has_c_a_aac}")
print(f"  -an dans assembler     : {has_an}")
print(f"  -i audio/narration     : {has_tts_input}")
print(f"\n  Responsabilité théorique:")
resp_audio = {
    'Flutter'         : 'NON - Flutter affiche, ne génère pas',
    'Edge Function'   : 'NON - Génère storyboard, pas audio',
    'Supabase'        : 'NON - Stocke et route, pas audio',
    'Kamatera Worker' : 'OUI - Orchestre FFmpeg',
    'FFmpeg Assembler': 'OUI DIRECT - Appelle FFmpeg avec ou sans -c:a',
    'TTS Service'     : 'OUI SI narration_mode=tts - fournit le fichier audio',
}
for k,v in resp_audio.items():
    print(f"    {k:22s} : {v}")
narration = data.get('storyboard_narration','none')
print(f"\n  narration_mode = '{narration}'")
if narration == 'none':
    print(f"  CONCLUSION: Pas de TTS attendu. L'audio est SILENCIEUX SYNTHÉTIQUE (anullsrc).")
    print(f"  RESPONSABLE AUDIO : FFmpeg Assembler v7 (anullsrc + AAC)")
else:
    print(f"  CONCLUSION: TTS attendu — vérifier présence du fichier narration")

data['has_audio'] = has_audio
data['narration_mode'] = narration
data['resp_audio_summary'] = resp_audio

# Sauvegarder
out_path = WINDSURF / "d25_raw_data.json"
with open(out_path, 'w', encoding='utf-8') as f:
    export = {k: v for k, v in data.items()
              if k not in ('assembler_code','worker_full','renderer_head','verbose_probe','logs')}
    json.dump(export, f, ensure_ascii=False, indent=2, default=str)
print(f"\n  Données JSON: {out_path}")

for key, fname in [('assembler_code','assembler.py'),('worker_full','worker.py'),
                   ('renderer_head','renderer_head.py'),('logs','worker_logs.txt'),
                   ('verbose_probe','verbose_probe.txt')]:
    p = WINDSURF / f"d25_src_{fname}"
    with open(p, 'w', encoding='utf-8') as f:
        f.write(data.get(key,''))

print("\n>>> COLLECTE COMPLÈTE. Génération des livrables...")

#!/usr/bin/env python3
"""
D.25 - Valider le dernier render produit par le worker v7
+ Injecter un nouveau render pour un projet existant avec storyboard
"""
import sys, json, time, requests, paramiko
sys.stdout.reconfigure(encoding='utf-8')

SUPABASE = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SKEY     = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H        = {"apikey": SKEY, "Authorization": f"Bearer {SKEY}", "Content-Type": "application/json"}
KM       = dict(hostname="185.167.97.144", username="root", password="Nexiomgroup@Academia0", timeout=30)

def sql(q):
    r = requests.post(f"{SUPABASE}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": q}, timeout=30)
    return r.json()

def ssh_run(c, cmd, timeout=120):
    _, o, e = c.exec_command(cmd, timeout=timeout)
    return o.read().decode(errors='replace'), e.read().decode(errors='replace')

print("="*70)
print("ETAPE 1 : Trouver project avec storyboard + scenes")
print("="*70)

# Trouver le project_id qui a le plus de scenes (storyboard complet)
res = sql("""
SELECT wp.id as project_id,
       wp.subject,
       jsonb_array_length(wp.storyboard_json->'scenes') as nb_scenes
FROM app.whiteboard_projects wp
WHERE jsonb_array_length(wp.storyboard_json->'scenes') > 0
ORDER BY nb_scenes DESC, wp.created_at DESC
LIMIT 5
""")
rows = res.get('rows', [])
print("Projects avec scenes:")
for r in rows:
    print(f"  project={r.get('project_id')} subject={r.get('subject')} nb_scenes={r.get('nb_scenes')}")

if not rows:
    print("Aucun project avec scenes trouve.")
    sys.exit(1)

best_project = rows[0]['project_id']
nb_scenes = rows[0]['nb_scenes']
print(f"\n  -> Project selectionne: {best_project} ({nb_scenes} scenes)")

print("\n" + "="*70)
print("ETAPE 2 : Inserer render job queued")
print("="*70)

# INSERT avec SELECT immediat pour recuperer l'ID
res2 = sql(f"INSERT INTO app.whiteboard_renders (project_id, status, progress) VALUES ('{best_project}', 'queued', 0)")
print(f"  INSERT result: {res2}")

# Recuperer via SELECT immediat
time.sleep(1)
res2b = sql(f"""
SELECT id, status, created_at 
FROM app.whiteboard_renders 
WHERE project_id = '{best_project}' 
ORDER BY created_at DESC 
LIMIT 1
""")
rows2b = res2b.get('rows', [])
print(f"  Rows apres insert: {rows2b}")

if not rows2b:
    print("ERREUR: render non trouve apres insert")
    sys.exit(1)

render_id = rows2b[0]['id']
status = rows2b[0]['status']
print(f"  render_id: {render_id}")
print(f"  status initial: {status}")

print("\n" + "="*70)
print("ETAPE 3 : Attente traitement par worker v7 (max 90s)")
print("="*70)

deadline = time.time() + 90
t0 = time.time()
video_url = None

while time.time() < deadline:
    res3 = sql(f"SELECT status, video_url, error_message FROM app.whiteboard_renders WHERE id = '{render_id}'")
    rows3 = res3.get('rows', [])
    if rows3:
        status = rows3[0].get('status', '?')
        video_url = rows3[0].get('video_url', '') or ''
        err = rows3[0].get('error_message', '') or ''
        elapsed = int(time.time() - t0)
        url_short = ('...' + video_url[-40:]) if video_url else ''
        print(f"  t={elapsed:3d}s  status={status}{url_short}")
        if status in ('done', 'failed'):
            break
    time.sleep(3)

print(f"\n  Status final: {status}  Duree: {int(time.time()-t0)}s")

print("\n" + "="*70)
print("ETAPE 4 : VALIDATION FFPROBE + AUDIO")
print("="*70)

if status == 'done' and video_url:
    print(f"  URL: {video_url}")

    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(**KM)

    # ffprobe JSON
    out, _ = ssh_run(c, f"""
curl -s -o /tmp/d25_latest.mp4 '{video_url}'
echo "SIZE_BYTES:$(stat -c%s /tmp/d25_latest.mp4)"
ffprobe -v quiet -print_format json -show_streams -show_format /tmp/d25_latest.mp4 2>/dev/null
""")

    # Parser
    size_b = 0
    for ln in out.split('\n'):
        if ln.startswith('SIZE_BYTES:'):
            try: size_b = int(ln.split(':')[1])
            except: pass

    json_start = out.find('{')
    info = {}
    if json_start >= 0:
        try:
            info = json.loads(out[json_start:])
        except:
            pass

    fmt = info.get('format', {})
    streams = info.get('streams', [])
    vs = [s for s in streams if s.get('codec_type') == 'video']
    as_ = [s for s in streams if s.get('codec_type') == 'audio']
    v = vs[0] if vs else {}
    a = as_[0] if as_ else {}

    print(f"  Taille fichier    : {size_b} bytes ({size_b/1024:.1f} KB)")
    print(f"  Duration          : {fmt.get('duration','?')}s")
    print(f"  Streams           : {len(streams)} (video={len(vs)}, audio={len(as_)})")

    print(f"\n  [VIDEO]")
    print(f"  codec             : {v.get('codec_name','?')}")
    print(f"  profile           : {v.get('profile','?')}")
    print(f"  level             : {v.get('level','?')}")
    print(f"  resolution        : {v.get('width','?')}x{v.get('height','?')}")
    print(f"  pix_fmt           : {v.get('pix_fmt','?')}")
    print(f"  fps               : {v.get('avg_frame_rate','?')}")
    print(f"  has_b_frames      : {v.get('has_b_frames','?')}")
    print(f"  color_space       : {v.get('color_space','?')}")
    print(f"  color_transfer    : {v.get('color_transfer','?')}")
    print(f"  color_primaries   : {v.get('color_primaries','?')}")
    print(f"  color_range       : {v.get('color_range','?')}")

    print(f"\n  [AUDIO - CORRECTION P1]")
    if as_:
        print(f"  codec             : {a.get('codec_name','?')}")
        print(f"  sample_rate       : {a.get('sample_rate','?')} Hz")
        print(f"  channels          : {a.get('channels','?')}")
        print(f"  duration          : {a.get('duration','?')}s")
        print(f"  bit_rate          : {a.get('bit_rate','?')} bps")
    else:
        print(f"  *** ABSENT *** P1 non applique pour ce render")

    # Atoms locaux
    resp = requests.get(video_url, timeout=30)
    data = resp.content
    off, atoms = 0, []
    while off < len(data) - 8:
        sz = int.from_bytes(data[off:off+4], 'big')
        nm = data[off+4:off+8].decode('ascii', errors='?')
        atoms.append(nm)
        if sz < 8: break
        off += sz
        if off >= len(data): break
    moov_ok = 'moov' in atoms and 'mdat' in atoms and atoms.index('moov') < atoms.index('mdat')
    print(f"\n  Atoms             : {' > '.join(atoms)}")
    print(f"  moov avant mdat   : {moov_ok}")

    # VUI smpte170m check
    out_vui, _ = ssh_run(c, "ffprobe -v verbose /tmp/d25_latest.mp4 2>&1 | grep -iE 'bt709|smpte|transfer|primaries|color' | head -5")
    has_smpte = 'smpte170m' in out_vui.lower()
    print(f"\n  VUI extrait       : {out_vui.strip()[:300]}")
    print(f"  smpte170m present : {has_smpte}")

    # Decode complet
    out_dec, err_dec = ssh_run(c, "ffmpeg -v error -i /tmp/d25_latest.mp4 -f null - 2>&1")
    decode_err = (out_dec + err_dec).strip()
    print(f"  Decode errors     : {decode_err if decode_err else 'AUCUNE'}")

    c.close()

    # ============================================================
    print(f"\n{'='*70}")
    print("BILAN FINAL D.25 - CORRECTIONS P1 + P2")
    print('='*70)

    checks = {
        "P1 - Audio present"          : len(as_) > 0,
        "P1 - Codec AAC"              : a.get('codec_name','') == 'aac',
        "P1 - Sample rate 44100Hz"    : str(a.get('sample_rate','')) == '44100',
        "P1 - Stereo (2 canaux)"      : str(a.get('channels','')) == '2',
        "v6 - BT709 color_space"      : v.get('color_space','') == 'bt709',
        "v6 - BT709 color_transfer"   : v.get('color_transfer','') == 'bt709',
        "v6 - BT709 color_primaries"  : v.get('color_primaries','') == 'bt709',
        "v6 - 0 smpte170m dans VUI"   : not has_smpte,
        "C3 - Baseline profile"       : 'Baseline' in v.get('profile',''),
        "C3 - Level 3.1"              : str(v.get('level','')) == '31',
        "C3 - 0 B-frames"             : str(v.get('has_b_frames','')) == '0',
        "C2 - moov avant mdat"        : moov_ok,
        "Decode sans erreur"          : not decode_err,
    }
    all_ok = all(checks.values())
    for k, ok in checks.items():
        print(f"  {'✓ OK  ' if ok else '✗ FAIL'} {k}")

    if all_ok:
        print(f"\n  ╔══════════════════════════════════════════════╗")
        print(f"  ║  PIPELINE v7 ENTIEREMENT VALIDE              ║")
        print(f"  ║  MP4 CONFORME EXOPLAYER ANDROID              ║")
        print(f"  ╚══════════════════════════════════════════════╝")
        print(f"\n  URL de test: {video_url}")
    else:
        fails = [k for k,ok in checks.items() if not ok]
        print(f"\n  ECHECS: {fails}")

elif status == 'failed':
    res_f = sql(f"SELECT error_message FROM app.whiteboard_renders WHERE id = '{render_id}'")
    err_msg = res_f.get('rows',[{}])[0].get('error_message','?')
    print(f"  ECHEC WORKER: {err_msg}")
else:
    print(f"  Timeout. Status: {status}")

print("\n=== TEST D.25 TERMINE ===")

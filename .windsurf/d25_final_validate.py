#!/usr/bin/env python3
"""Validation finale du render ad74ed9e produit par worker v7"""
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

def ssh_run(c, cmd, timeout=120):
    _, o, e = c.exec_command(cmd, timeout=timeout)
    return o.read().decode(errors='replace'), e.read().decode(errors='replace')

# Recuperer l'URL
res = sql(f"SELECT status, video_url FROM app.whiteboard_renders WHERE id = '{RENDER_ID}'")
rows = res.get('rows', [])
print(f"Render {RENDER_ID[:8]}...")
if not rows:
    print(f"Non trouve: {res}")
    sys.exit(1)
row = rows[0]
print(f"  status    : {row.get('status')}")
video_url = row.get('video_url', '')
print(f"  video_url : {video_url}")

if not video_url or row.get('status') != 'done':
    print("Render pas done ou URL manquante")
    sys.exit(1)

# Validation
c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect(**KM)

out, _ = ssh_run(c, f"""
curl -s -o /tmp/d25_ad74.mp4 '{video_url}'
echo "SIZE_BYTES=$(stat -c%s /tmp/d25_ad74.mp4)"
ffprobe -v quiet -print_format json -show_streams -show_format /tmp/d25_ad74.mp4 2>/dev/null
""")

# Size
for ln in out.split('\n'):
    if 'SIZE_BYTES' in ln:
        print(f"\n  Taille    : {ln.strip()}")

# Parse JSON
start = out.find('{')
info = json.loads(out[start:]) if start >= 0 else {}
fmt = info.get('format', {})
streams = info.get('streams', [])
vs = [s for s in streams if s.get('codec_type') == 'video']
as_ = [s for s in streams if s.get('codec_type') == 'audio']
v = vs[0] if vs else {}
a = as_[0] if as_ else {}

print(f"  Duration  : {fmt.get('duration','?')}s")
print(f"  Streams   : {len(streams)} (video={len(vs)}, audio={len(as_)})")
print(f"\n  [VIDEO]")
print(f"  codec      : {v.get('codec_name','?')} | {v.get('profile','?')} | level={v.get('level','?')}")
print(f"  resolution : {v.get('width','?')}x{v.get('height','?')} | {v.get('pix_fmt','?')}")
print(f"  fps        : {v.get('avg_frame_rate','?')} | b_frames={v.get('has_b_frames','?')}")
print(f"  color_space: {v.get('color_space','?')}")
print(f"  color_trc  : {v.get('color_transfer','?')}")
print(f"  color_prim : {v.get('color_primaries','?')}")
print(f"  color_range: {v.get('color_range','?')}")
print(f"\n  [AUDIO - P1]")
if as_:
    print(f"  codec      : {a.get('codec_name','?')}")
    print(f"  sample_rate: {a.get('sample_rate','?')} Hz")
    print(f"  channels   : {a.get('channels','?')}")
    print(f"  duration   : {a.get('duration','?')}s")
else:
    print(f"  AUCUNE PISTE AUDIO - P1 non actif!")

# Atoms
resp = requests.get(video_url, timeout=30)
data = resp.content
off, atoms = 0, []
while off < len(data)-8:
    sz = int.from_bytes(data[off:off+4],'big')
    nm = data[off+4:off+8].decode('ascii',errors='?')
    atoms.append(nm)
    if sz < 8: break
    off += sz
    if off >= len(data): break
moov_ok = 'moov' in atoms and 'mdat' in atoms and atoms.index('moov') < atoms.index('mdat')
print(f"\n  Atoms      : {' > '.join(atoms)}")
print(f"  moov<mdat  : {moov_ok}")

# VUI
out_vui, _ = ssh_run(c, "ffprobe -v verbose /tmp/d25_ad74.mp4 2>&1 | grep -iE 'bt709|smpte|transfer|primaries|color' | head -5")
has_smpte = 'smpte170m' in out_vui.lower()
print(f"\n  VUI        : {out_vui.strip()[:200]}")
print(f"  smpte170m  : {has_smpte}")

# Decode
out_d, err_d = ssh_run(c, "ffmpeg -v error -i /tmp/d25_ad74.mp4 -f null - 2>&1")
decode_err = (out_d+err_d).strip()
print(f"  Decode err : {decode_err if decode_err else 'AUCUNE'}")

c.close()

# Bilan
print(f"\n{'='*70}")
print("BILAN D.25 - CORRECTIONS APPLIQUEES ET TESTEES")
print('='*70)
checks = {
    "P1 - Audio present"        : len(as_) > 0,
    "P1 - Codec AAC"            : a.get('codec_name','') == 'aac',
    "P1 - Sample 44100Hz"       : str(a.get('sample_rate','')) == '44100',
    "P1 - Stereo"               : str(a.get('channels','')) == '2',
    "v6 - BT709 color_space"    : v.get('color_space','') == 'bt709',
    "v6 - BT709 color_trc"      : v.get('color_transfer','') == 'bt709',
    "v6 - BT709 color_primaries": v.get('color_primaries','') == 'bt709',
    "v6 - 0 smpte170m VUI"      : not has_smpte,
    "C3 - Baseline profile"     : 'Baseline' in v.get('profile',''),
    "C3 - Level 3.1"            : str(v.get('level','')) == '31',
    "C3 - 0 B-frames"           : str(v.get('has_b_frames','')) == '0',
    "C2 - moov avant mdat"      : moov_ok,
    "Decode sans erreur"        : not decode_err,
}
all_ok = all(checks.values())
for k, ok in checks.items():
    print(f"  {'OK   ' if ok else 'ECHEC'} {k}")

if all_ok:
    print(f"\n  *** TOUTES LES CORRECTIONS VALIDEES ***")
    print(f"  *** MP4 v7 CONFORME EXOPLAYER ANDROID ***")
    print(f"\n  render_id : {RENDER_ID}")
    print(f"  URL       : {video_url}")
else:
    fails = [k for k,ok in checks.items() if not ok]
    print(f"\n  ECHECS: {fails}")

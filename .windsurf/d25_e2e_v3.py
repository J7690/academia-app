#!/usr/bin/env python3
"""D.25 - TEST E2E v3 : Cherche le dernier render du project et valide"""
import sys, json, time, requests, paramiko
sys.stdout.reconfigure(encoding='utf-8')

SUPABASE = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SKEY     = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H        = {"apikey": SKEY, "Authorization": f"Bearer {SKEY}", "Content-Type": "application/json"}
KM       = dict(hostname="185.167.97.144", username="root", password="Nexiomgroup@Academia0", timeout=30)
PROJECT_ID = "3fa88728-9ce5-489e-8f51-85dc3b87f7f4"

def sql(q):
    r = requests.post(f"{SUPABASE}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": q}, timeout=30)
    return r.json()

def ssh_run(c, cmd, timeout=120):
    _, o, e = c.exec_command(cmd, timeout=timeout)
    return o.read().decode(errors='replace'), e.read().decode(errors='replace')

print("="*70)
print("TEST E2E v3 - Valider le dernier render produit par v7")
print("="*70)

# 1. Trouver le dernier render de ce project (recemment insere)
print("\n[1] Derniers renders pour ce project...")
res = sql(f"""
SELECT id, status, video_url, created_at, error_message
FROM app.whiteboard_renders
WHERE project_id = '{PROJECT_ID}'
ORDER BY created_at DESC
LIMIT 5
""")
rows = res.get('rows', [])
for r in rows:
    url = str(r.get('video_url',''))[:80] if r.get('video_url') else 'null'
    print(f"  id={str(r.get('id',''))[:8]}... status={r.get('status')} url={url}")

# Le plus recent
if not rows:
    print("Aucun render trouve")
    sys.exit(1)

last = rows[0]
render_id = last['id']
status = last['status']
video_url = last.get('video_url','')

print(f"\n  Render selectionne: {render_id}")
print(f"  Status actuel: {status}")

# 2. Si pas done, attendre
if status not in ('done', 'failed'):
    print(f"\n[2] Attente completion (max 60s)...")
    deadline = time.time() + 60
    t0 = time.time()
    while time.time() < deadline:
        res2 = sql(f"SELECT status, video_url, error_message FROM app.whiteboard_renders WHERE id = '{render_id}'")
        rows2 = res2.get('rows', [])
        if rows2:
            status = rows2[0].get('status', '?')
            video_url = rows2[0].get('video_url', '')
            elapsed = int(time.time()-t0)
            print(f"  t={elapsed:3d}s status={status}")
            if status in ('done', 'failed'):
                break
        time.sleep(3)
elif status == 'done':
    print("\n  [2] Render deja done - validation immediate")

print(f"\n  Status final: {status}")

# 3. Validation MP4
if status == 'done' and video_url:
    print(f"\n[3] VALIDATION MP4 v7")
    print(f"  URL: {video_url}")

    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(**KM)

    out, _ = ssh_run(c, f"""
curl -s -o /tmp/d25_v3.mp4 '{video_url}' 2>&1
echo "SIZE: $(stat -c%s /tmp/d25_v3.mp4) bytes"
ffprobe -v quiet -print_format json -show_streams -show_format /tmp/d25_v3.mp4 2>/dev/null
""")

    # Separer la taille du JSON
    lines = out.split('\n')
    size_line = [l for l in lines if l.startswith('SIZE:')]
    if size_line: print(f"  {size_line[0]}")

    json_str = out
    try:
        # Trouver le debut du JSON
        start = out.find('{')
        if start >= 0:
            json_str = out[start:]
        info = json.loads(json_str)
        fmt = info.get('format', {})
        streams = info.get('streams', [])
        vs = [s for s in streams if s.get('codec_type')=='video']
        as_ = [s for s in streams if s.get('codec_type')=='audio']
        v = vs[0] if vs else {}
        a = as_[0] if as_ else {}

        print(f"\n  === FFPROBE ===")
        print(f"  duration       : {fmt.get('duration','?')}s")
        print(f"  size           : {fmt.get('size','?')} bytes")
        print(f"  streams total  : {len(streams)} (video={len(vs)}, audio={len(as_)})")
        print(f"  [VIDEO]")
        print(f"  profile        : {v.get('profile','?')}")
        print(f"  level          : {v.get('level','?')}")
        print(f"  resolution     : {v.get('width')}x{v.get('height')}")
        print(f"  has_b_frames   : {v.get('has_b_frames','?')}")
        print(f"  color_space    : {v.get('color_space','?')}")
        print(f"  color_transfer : {v.get('color_transfer','?')}")
        print(f"  color_primaries: {v.get('color_primaries','?')}")
        print(f"  [AUDIO - P1 FIX]")
        if as_:
            print(f"  codec          : {a.get('codec_name','?')}")
            print(f"  sample_rate    : {a.get('sample_rate','?')}")
            print(f"  channels       : {a.get('channels','?')}")
            print(f"  duration       : {a.get('duration','?')}")
        else:
            print(f"  ABSENT - Fix P1 non effectif pour ce render!")

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
        print(f"\n  Atoms: {'>'.join(atoms)}")
        print(f"  moov<mdat: {moov_ok}")

        # Decode
        out3, err3 = ssh_run(c, "ffmpeg -v error -i /tmp/d25_v3.mp4 -f null - 2>&1")
        decode_err = (out3+err3).strip()

        # VUI check
        out4, _ = ssh_run(c, "ffprobe -v verbose /tmp/d25_v3.mp4 2>&1 | grep -iE 'bt709|smpte|transfer|primaries' | head -5")
        print(f"\n  VUI: {out4.strip()[:300]}")

        # Bilan
        print(f"\n{'='*70}")
        print("BILAN FINAL")
        print('='*70)
        checks = {
            "Audio present (P1)": len(as_) > 0,
            "Codec AAC": a.get('codec_name','') == 'aac',
            "Sample 44100Hz": str(a.get('sample_rate','')) == '44100',
            "BT709 pure (P1 v6)": v.get('color_space','') == 'bt709' and v.get('color_transfer','') == 'bt709',
            "0 smpte170m": 'smpte170m' not in out4.lower(),
            "Baseline 3.1": str(v.get('level','')) == '31',
            "No B-frames": str(v.get('has_b_frames','')) == '0',
            "moov<mdat": moov_ok,
            "Decode sans erreur": not decode_err,
        }
        all_ok = all(checks.values())
        for k, ok in checks.items():
            print(f"  {'OK   ' if ok else 'ECHEC'} {k}")
        if all_ok:
            print(f"\n  *** PIPELINE v7 VALIDE ***")
            print(f"  MP4 COMPATIBLE EXOPLAYER ANDROID")
            print(f"  URL: {video_url}")
        else:
            fails = [k for k,ok in checks.items() if not ok]
            print(f"\n  ECHECS: {fails}")

    except Exception as ex:
        print(f"  Erreur: {ex}")
        print(f"  Raw: {out[:1000]}")

    c.close()

elif status == 'failed':
    err_res = sql(f"SELECT error_message FROM app.whiteboard_renders WHERE id = '{render_id}'")
    print(f"ECHEC: {err_res}")
else:
    print(f"Status: {status} — pas de validation possible")

print("\n=== E2E v3 TERMINE ===")

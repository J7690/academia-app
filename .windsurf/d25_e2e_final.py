#!/usr/bin/env python3
"""D.25 - TEST E2E FINAL : Render v7 + validation audio+video"""
import sys, json, time, requests, paramiko
sys.stdout.reconfigure(encoding='utf-8')

SUPABASE = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SKEY     = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H        = {"apikey": SKEY, "Authorization": f"Bearer {SKEY}", "Content-Type": "application/json"}
KM       = dict(hostname="185.167.97.144", username="root", password="Nexiomgroup@Academia0", timeout=30)

# Project existant avec student_id=user_id correct
PROJECT_ID = "3fa88728-9ce5-489e-8f51-85dc3b87f7f4"

def sql(q):
    r = requests.post(f"{SUPABASE}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": q}, timeout=30)
    return r.json()

def ssh_run(c, cmd, timeout=120):
    _, o, e = c.exec_command(cmd, timeout=timeout)
    return o.read().decode(errors='replace'), e.read().decode(errors='replace')

print("="*70)
print("TEST E2E FINAL - RENDER v7 (Audio AAC + BT709 pur)")
print("="*70)

# 1. Creer un render job
print(f"\n[1] Insertion render job pour project {PROJECT_ID[:8]}...")
res = sql(f"""
INSERT INTO app.whiteboard_renders (project_id, status, progress)
VALUES ('{PROJECT_ID}', 'queued', 0)
RETURNING id
""")

if res.get('ok') or 'rows' in res:
    # Recuperer l'ID insere
    res2 = sql(f"""
SELECT id FROM app.whiteboard_renders 
WHERE project_id = '{PROJECT_ID}' AND status = 'queued' 
ORDER BY created_at DESC LIMIT 1
""")
    rows = res2.get('rows', [])
    if not rows:
        print(f"Erreur recuperation render_id: {res2}")
        sys.exit(1)
    render_id = rows[0]['id']
    print(f"  render_id: {render_id}")
else:
    print(f"Erreur insertion: {res}")
    sys.exit(1)

# 2. Attendre le traitement par le worker
print(f"\n[2] Attente traitement par worker v7 (max 90s)...")
deadline = time.time() + 90
status = 'queued'
video_url = None
t0 = time.time()

while time.time() < deadline:
    res3 = sql(f"SELECT status, video_url, error_message FROM app.whiteboard_renders WHERE id = '{render_id}'")
    rows3 = res3.get('rows', [])
    if rows3:
        status = rows3[0].get('status', '?')
        video_url = rows3[0].get('video_url', '')
        err = rows3[0].get('error_message', '')
        elapsed = int(time.time() - t0)
        print(f"  t={elapsed:3d}s status={status}", end='')
        if video_url: print(f" url=...{str(video_url)[-40:]}", end='')
        print()
        if status in ('done', 'failed'):
            break
    time.sleep(3)

print(f"\n  Status final: {status}")
print(f"  Duree traitement: {int(time.time()-t0)}s")

# 3. Validation du MP4 produit
if status == 'done' and video_url:
    print(f"\n[3] VALIDATION MP4 v7")
    print(f"  URL: {video_url}")

    # Taille
    head = requests.head(video_url, timeout=15)
    size = int(head.headers.get('content-length', 0))
    print(f"  Taille: {size} bytes ({size/1024:.1f} KB)")

    # Telecharger
    resp = requests.get(video_url, timeout=60)
    data = resp.content
    print(f"  Download: HTTP {resp.status_code} ({len(data)} bytes)")

    # Atoms
    off, atoms = 0, []
    while off < len(data)-8:
        sz = int.from_bytes(data[off:off+4],'big')
        nm = data[off+4:off+8].decode('ascii',errors='?')
        atoms.append(nm)
        if sz < 8: break
        off += sz
        if off >= len(data): break
    moov_ok = 'moov' in atoms and 'mdat' in atoms and atoms.index('moov') < atoms.index('mdat')
    print(f"  Atoms: {'>'.join(atoms)}")
    print(f"  moov<mdat: {moov_ok}")

    # ffprobe SSH
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(**KM)

    out, _ = ssh_run(c, f"curl -s -o /tmp/d25_e2e.mp4 '{video_url}' && ffprobe -v quiet -print_format json -show_streams -show_format /tmp/d25_e2e.mp4 2>/dev/null")
    try:
        info = json.loads(out)
        fmt = info.get('format', {})
        streams = info.get('streams', [])
        video_s = [s for s in streams if s.get('codec_type') == 'video']
        audio_s = [s for s in streams if s.get('codec_type') == 'audio']
        v = video_s[0] if video_s else {}
        a = audio_s[0] if audio_s else {}

        print(f"\n  === FFPROBE REEL ===")
        print(f"  duration         : {fmt.get('duration','?')}s")
        print(f"  size             : {fmt.get('size','?')} bytes")
        print(f"  streams          : {len(streams)} total (video={len(video_s)}, audio={len(audio_s)})")
        print(f"\n  [VIDEO]")
        print(f"  profile          : {v.get('profile','?')}")
        print(f"  level            : {v.get('level','?')}")
        print(f"  resolution       : {v.get('width','?')}x{v.get('height','?')}")
        print(f"  pix_fmt          : {v.get('pix_fmt','?')}")
        print(f"  fps              : {v.get('avg_frame_rate','?')}")
        print(f"  has_b_frames     : {v.get('has_b_frames','?')}")
        print(f"  color_space      : {v.get('color_space','?')}")
        print(f"  color_transfer   : {v.get('color_transfer','?')}")
        print(f"  color_primaries  : {v.get('color_primaries','?')}")
        print(f"  color_range      : {v.get('color_range','?')}")
        print(f"\n  [AUDIO - P1]")
        print(f"  codec_audio      : {a.get('codec_name','ABSENT')}")
        print(f"  sample_rate      : {a.get('sample_rate','?')}")
        print(f"  channels         : {a.get('channels','?')}")
        print(f"  bit_rate         : {a.get('bit_rate','?')}")
        print(f"  duration_audio   : {a.get('duration','?')}")

        # Verification smpte170m dans VUI
        out2, _ = ssh_run(c, "ffprobe -v verbose /tmp/d25_e2e.mp4 2>&1 | grep -iE 'smpte|bt709|transfer|primaries|color' | head -10")
        print(f"\n  [VUI BITSTREAM]")
        print(out2[:800])

        # Decode
        out3, err3 = ssh_run(c, "ffmpeg -v error -i /tmp/d25_e2e.mp4 -f null - 2>&1")
        decode_err = (out3+err3).strip()
        print(f"\n  [DECODE]")
        print(f"  Erreurs: {decode_err if decode_err else 'AUCUNE'}")

        # Bilan final
        print(f"\n{'='*70}")
        print(f"BILAN FINAL - RENDER v7")
        print(f"{'='*70}")
        checks = {
            "Audio present": len(audio_s) > 0,
            "Codec AAC": a.get('codec_name','') == 'aac',
            "Sample rate 44100": str(a.get('sample_rate','')) == '44100',
            "BT709 color_space": v.get('color_space','') == 'bt709',
            "BT709 color_trc": v.get('color_transfer','') == 'bt709',
            "BT709 color_prim": v.get('color_primaries','') == 'bt709',
            "Baseline profile": 'Baseline' in v.get('profile',''),
            "Level 3.1": str(v.get('level','')) == '31',
            "No B-frames": str(v.get('has_b_frames','')) == '0',
            "moov<mdat": moov_ok,
            "Decode OK": not decode_err,
        }
        all_ok = True
        for name, ok in checks.items():
            mark = "OK" if ok else "ECHEC"
            print(f"  {mark:5s} {name}")
            if not ok: all_ok = False

        if all_ok:
            print(f"\n*** PIPELINE v7 COMPLET - TOUS LES CHECKS PASSES ***")
            print(f"URL de la video: {video_url}")
        else:
            print(f"\nECHECS detectes - voir details ci-dessus")

    except json.JSONDecodeError:
        print(f"Parse ffprobe error. Raw: {out[:500]}")

    c.close()

elif status == 'failed':
    res_err = sql(f"SELECT error_message FROM app.whiteboard_renders WHERE id = '{render_id}'")
    print(f"ECHEC WORKER: {res_err.get('rows',[])[0].get('error_message','?') if res_err.get('rows') else res_err}")

else:
    print(f"Timeout ou status inattendu: {status}")

print("\n=== TEST E2E TERMINE ===")

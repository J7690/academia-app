#!/usr/bin/env python3
"""
D.25 - TEST END-TO-END COMPLET
Creer un render job -> attendre traitement -> valider MP4 avec audio
"""
import sys, json, time, struct, requests, paramiko
sys.stdout.reconfigure(encoding='utf-8')

SUPABASE = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SKEY     = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H        = {"apikey": SKEY, "Authorization": f"Bearer {SKEY}", "Content-Type": "application/json"}
KM       = dict(hostname="185.167.97.144", username="root", password="Nexiomgroup@Academia0", timeout=30)

USER_ID = "6745c7ad-732b-47d0-b5b8-06d6dcf286ff"

def sql(q):
    r = requests.post(f"{SUPABASE}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": q}, timeout=30)
    return r.json()

print("="*70)
print("TEST E2E - PIPELINE COMPLET v7")
print("="*70)

# 1. Trouver un project_id existant pour ce user
print("\n[1] Recherche project existant...")
res = sql(f"SELECT id, subject, storyboard_json->'scenes' FROM app.whiteboard_projects WHERE student_id = (SELECT id FROM app.students WHERE user_id = '{USER_ID}' LIMIT 1) ORDER BY created_at DESC LIMIT 3")
rows = res.get('rows', [])
project_id = None
for row in rows:
    pid = row.get('id')
    subj = row.get('subject','?')
    scenes = row.get('?column?', [])
    nb = len(scenes) if isinstance(scenes, list) else '?'
    print(f"  project: {pid} subject={subj} scenes={nb}")
    if project_id is None:
        project_id = pid

if not project_id:
    print("ERREUR: Aucun project trouve pour ce user")
    sys.exit(1)

print(f"  -> Utilisation project_id: {project_id}")

# 2. Creer un render job directement dans app.whiteboard_renders
print("\n[2] Creation render job directement en DB...")
res2 = sql(f"""
INSERT INTO app.whiteboard_renders (project_id, status, progress)
VALUES ('{project_id}', 'queued', 0)
RETURNING id, status, created_at
""")
if res2.get('ok'):
    print("Insert OK")
    # Recuperer le render_id
    res2b = sql(f"SELECT id FROM app.whiteboard_renders WHERE project_id = '{project_id}' AND status = 'queued' ORDER BY created_at DESC LIMIT 1")
    rows2 = res2b.get('rows', [])
    if rows2:
        render_id = rows2[0]['id']
        print(f"  render_id: {render_id}")
    else:
        print(f"ERREUR: {res2b}")
        sys.exit(1)
else:
    print(f"Reponse: {res2}")
    # Essayer de trouver le dernier render queued
    res2c = sql(f"SELECT id FROM app.whiteboard_renders WHERE project_id = '{project_id}' AND status IN ('queued','processing') ORDER BY created_at DESC LIMIT 1")
    rows2c = res2c.get('rows', [])
    if rows2c:
        render_id = rows2c[0]['id']
        print(f"  render_id existant: {render_id}")
    else:
        print("Pas de render en cours. Insertion directe necessaire.")
        sys.exit(1)

# 3. Attendre le traitement (max 60s)
print(f"\n[3] Attente traitement render {render_id}...")
deadline = time.time() + 90
status = 'queued'
while time.time() < deadline:
    res3 = sql(f"SELECT status, video_url, error_message FROM app.whiteboard_renders WHERE id = '{render_id}'")
    rows3 = res3.get('rows', [])
    if rows3:
        status = rows3[0].get('status', '?')
        video_url = rows3[0].get('video_url', '')
        err = rows3[0].get('error_message', '')
        print(f"  status={status} url={str(video_url)[:60] if video_url else 'null'}")
        if status == 'done':
            break
        elif status == 'failed':
            print(f"  ERREUR: {err}")
            break
    time.sleep(3)

# 4. Valider le MP4 produit
if status == 'done' and video_url:
    print(f"\n[4] VALIDATION MP4: {video_url}")
    resp = requests.get(video_url, timeout=30)
    print(f"  HTTP: {resp.status_code} taille: {len(resp.content)} bytes")

    if resp.status_code == 200:
        data = resp.content

        # Atoms
        off, atoms = 0, []
        while off < len(data)-8:
            sz = int.from_bytes(data[off:off+4],'big')
            nm = data[off+4:off+8].decode('ascii',errors='?')
            atoms.append(nm)
            if sz < 8: break
            off += sz
            if off >= len(data): break
        print(f"  Atoms: {'>'.join(atoms)}")
        moov_ok = 'moov' in atoms and 'mdat' in atoms and atoms.index('moov') < atoms.index('mdat')
        print(f"  moov<mdat: {moov_ok}")

        # Sauvegarder pour ffprobe
        with open(r"C:\tmp\d25_v7_final.mp4", "wb") as f:
            f.write(data)

        # ffprobe via SSH
        c = paramiko.SSHClient()
        c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        c.connect(**KM)
        _, o, e = c.exec_command(f"""
curl -s -o /tmp/d25_v7_final.mp4 '{video_url}' && \
ffprobe -v quiet -print_format json -show_streams -show_format /tmp/d25_v7_final.mp4 2>/dev/null
""", timeout=60)
        out = o.read().decode(errors='replace')
        try:
            info = json.loads(out)
            fmt = info.get('format', {})
            streams = info.get('streams', [])
            video = [s for s in streams if s.get('codec_type') == 'video']
            audio = [s for s in streams if s.get('codec_type') == 'audio']
            v = video[0] if video else {}
            a = audio[0] if audio else {}

            print(f"\n  === FFPROBE MP4 v7 REEL ===")
            print(f"  duration       : {fmt.get('duration','?')}s")
            print(f"  streams        : video={len(video)} audio={len(audio)}")
            print(f"  codec_video    : {v.get('codec_name','?')} {v.get('profile','?')} level={v.get('level','?')}")
            print(f"  color_space    : {v.get('color_space','?')}")
            print(f"  color_transfer : {v.get('color_transfer','?')}")
            print(f"  color_primaries: {v.get('color_primaries','?')}")
            print(f"  has_b_frames   : {v.get('has_b_frames','?')}")
            print(f"  codec_audio    : {a.get('codec_name','ABSENT')}")
            print(f"  sample_rate    : {a.get('sample_rate','?')}")
            print(f"  channels       : {a.get('channels','?')}")

            checks = {
                "moov<mdat": moov_ok,
                "audio_present": len(audio) > 0,
                "codec_aac": a.get('codec_name','') == 'aac',
                "bt709_cs": v.get('color_space','') == 'bt709',
                "bt709_trc": v.get('color_transfer','') == 'bt709',
                "bt709_prim": v.get('color_primaries','') == 'bt709',
                "baseline": 'Baseline' in v.get('profile',''),
                "level_31": str(v.get('level','')) == '31',
                "no_bframes": str(v.get('has_b_frames','')) == '0',
            }
            fails = [k for k,v in checks.items() if not v]
            print(f"\n  === RESULTAT FINAL ===")
            for k, ok in checks.items():
                print(f"  {'OK' if ok else 'ECHEC'} {k}")
            if not fails:
                print(f"\n  *** SUCCES COMPLET - MP4 v7 CONFORME EXOPLAYER ***")
                print(f"  URL: {video_url}")
            else:
                print(f"\n  ECHECS: {fails}")

        except json.JSONDecodeError:
            print(f"  ffprobe parse error. Raw: {out[:500]}")

        # Test decode
        _, o2, e2 = c.exec_command("ffmpeg -v error -i /tmp/d25_v7_final.mp4 -f null - 2>&1", timeout=60)
        decode_err = (o2.read() + e2.read()).decode(errors='replace').strip()
        if decode_err:
            print(f"  DECODE ERRORS: {decode_err[:500]}")
        else:
            print(f"  Decode complet: OK (0 erreur)")

        c.close()
else:
    print(f"\nStatus final: {status} — MP4 non disponible pour validation")

print("\n=== FIN TEST E2E ===")

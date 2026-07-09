#!/usr/bin/env python3
"""D.25 - TEST E2E v2 : whiteboard_get_any_student_id + insert direct"""
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
print("TEST E2E v2 - Render via whiteboard_get_any_student_id")
print("="*70)

# Utiliser la RPC whiteboard_get_any_student_id pour trouver un student_id valide
print("\n[0] Trouver student_id via RPC whiteboard_get_any_student_id...")
res0 = requests.post(f"{SUPABASE}/rest/v1/rpc/whiteboard_get_any_student_id", headers=H, json={}, timeout=15)
print(f"  HTTP: {res0.status_code} -> {res0.text[:200]}")

# Chercher un project_id qui a bien un FK valide dans whiteboard_renders
print("\n[0b] Verifier la contrainte FK de whiteboard_renders...")
res_fk = sql("""
SELECT 
    tc.constraint_name,
    kcu.column_name,
    ccu.table_schema || '.' || ccu.table_name AS references_table,
    ccu.column_name AS references_column
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage ccu ON ccu.constraint_name = tc.constraint_name
WHERE tc.table_schema = 'app' AND tc.table_name = 'whiteboard_renders'
AND tc.constraint_type = 'FOREIGN KEY'
""")
print(f"  FKs: {res_fk.get('rows', [])}")

# Trouver un project_id qui existe reellement dans whiteboard_projects
print("\n[1] Projects existants dans whiteboard_projects...")
res1 = sql("SELECT id, student_id, subject FROM app.whiteboard_projects ORDER BY created_at DESC LIMIT 3")
rows1 = res1.get('rows', [])
for r in rows1:
    print(f"  id={r.get('id')} student={r.get('student_id')} subject={r.get('subject')}")

if not rows1:
    print("ERREUR: Aucun project trouve")
    sys.exit(1)

project_id = rows1[0]['id']
print(f"\n  -> project_id selectionne: {project_id}")

# Verifier si project existe vraiment
res_check = sql(f"SELECT COUNT(*) as n FROM app.whiteboard_projects WHERE id = '{project_id}'")
print(f"  Exists check: {res_check.get('rows',[])}")

# Essayer l'insert avec RETURNING explicite
print(f"\n[2] INSERT render job...")
res2 = sql(f"""
WITH inserted AS (
    INSERT INTO app.whiteboard_renders (project_id, status, progress)
    VALUES ('{project_id}', 'queued', 0)
    RETURNING id, project_id, status, created_at
)
SELECT * FROM inserted
""")
print(f"  Resultat INSERT: {res2}")

render_id = None
if res2.get('rows'):
    render_id = res2['rows'][0]['id']
    print(f"  render_id insere: {render_id}")
else:
    # Essayer de recuperer le plus recent queued
    res2b = sql(f"SELECT id FROM app.whiteboard_renders WHERE project_id = '{project_id}' AND status = 'queued' ORDER BY created_at DESC LIMIT 1")
    rows2b = res2b.get('rows', [])
    if rows2b:
        render_id = rows2b[0]['id']
        print(f"  render_id existant trouve: {render_id}")
    else:
        # Chercher n'importe quel render recent queued
        res2c = sql("SELECT id, project_id, status FROM app.whiteboard_renders WHERE status = 'queued' ORDER BY created_at DESC LIMIT 3")
        print(f"  Renders queued disponibles: {res2c.get('rows', [])}")
        rows2c = res2c.get('rows', [])
        if rows2c:
            render_id = rows2c[0]['id']
        else:
            print("Aucun render queued. Verifier insert manuel.")
            sys.exit(1)

# 3. Attendre traitement
print(f"\n[3] Attente traitement render {render_id}...")
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
        print(f"  t={elapsed:3d}s status={status}{' url=...'+str(video_url)[-40:] if video_url else ''}")
        if status in ('done', 'failed'):
            break
    time.sleep(3)

print(f"\n  Status: {status} | Duree: {int(time.time()-t0)}s")

# 4. Validation si done
if status == 'done' and video_url:
    print(f"\n[4] VALIDATION MP4 v7")
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(**KM)

    out, _ = ssh_run(c, f"""
curl -s -o /tmp/d25_e2e2.mp4 '{video_url}'
ffprobe -v quiet -print_format json -show_streams -show_format /tmp/d25_e2e2.mp4 2>/dev/null
""")
    try:
        info = json.loads(out)
        streams = info.get('streams', [])
        fmt = info.get('format', {})
        vs = [s for s in streams if s.get('codec_type')=='video']
        as_ = [s for s in streams if s.get('codec_type')=='audio']
        v = vs[0] if vs else {}
        a = as_[0] if as_ else {}

        print(f"  duration     : {fmt.get('duration')}s")
        print(f"  streams      : video={len(vs)} audio={len(as_)}")
        print(f"  codec_audio  : {a.get('codec_name','ABSENT')}")
        print(f"  sample_rate  : {a.get('sample_rate','?')}")
        print(f"  color_space  : {v.get('color_space','?')}")
        print(f"  color_trc    : {v.get('color_transfer','?')}")
        print(f"  color_prim   : {v.get('color_primaries','?')}")
        print(f"  profile      : {v.get('profile','?')}")
        print(f"  level        : {v.get('level','?')}")
        print(f"  has_b_frames : {v.get('has_b_frames','?')}")

        # Decode test
        out2, err2 = ssh_run(c, "ffmpeg -v error -i /tmp/d25_e2e2.mp4 -f null - 2>&1")
        decode_err = (out2+err2).strip()

        checks = {
            "Audio present (P1)": len(as_) > 0,
            "Codec AAC": a.get('codec_name','') == 'aac',
            "BT709 cs": v.get('color_space','') == 'bt709',
            "BT709 trc": v.get('color_transfer','') == 'bt709',
            "BT709 prim": v.get('color_primaries','') == 'bt709',
            "Baseline 3.1": str(v.get('level','')) == '31',
            "0 B-frames": str(v.get('has_b_frames','')) == '0',
            "Decode OK": not decode_err,
        }
        print(f"\n  === BILAN ===")
        all_ok = all(checks.values())
        for k, ok in checks.items():
            print(f"  {'OK   ' if ok else 'ECHEC'} {k}")
        if all_ok:
            print(f"\n  *** PIPELINE v7 VALIDE - EXOPLAYER COMPATIBLE ***")
        else:
            fails = [k for k,ok in checks.items() if not ok]
            print(f"\n  ECHECS: {fails}")
    except Exception as ex:
        print(f"  Parse error: {ex}\n  Raw: {out[:500]}")
    c.close()

elif status == 'failed':
    res_f = sql(f"SELECT error_message FROM app.whiteboard_renders WHERE id = '{render_id}'")
    print(f"ECHEC WORKER: {res_f}")

print("\n=== E2E v2 TERMINE ===")

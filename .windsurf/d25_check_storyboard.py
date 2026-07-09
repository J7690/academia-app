#!/usr/bin/env python3
"""Vérifier structure storyboard et déclencher render via Kamatera"""
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

# 1. Lire le storyboard raw d'un project existant
print("=== Structure storyboard_json ===")
res = sql("SELECT id, storyboard_json FROM app.whiteboard_projects ORDER BY created_at DESC LIMIT 1")
rows = res.get('rows', [])
if rows:
    pid = rows[0]['id']
    sj = rows[0]['storyboard_json']
    print(f"project_id: {pid}")
    print(f"type: {type(sj)}")
    if isinstance(sj, str):
        sj = json.loads(sj)
    print(f"keys: {list(sj.keys()) if isinstance(sj, dict) else 'NOT DICT'}")
    if isinstance(sj, dict):
        scenes = sj.get('scenes', [])
        print(f"nb_scenes: {len(scenes)}")
        for i, sc in enumerate(scenes[:3]):
            print(f"  scene {i}: {list(sc.keys())}")
else:
    print(f"Pas de project: {res}")
    sys.exit(1)

# 2. Utiliser ce project_id avec storyboard valide et déclencher via Kamatera directement
print(f"\n=== Test render direct via Kamatera worker (inject job) ===")

c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect(**KM)

# Créer un job directement dans la DB depuis Kamatera
inject_script = f'''
import httpx, json, asyncio

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
KEY = "{SKEY}"
PROJECT_ID = "{pid}"

headers = {{
    "apikey": KEY,
    "Authorization": f"Bearer {{KEY}}",
    "Content-Type": "application/json"
}}

async def main():
    # Inserer un render job
    url_sql = f"{{SUPABASE_URL}}/rest/v1/rpc/admin_execute_sql"
    q = f"INSERT INTO app.whiteboard_renders (project_id, status, progress) VALUES (\\'{{PROJECT_ID}}\\', \\'queued\\', 0)"
    async with httpx.AsyncClient() as client:
        r = await client.post(url_sql, headers=headers, json={{"p_sql": q}}, timeout=20)
        print("INSERT:", r.status_code, r.text[:200])
        
        # Recuperer le render_id
        q2 = f"SELECT id FROM app.whiteboard_renders WHERE project_id = \\'{{PROJECT_ID}}\\' ORDER BY created_at DESC LIMIT 1"
        r2 = await client.post(url_sql, headers=headers, json={{"p_sql": q2}}, timeout=20)
        d2 = r2.json()
        print("RENDER_ID:", json.dumps(d2.get("rows",[])))

asyncio.run(main())
'''

sftp = c.open_sftp()
with sftp.open('/tmp/d25_inject.py', 'w') as f:
    f.write(inject_script)
sftp.close()

out, _ = ssh_run(c, "python3 /tmp/d25_inject.py 2>&1")
print(out[:2000])

# Attendre que le worker traite le job
print("\nAttente 30s pour que le worker traite le job...")
time.sleep(15)

# Check statut via logs
out2, _ = ssh_run(c, "journalctl -u whiteboard-worker --no-pager -n 20 2>/dev/null | grep -E 'Processing|Assembling|Uploading|completed|error|ERROR' | tail -10")
print("LOGS WORKER:")
print(out2)

# Trouver le dernier render done
check_script = f'''
import httpx, json, asyncio

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
KEY = "{SKEY}"
PROJECT_ID = "{pid}"

headers = {{"apikey": KEY, "Authorization": f"Bearer {{KEY}}", "Content-Type": "application/json"}}

async def main():
    url_sql = f"{{SUPABASE_URL}}/rest/v1/rpc/admin_execute_sql"
    q = f"SELECT id, status, video_url FROM app.whiteboard_renders WHERE project_id = \\'{{PROJECT_ID}}\\' ORDER BY created_at DESC LIMIT 3"
    async with httpx.AsyncClient() as client:
        r = await client.post(url_sql, headers=headers, json={{"p_sql": q}}, timeout=20)
        d = r.json()
        for row in d.get("rows", []):
            print(f"render={{row.get(\\'id\\',\\'?\\')[:8]}}... status={{row.get(\\'status\\')}} url={{str(row.get(\\'video_url\\',\\'null\\'))[:80]}}")

asyncio.run(main())
'''

sftp = c.open_sftp()
with sftp.open('/tmp/d25_check_render.py', 'w') as f:
    f.write(check_script)
sftp.close()

# Attendre encore
time.sleep(20)
out3, _ = ssh_run(c, "python3 /tmp/d25_check_render.py 2>&1")
print("RENDERS RECENTS:")
print(out3[:1000])

# Logs finaux
out4, _ = ssh_run(c, "journalctl -u whiteboard-worker --no-pager --since '2026-06-29 09:00' 2>/dev/null | grep -E 'Processing|completed|error' | tail -10")
print("LOGS FINAUX:")
print(out4)

c.close()

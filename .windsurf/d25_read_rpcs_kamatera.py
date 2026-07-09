#!/usr/bin/env python3
"""Lire les RPCs whiteboard depuis Kamatera via httpx"""
import sys, json, paramiko
sys.stdout.reconfigure(encoding='utf-8')

SUPABASE = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SKEY     = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
KM       = dict(hostname="185.167.97.144", username="root", password="Nexiomgroup@Academia0", timeout=30)

c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect(**KM)

def ssh(cmd, timeout=60):
    _, o, e = c.exec_command(cmd, timeout=timeout)
    out = o.read().decode(errors='replace')
    err = e.read().decode(errors='replace')
    if out.strip(): print(out[:6000])
    if err.strip() and 'Traceback' not in err: print(f"[ERR] {err[:300]}")
    return out

# Script Python pour recuperer les definitions RPC
script = f'''
import httpx, json

url = "{SUPABASE}/rest/v1/rpc/admin_execute_sql"
headers = {{
    "apikey": "{SKEY}",
    "Authorization": "Bearer {SKEY}",
    "Content-Type": "application/json"
}}

rpcs = [
    "whiteboard_get_render_status",
    "whiteboard_create_render_job",
    "whiteboard_mark_done",
    "whiteboard_mark_processing",
    "whiteboard_mark_failed",
    "whiteboard_fetch_queued_jobs",
    "whiteboard_list_projects",
]

for rpc in rpcs:
    q = f"SELECT pg_get_functiondef(oid) as def FROM pg_proc WHERE proname = \\"{rpc}\\";"
    r = httpx.post(url, headers=headers, json={{"p_sql": q}}, timeout=20)
    d = r.json()
    rows = d.get("rows", [])
    print(f"\\n{'='*60}")
    print(f"RPC: {{rpc}}")
    print("="*60)
    if rows:
        print(rows[0].get("def", "NO DEF")[:3000])
    else:
        print(f"Not found. Response: {{json.dumps(d)[:200]}}")
'''

# Ecrire le script dans /tmp
sftp = c.open_sftp()
with sftp.open('/tmp/d25_read_rpcs.py', 'w') as f:
    f.write(script)
sftp.close()

ssh("python3 /tmp/d25_read_rpcs.py 2>&1")

# Aussi verifier: quels renders existent dans app.whiteboard_renders
print("\n" + "="*60)
print("RENDERS DANS app.whiteboard_renders (via SQL direct)")
print("="*60)

script2 = f'''
import httpx, json

url = "{SUPABASE}/rest/v1/rpc/admin_execute_sql"
headers = {{
    "apikey": "{SKEY}",
    "Authorization": "Bearer {SKEY}",
    "Content-Type": "application/json"
}}

# Chercher les renders recents
q = "SELECT id, project_id, status, video_url, created_at FROM app.whiteboard_renders ORDER BY created_at DESC LIMIT 5;"
r = httpx.post(url, headers=headers, json={{"p_sql": q}}, timeout=20)
d = r.json()
rows = d.get("rows", [])
print(f"Renders trouves: {{len(rows)}}")
for row in rows:
    print(f"  id={{row.get('id')}} status={{row.get('status')}} url={{str(row.get('video_url',''))[:60]}}")
'''

sftp = c.open_sftp()
with sftp.open('/tmp/d25_check_renders.py', 'w') as f:
    f.write(script2)
sftp.close()

ssh("python3 /tmp/d25_check_renders.py 2>&1")

c.close()

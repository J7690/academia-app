#!/usr/bin/env python3
"""D25 - Recuperer storyboard via Kamatera (acces direct DB) + verif admin_execute_sql"""
import sys, json, requests, paramiko
sys.stdout.reconfigure(encoding='utf-8')

RENDER_ID = "07356b0d-ff4c-4ce2-80a9-9e7ec5306367"
SUPABASE  = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SKEY      = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H  = {"apikey": SKEY, "Authorization": f"Bearer {SKEY}", "Content-Type": "application/json"}
KM = dict(hostname="185.167.97.144", username="root", password="Nexiomgroup@Academia0", timeout=30)

def ssh_run(c, cmd, timeout=60):
    _, o, e = c.exec_command(cmd, timeout=timeout)
    return o.read().decode(errors='replace'), e.read().decode(errors='replace')

c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect(**KM)

# Le worker accede via REST API avec httpx - utiliser la meme approche
print("=== D25-01: STORYBOARD VIA KAMATERA ===")
out, _ = ssh_run(c, f"""python3 -c "
import httpx, json

url = 'https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/whiteboard_get_render_status'
headers = {{
    'apikey': '{SKEY}',
    'Authorization': 'Bearer {SKEY}',
    'Content-Type': 'application/json'
}}
r = httpx.post(url, headers=headers, json={{'p_render_id': '{RENDER_ID}'}}, timeout=20)
print('HTTP:', r.status_code)
data = r.json()

# Chercher les tables dans app schema
url2 = 'https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/whiteboard_fetch_queued_jobs'
r2 = httpx.post(url2, headers=headers, json={{}}, timeout=20)
print('FETCH QUEUED STATUS:', r2.status_code)
print('FETCH QUEUED BODY:', r2.text[:500])
" 2>&1
""")
print(out[:3000])

# Essayer de lire directement les tables whiteboard via REST
print("\n=== TABLES ACCESSIBLES REST ===")
for table in ['whiteboard_render_jobs', 'whiteboard_projects', 'whiteboard_renders']:
    r = requests.get(f"{SUPABASE}/rest/v1/{table}?id=eq.{RENDER_ID}&limit=1",
                     headers={**H, "Prefer": "return=representation"}, timeout=10)
    print(f"  {table}: HTTP {r.status_code} - {r.text[:200]}")

# Lire le worker code pour comprendre comment il accede a Supabase
print("\n=== D25-01: LECTURE WORKER POUR COMPRENDRE LES TABLES ===")
out2, _ = ssh_run(c, "grep -n 'whiteboard_render\\|whiteboard_project\\|whiteboard_fetch\\|whiteboard_mark\\|whiteboard_get' /opt/whiteboard-worker/whiteboard_render_worker.py 2>/dev/null | head -30")
print(out2[:3000])

# Lire le worker complet pour trouver l'acces Supabase
out3, _ = ssh_run(c, "cat /opt/whiteboard-worker/whiteboard_render_worker.py 2>/dev/null")
print("\n=== WHITEBOARD RENDER WORKER COMPLET ===")
print(out3[:8000])

c.close()

#!/usr/bin/env python3
"""
D.25 - APPLICATION CORRECTIONS P1 + P2
P1: Piste audio silencieuse dans FFmpeg assembler
P2: Diagnostic RPC whiteboard_get_render_status
"""
import sys, json, requests, paramiko
sys.stdout.reconfigure(encoding='utf-8')

SUPABASE = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SKEY     = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H        = {"apikey": SKEY, "Authorization": f"Bearer {SKEY}", "Content-Type": "application/json"}
KM       = dict(hostname="185.167.97.144", username="root", password="Nexiomgroup@Academia0", timeout=30)

def ssh_run(c, cmd, timeout=120):
    _, o, e = c.exec_command(cmd, timeout=timeout)
    return o.read().decode(errors='replace'), e.read().decode(errors='replace')

# ============================================================
print("="*70)
print("DIAGNOSTIC P2 : RPC whiteboard_get_render_status")
print("="*70)

# Tester avec un render_id connu
for rid in [
    "07356b0d-ff4c-4ce2-80a9-9e7ec5306367",
    "3b601453-fa7b-4f13-88a7-18683022d1a8",
]:
    r = requests.post(f"{SUPABASE}/rest/v1/rpc/whiteboard_get_render_status",
        headers=H, json={"p_render_id": rid}, timeout=15)
    print(f"render_id={rid[:8]}... -> HTTP {r.status_code} -> {r.text[:200]}")

# Lire la definition de la RPC depuis Kamatera (qui connait le vrai schema)
c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect(**KM)

print("\n--- Code de la RPC via Kamatera ---")
out, _ = ssh_run(c, f"""python3 -c "
import httpx, json
url = '{SUPABASE}/rest/v1/rpc/admin_execute_sql'
headers = {{
    'apikey': '{SKEY}',
    'Authorization': 'Bearer {SKEY}',
    'Content-Type': 'application/json'
}}
# Chercher la definition de la fonction
q = '''
SELECT n.nspname as schema, p.proname, pg_get_functiondef(p.oid) as def
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE p.proname = \\'whiteboard_get_render_status\\'
LIMIT 1;
'''
r = httpx.post(url, headers=headers, json={{'p_sql': q}}, timeout=20)
print('HTTP:', r.status_code)
d = r.json()
rows = d.get('rows', [])
if rows:
    print('Schema:', rows[0].get('schema'))
    print('DEF:', rows[0].get('def', '')[:3000])
else:
    print('Result:', json.dumps(d)[:500])
" 2>&1
""")
print(out[:4000])

# Aussi: lister tous les render jobs disponibles
print("\n--- Render jobs recents via whiteboard_fetch_queued_jobs ---")
out2, _ = ssh_run(c, f"""python3 -c "
import httpx, json
url = '{SUPABASE}/rest/v1/rpc/whiteboard_fetch_queued_jobs'
headers = {{
    'apikey': '{SKEY}',
    'Authorization': 'Bearer {SKEY}',
    'Content-Type': 'application/json'
}}
r = httpx.post(url, headers=headers, json={{'p_limit': 10}}, timeout=20)
print('HTTP:', r.status_code)
d = r.json()
print('Result:', json.dumps(d)[:1000])
" 2>&1
""")
print(out2[:2000])

c.close()

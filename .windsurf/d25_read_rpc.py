#!/usr/bin/env python3
"""D25 - Lire la definition de la RPC whiteboard_get_render_status"""
import sys, json, requests, paramiko
sys.stdout.reconfigure(encoding='utf-8')

SUPABASE = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SKEY     = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H        = {"apikey": SKEY, "Authorization": f"Bearer {SKEY}", "Content-Type": "application/json"}
KM       = dict(hostname="185.167.97.144", username="root", password="Nexiomgroup@Academia0", timeout=30)

def ssh_run(c, cmd, timeout=60):
    _, o, e = c.exec_command(cmd, timeout=timeout)
    return o.read().decode(errors='replace'), e.read().decode(errors='replace')

c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect(**KM)

# La RPC admin_execute_sql exige p_sql et retourne rows pour SELECT
# Le mode "exec" signifie qu'une statement DML a ete executee - probablement 
# la fonction a une restriction. On essaie avec SELECT explicite
queries = [
    ("pg_proc search", """SELECT n.nspname, p.proname FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE p.proname LIKE 'whiteboard%' ORDER BY n.nspname, p.proname"""),
    ("get_render_status def", """SELECT pg_get_functiondef(oid) as def FROM pg_proc WHERE proname = 'whiteboard_get_render_status'"""),
    ("whiteboard_mark_done def", """SELECT pg_get_functiondef(oid) as def FROM pg_proc WHERE proname = 'whiteboard_mark_done'"""),
]

for label, q in queries:
    print(f"\n{'='*60}")
    print(f"QUERY: {label}")
    print('='*60)
    out, _ = ssh_run(c, f"""python3 -c "
import httpx, json
url = '{SUPABASE}/rest/v1/rpc/admin_execute_sql'
headers = {{
    'apikey': '{SKEY}',
    'Authorization': 'Bearer {SKEY}',
    'Content-Type': 'application/json'
}}
q = '''{q}'''
r = httpx.post(url, headers=headers, json={{'p_sql': q}}, timeout=20)
d = r.json()
rows = d.get('rows', [])
if rows:
    for row in rows[:3]:
        for k,v in row.items():
            print(f'  {{k}}: {{str(v)[:2000]}}')
        print('---')
else:
    print('No rows. Full result:', json.dumps(d)[:300])
" 2>&1
""")
    print(out[:4000])

# Chercher dans les migrations SQL locales
c.close()

#!/usr/bin/env python3
"""Lire les RPCs whiteboard directement"""
import sys, json, requests, paramiko
sys.stdout.reconfigure(encoding='utf-8')

SUPABASE = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SKEY     = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H        = {"apikey": SKEY, "Authorization": f"Bearer {SKEY}", "Content-Type": "application/json"}
KM       = dict(hostname="185.167.97.144", username="root", password="Nexiomgroup@Academia0", timeout=30)

def sql(query):
    r = requests.post(f"{SUPABASE}/rest/v1/rpc/admin_execute_sql", headers=H,
                      json={"p_sql": query}, timeout=30)
    return r.json()

# Lister toutes les RPCs whiteboard
print("=== TOUTES LES RPCs whiteboard ===")
res = sql("SELECT n.nspname, p.proname FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE p.proname LIKE 'whiteboard%' ORDER BY n.nspname, p.proname")
for row in res.get('rows', []):
    print(f"  {row.get('nspname')}.{row.get('proname')}")

# Lire la def de whiteboard_get_render_status
print("\n=== whiteboard_get_render_status ===")
res2 = sql("SELECT pg_get_functiondef(p.oid) as def FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE p.proname = 'whiteboard_get_render_status'")
for row in res2.get('rows', []):
    print(row.get('def','')[:4000])
if not res2.get('rows'):
    print(f"Pas trouve. Reponse: {res2}")

# Lire la def de whiteboard_create_render_job
print("\n=== whiteboard_create_render_job ===")
res3 = sql("SELECT pg_get_functiondef(p.oid) as def FROM pg_proc p WHERE p.proname = 'whiteboard_create_render_job'")
for row in res3.get('rows', []):
    print(row.get('def','')[:3000])
if not res3.get('rows'):
    print(f"Pas trouve. Reponse: {res3}")

# Lire les renders recents dans app.whiteboard_renders
print("\n=== app.whiteboard_renders (5 derniers) ===")
res4 = sql("SELECT id, project_id, status, video_url, created_at FROM app.whiteboard_renders ORDER BY created_at DESC LIMIT 5")
if res4.get('rows'):
    for row in res4['rows']:
        print(f"  id={row.get('id')} status={row.get('status')} url={str(row.get('video_url',''))[:80]}")
else:
    print(f"Reponse: {res4}")

# Kamatera: verifier si les renders sont dans un whiteboard_render_jobs different
c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect(**KM)

print("\n=== TABLES EXISTANTES (Kamatera httpx) ===")
_, o, e = c.exec_command("""python3 -c "
import httpx, json

url = 'https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql'
h = {'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM', 'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM', 'Content-Type': 'application/json'}

q1 = 'SELECT tablename, schemaname FROM pg_tables WHERE tablename LIKE chr(119)||chr(104)||chr(105)||chr(116)||chr(101)||chr(98)||chr(111)||chr(97)||chr(114)||chr(100)||chr(37) ORDER BY schemaname, tablename'
r1 = httpx.post(url, headers=h, json={'p_sql': q1}, timeout=20)
d1 = r1.json()
print('TABLES:', json.dumps(d1.get('rows', []), indent=2))

# renders recents
q2 = 'SELECT id, status, video_url FROM app.whiteboard_renders ORDER BY created_at DESC LIMIT 3'
r2 = httpx.post(url, headers=h, json={'p_sql': q2}, timeout=20)
d2 = r2.json()
print('RENDERS:', json.dumps(d2.get('rows', []), indent=2))

# get_render_status
q3 = 'SELECT pg_get_functiondef(p.oid) as def FROM pg_proc p WHERE p.proname = chr(119)||chr(104)||chr(105)||chr(116)||chr(101)||chr(98)||chr(111)||chr(97)||chr(114)||chr(100)||chr(95)||chr(103)||chr(101)||chr(116)||chr(95)||chr(114)||chr(101)||chr(110)||chr(100)||chr(101)||chr(114)||chr(95)||chr(115)||chr(116)||chr(97)||chr(116)||chr(117)||chr(115)'
r3 = httpx.post(url, headers=h, json={'p_sql': q3}, timeout=20)
d3 = r3.json()
rows3 = d3.get('rows', [])
if rows3:
    print('GET_RENDER_STATUS DEF:', rows3[0].get('def','')[:3000])
else:
    print('GET_RENDER_STATUS not found:', json.dumps(d3)[:200])
" 2>&1""", timeout=60)
print(o.read().decode(errors='replace')[:5000])

c.close()

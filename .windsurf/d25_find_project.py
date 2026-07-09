#!/usr/bin/env python3
import sys, json, requests
sys.stdout.reconfigure(encoding='utf-8')

SUPABASE = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SKEY     = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H        = {"apikey": SKEY, "Authorization": f"Bearer {SKEY}", "Content-Type": "application/json"}

def sql(q):
    r = requests.post(f"{SUPABASE}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": q}, timeout=30)
    return r.json()

# Chercher dans TOUTES les tables du schema app
res = sql("SELECT tablename FROM pg_tables WHERE schemaname = 'app' ORDER BY tablename")
print("TABLES dans app:")
for row in res.get('rows', []):
    print(f"  {row.get('tablename')}")

# Whiteboard projects directement
res2 = sql("SELECT id, student_id, subject FROM app.whiteboard_projects ORDER BY created_at DESC LIMIT 5")
print(f"\nWHITEBOARD_PROJECTS rows: {len(res2.get('rows',[]))}")
for row in res2.get('rows', []):
    print(f"  {row}")

# whiteboard_renders
res3 = sql("SELECT id, project_id, status, video_url FROM app.whiteboard_renders ORDER BY created_at DESC LIMIT 5")
print(f"\nWHITEBOARD_RENDERS rows: {len(res3.get('rows',[]))}")
for row in res3.get('rows', []):
    pid = str(row.get('project_id',''))[:8]
    url = str(row.get('video_url',''))[:80]
    print(f"  render={str(row.get('id',''))[:8]}... project={pid}... status={row.get('status')} url={url}")

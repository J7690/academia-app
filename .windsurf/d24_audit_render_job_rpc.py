#!/usr/bin/env python3
"""D24 - Audit whiteboard_create_render_job : que retourne ce RPC ?"""
import requests, json, time
from datetime import datetime

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SKEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": SKEY, "Authorization": f"Bearer {SKEY}", "Content-Type": "application/json"}

def admin_sql(label, sql):
    r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H,
                      json={"p_sql": sql.strip().rstrip(";")}, timeout=30)
    print(f"\n=== {label} === HTTP:{r.status_code}")
    try:
        b = r.json()
        print(json.dumps(b, ensure_ascii=False)[:4000])
    except:
        print(r.text[:500])

print(f"D24 AUDIT whiteboard_create_render_job - {datetime.now().isoformat()}")

# 1. SQL complet de whiteboard_create_render_job
admin_sql("SQL whiteboard_create_render_job",
    "SELECT left(pg_get_functiondef(oid),5000) AS fulldef FROM pg_proc WHERE proname = 'whiteboard_create_render_job'")

# 2. Derniers render jobs créés
admin_sql("Derniers render jobs",
    "SELECT id, project_id, status, created_at FROM app.whiteboard_renders ORDER BY created_at DESC LIMIT 5")

# 3. Derniers projets créés (pour trouver ceux du test D24)
admin_sql("Derniers projets whiteboard (D24 test 10h26-10h36)",
    "SELECT id, student_id, subject, status, created_at FROM app.whiteboard_projects WHERE created_at > '2026-06-28 10:20:00' ORDER BY created_at DESC LIMIT 10")

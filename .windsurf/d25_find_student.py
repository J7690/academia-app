#!/usr/bin/env python3
import sys, json, requests
sys.stdout.reconfigure(encoding='utf-8')

SUPABASE = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SKEY     = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H        = {"apikey": SKEY, "Authorization": f"Bearer {SKEY}", "Content-Type": "application/json"}

def sql(q):
    r = requests.post(f"{SUPABASE}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": q}, timeout=30)
    return r.json()

# Trouver le student_id correct
print("=== student via whiteboard_renders (projects existants) ===")
res = sql("""
SELECT wp.id as project_id, wp.student_id, wp.subject, 
       jsonb_array_length(wp.storyboard_json->'scenes') as nb_scenes,
       wp.created_at
FROM app.whiteboard_projects wp
ORDER BY wp.created_at DESC
LIMIT 5
""")
for row in res.get('rows', []):
    print(f"  project={row.get('project_id')} student={row.get('student_id')} subject={row.get('subject')} scenes={row.get('nb_scenes')}")

print("\n=== Mapping student_id -> user_id ===")
res2 = sql("""
SELECT s.id as student_id, s.user_id, s.email
FROM app.students s
JOIN app.whiteboard_projects wp ON wp.student_id = s.id
ORDER BY wp.created_at DESC
LIMIT 3
""")
for row in res2.get('rows', []):
    print(f"  student_id={row.get('student_id')} user_id={row.get('user_id')} email={row.get('email')}")

# Dernier render job cree (pour verifier le project_id associe)
print("\n=== Dernier render job (avec project_id) ===")
res3 = sql("""
SELECT wr.id as render_id, wr.project_id, wr.status, wr.video_url,
       wp.student_id
FROM app.whiteboard_renders wr
JOIN app.whiteboard_projects wp ON wr.project_id = wp.id
ORDER BY wr.created_at DESC
LIMIT 5
""")
for row in res3.get('rows', []):
    print(f"  render={row.get('render_id')[:8]}... project={row.get('project_id')[:8]}... status={row.get('status')}")

# Utiliser directement le project_id du dernier render done
if res3.get('rows'):
    last = res3['rows'][0]
    print(f"\nDernier project_id disponible: {last.get('project_id')}")
    print(f"Student_id associe: {last.get('student_id')}")

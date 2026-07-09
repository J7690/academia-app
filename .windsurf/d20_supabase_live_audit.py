#!/usr/bin/env python3
"""D20 - Audit Supabase live: Edge Functions, RPCs, Buckets, Tables"""
import requests
import json

url = "https://thevdfcwlcqzdoybfvgs.supabase.co"
skey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
headers = {
    "apikey": skey,
    "Authorization": "Bearer " + skey,
    "Content-Type": "application/json",
}
admin_rpc = url + "/rest/v1/rpc/admin_execute_sql"

results = []

def sql_query(label, sql):
    results.append(f"\n=== {label} ===")
    r = requests.post(admin_rpc, headers=headers, json={"p_sql": sql}, timeout=30)
    results.append(f"STATUS: {r.status_code}")
    if r.status_code == 200:
        data = r.json()
        rows = data.get("data", [])
        results.append(f"Rows: {len(rows)}")
        for row in rows:
            results.append(f"  {row}")
    else:
        results.append(f"ERROR: {r.text[:400]}")

# 1. Edge Function whiteboard-generate-storyboard
results.append("\n=== EDGE FUNCTION whiteboard-generate-storyboard (sans JWT user) ===")
r = requests.post(
    url + "/functions/v1/whiteboard-generate-storyboard",
    headers=headers,
    json={"mode": "simple_subject", "subject": "test", "renderer": "scientific", "theme": "scientific", "narration_mode": "none"},
    timeout=20
)
results.append(f"STATUS: {r.status_code}")
results.append(f"BODY: {r.text[:400]}")

# 2. Storage buckets
results.append("\n=== STORAGE BUCKETS ===")
r2 = requests.get(url + "/storage/v1/bucket", headers=headers, timeout=15)
results.append(f"STATUS: {r2.status_code}")
try:
    buckets = r2.json()
    if isinstance(buckets, list):
        results.append(f"Nombre de buckets: {len(buckets)}")
        for b in buckets:
            results.append(f"  - name={b.get('name','?')} public={b.get('public','?')}")
    else:
        results.append(r2.text[:300])
except Exception as e:
    results.append(f"Parse error: {e}")
    results.append(r2.text[:300])

# 3. RPC whiteboard_create_project
results.append("\n=== RPC whiteboard_create_project ===")
r3 = requests.post(
    url + "/rest/v1/rpc/whiteboard_create_project",
    headers=headers,
    json={
        "p_student_id": "00000000-0000-0000-0000-000000000000",
        "p_subject": "test",
        "p_renderer_id": "scientific",
        "p_theme_id": "scientific",
        "p_narration_mode": "none",
        "p_storyboard_json": {}
    },
    timeout=15
)
results.append(f"STATUS: {r3.status_code}")
results.append(f"BODY: {r3.text[:400]}")

# 4. Tables whiteboard via pg_proc
sql_query("FONCTIONS WHITEBOARD (pg_proc)", """
SELECT n.nspname, p.proname, pg_get_function_identity_arguments(p.oid) as sig
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE p.proname ILIKE '%whiteboard%'
ORDER BY n.nspname, p.proname
""")

# 5. Tables app schema
sql_query("TABLES SCHEMA APP", """
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_schema = 'app'
ORDER BY table_name
""")

# 6. Tables whiteboard all schemas
sql_query("TABLES WHITEBOARD ALL SCHEMAS", """
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_name ILIKE '%whiteboard%' OR table_name ILIKE '%render%'
ORDER BY table_schema, table_name
""")

# 7. RPC whiteboard_fetch_queued_jobs (worker RPC)
results.append("\n=== RPC whiteboard_fetch_queued_jobs ===")
r4 = requests.post(
    url + "/rest/v1/rpc/whiteboard_fetch_queued_jobs",
    headers=headers,
    json={"p_limit": 5},
    timeout=15
)
results.append(f"STATUS: {r4.status_code}")
results.append(f"BODY: {r4.text[:400]}")

output = "\n".join(results)
print(output)
outfile = "c:\\Users\\fasop\\AndroidStudioProjects\\academia\\.windsurf\\d20_supabase_live_audit_output.txt"
with open(outfile, "w", encoding="utf-8") as f:
    f.write(output)
print(f"\nSaved to: {outfile}")

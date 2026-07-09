"""
Phase C.3E – Pre-Change Snapshot
Snapshot complet avant modification LOT 1
"""

import requests

admin_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

def execute_sql(sql):
    resp = requests.post(admin_url, headers=headers, json={"p_sql": sql}, timeout=30)
    return resp.json()

print("=== PRE-CHANGE SNAPSHOT ===\n")

# 1. Snapshot app.whiteboard_projects
print("1. SNAPSHOT app.whiteboard_projects")
sql_projects = """
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'app' AND table_name = 'whiteboard_projects'
ORDER BY ordinal_position;
"""
resp = requests.post(admin_url, headers=headers, json={"p_sql": sql_projects}, timeout=30)
print(f"   Colonnes : {resp.json()}")

sql_projects_constraints = """
SELECT conname, contype, pg_get_constraintdef(oid)
FROM pg_constraint
WHERE conrelid = 'app.whiteboard_projects'::regclass
ORDER BY conname;
"""
resp = requests.post(admin_url, headers=headers, json={"p_sql": sql_projects_constraints}, timeout=30)
print(f"   Contraintes : {resp.json()}")
print()

# 2. Snapshot app.whiteboard_renders
print("2. SNAPSHOT app.whiteboard_renders")
sql_renders = """
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'app' AND table_name = 'whiteboard_renders'
ORDER BY ordinal_position;
"""
resp = requests.post(admin_url, headers=headers, json={"p_sql": sql_renders}, timeout=30)
print(f"   Colonnes : {resp.json()}")

sql_renders_constraints = """
SELECT conname, contype, pg_get_constraintdef(oid)
FROM pg_constraint
WHERE conrelid = 'app.whiteboard_renders'::regclass
ORDER BY conname;
"""
resp = requests.post(admin_url, headers=headers, json={"p_sql": sql_renders_constraints}, timeout=30)
print(f"   Contraintes : {resp.json()}")

sql_renders_count = "SELECT COUNT(*) as total FROM app.whiteboard_renders"
resp = requests.post(admin_url, headers=headers, json={"p_sql": sql_renders_count}, timeout=30)
print(f"   Total rows : {resp.json()}")
print()

# 3. Snapshot RPC whiteboard*
print("3. SNAPSHOT RPC whiteboard*")
sql_rpcs = """
SELECT routine_name, routine_schema
FROM information_schema.routines
WHERE routine_schema IN ('app', 'public')
AND routine_name LIKE '%whiteboard%'
ORDER BY routine_schema, routine_name;
"""
resp = requests.post(admin_url, headers=headers, json={"p_sql": sql_rpcs}, timeout=30)
print(f"   RPCs : {resp.json()}")
print()

print("=== SNAPSHOT TERMINÉ ===\n")

"""
Phase C.3E – Post-Execution Audit
Audit complet après LOT 1
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

print("=== POST-EXECUTION AUDIT ===\n")

# 1. Audit app.whiteboard_renders colonnes
print("1. AUDIT app.whiteboard_renders colonnes")
sql_renders = """
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'app' AND table_name = 'whiteboard_renders'
ORDER BY ordinal_position;
"""
resp = requests.post(admin_url, headers=headers, json={"p_sql": sql_renders}, timeout=30)
print(f"   Colonnes : {resp.json()}")
print()

# 2. Audit app.whiteboard_renders contraintes
print("2. AUDIT app.whiteboard_renders contraintes")
sql_renders_constraints = """
SELECT conname, contype, pg_get_constraintdef(oid)
FROM pg_constraint
WHERE conrelid = 'app.whiteboard_renders'::regclass
ORDER BY conname;
"""
resp = requests.post(admin_url, headers=headers, json={"p_sql": sql_renders_constraints}, timeout=30)
print(f"   Contraintes : {resp.json()}")
print()

# 3. Vérifier colonnes spécifiques
print("3. VÉRIFICATION COLONNES SPÉCIFIQUES")

# export_settings
sql_export = """
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'app' AND table_name = 'whiteboard_renders' AND column_name = 'export_settings';
"""
resp = requests.post(admin_url, headers=headers, json={"p_sql": sql_export}, timeout=30)
print(f"   export_settings : {resp.json()}")

# started_at
sql_started = """
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'app' AND table_name = 'whiteboard_renders' AND column_name = 'started_at';
"""
resp = requests.post(admin_url, headers=headers, json={"p_sql": sql_started}, timeout=30)
print(f"   started_at : {resp.json()}")
print()

# 4. Vérifier contrainte CHECK status
print("4. VÉRIFICATION CHECK STATUS")
sql_check = """
SELECT conname, pg_get_constraintdef(oid)
FROM pg_constraint
WHERE conrelid = 'app.whiteboard_renders'::regclass AND conname = 'whiteboard_renders_status_check';
"""
resp = requests.post(admin_url, headers=headers, json={"p_sql": sql_check}, timeout=30)
print(f"   CHECK status : {resp.json()}")
print()

print("=== AUDIT TERMINÉ ===\n")

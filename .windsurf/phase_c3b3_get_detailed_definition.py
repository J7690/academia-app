"""
Phase C.3B.3 – Get Detailed Definition
Récupère la définition détaillée de app.whiteboard_renders
"""

import requests

admin_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=== GET DETAILED DEFINITION ===\n")

# 1. Colonnes avec tous les détails
print("1. COLONNES (détails complets)")
sql_columns = """
SELECT 
    column_name,
    data_type,
    character_maximum_length,
    is_nullable,
    column_default,
    ordinal_position
FROM information_schema.columns
WHERE table_schema = 'app' AND table_name = 'whiteboard_renders'
ORDER BY ordinal_position;
"""
resp = requests.post(admin_url, headers=headers, json={"p_sql": sql_columns}, timeout=30)
print(f"   Status : {resp.status_code}")
print(f"   Résultat : {resp.json()}")
print()

# 2. Contraintes CHECK avec définition
print("2. CONTRAINTES CHECK (avec définition)")
sql_check = """
SELECT 
    conname,
    pg_get_constraintdef(oid) as constraint_def
FROM pg_constraint
WHERE conrelid = 'app.whiteboard_renders'::regclass
AND contype = 'c'
ORDER BY conname;
"""
resp = requests.post(admin_url, headers=headers, json={"p_sql": sql_check}, timeout=30)
print(f"   Status : {resp.status_code}")
print(f"   Résultat : {resp.json()}")
print()

# 3. Contraintes FK
print("3. CONTRAINTES FK")
sql_fk = """
SELECT 
    conname,
    pg_get_constraintdef(oid) as constraint_def
FROM pg_constraint
WHERE conrelid = 'app.whiteboard_renders'::regclass
AND contype = 'f'
ORDER BY conname;
"""
resp = requests.post(admin_url, headers=headers, json={"p_sql": sql_fk}, timeout=30)
print(f"   Status : {resp.status_code}")
print(f"   Résultat : {resp.json()}")
print()

# 4. Triggers
print("4. TRIGGERS")
sql_triggers = """
SELECT 
    trigger_name,
    event_manipulation,
    event_object_table,
    action_timing,
    action_condition,
    action_statement
FROM information_schema.triggers
WHERE trigger_schema = 'app' AND event_object_table = 'whiteboard_renders'
ORDER BY trigger_name;
"""
resp = requests.post(admin_url, headers=headers, json={"p_sql": sql_triggers}, timeout=30)
print(f"   Status : {resp.status_code}")
print(f"   Résultat : {resp.json()}")
print()

# 5. RLS Policies
print("5. RLS POLICIES")
sql_policies = """
SELECT 
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE schemaname = 'app' AND tablename = 'whiteboard_renders'
ORDER BY policyname;
"""
resp = requests.post(admin_url, headers=headers, json={"p_sql": sql_policies}, timeout=30)
print(f"   Status : {resp.status_code}")
print(f"   Résultat : {resp.json()}")

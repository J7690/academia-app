"""
Script pour Phase B.5 – Vérification des tables whiteboard
"""

import requests

# Configuration
url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

def execute_sql(sql):
    resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
    return resp.json()

print("=== VÉRIFICATION TABLES WHITEBOARD ===\n")

# Vérifier table whiteboard_projects
sql = """
SELECT 
    column_name, 
    data_type, 
    is_nullable, 
    column_default
FROM information_schema.columns 
WHERE table_schema = 'app' 
  AND table_name = 'whiteboard_projects' 
ORDER BY ordinal_position
"""
result = execute_sql(sql)
print("Table whiteboard_projects:")
if result.get("ok") and result.get("rows"):
    for row in result["rows"]:
        print(f"  {row['column_name']}: {row['data_type']} (nullable: {row['is_nullable']})")
else:
    print("❌ Table whiteboard_projects non trouvée")

# Vérifier table whiteboard_renders
sql = """
SELECT 
    column_name, 
    data_type, 
    is_nullable, 
    column_default
FROM information_schema.columns 
WHERE table_schema = 'app' 
  AND table_name = 'whiteboard_renders' 
ORDER BY ordinal_position
"""
result = execute_sql(sql)
print("\nTable whiteboard_renders:")
if result.get("ok") and result.get("rows"):
    for row in result["rows"]:
        print(f"  {row['column_name']}: {row['data_type']} (nullable: {row['is_nullable']})")
else:
    print("❌ Table whiteboard_renders non trouvée")

# Vérifier RLS policies
sql = """
SELECT 
    schemaname, 
    tablename, 
    policyname, 
    permissive, 
    roles, 
    cmd, 
    qual
FROM pg_policies 
WHERE schemaname = 'app' 
  AND tablename IN ('whiteboard_projects', 'whiteboard_renders')
ORDER BY tablename, policyname
"""
result = execute_sql(sql)
print("\nRLS Policies:")
if result.get("ok") and result.get("rows"):
    for row in result["rows"]:
        print(f"  {row['tablename']}.{row['policyname']}")
        print(f"    Roles: {row['roles']}")
        print(f"    Command: {row['cmd']}")
else:
    print("❌ Aucune RLS policy trouvée")

print("\n=== VÉRIFICATION TERMINÉE ===\n")

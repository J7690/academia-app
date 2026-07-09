"""
Script pour Phase B.5 – Non-régression Validation
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

print("=== VALIDATION NON-RÉGRESSION ===\n")

# Vérifier tables existantes (Challenge, Bobodo)
print("Tables existantes (Challenge, Bobodo):")
sql = "SELECT table_name FROM information_schema.tables WHERE table_schema = 'app' AND table_name LIKE 'challenge_%' OR table_name LIKE 'bobodo_%' ORDER BY table_name"
result = execute_sql(sql)
if result.get("ok") and result.get("rows"):
    for row in result["rows"]:
        print(f"  {row['table_name']}")
else:
    print("❌ Erreur récupération tables")

# Vérifier RPCs existantes
print("\nRPCs existantes (Challenge, Bobodo):")
sql = "SELECT routine_name FROM information_schema.routines WHERE routine_schema = 'app' AND (routine_name LIKE 'challenge_%' OR routine_name LIKE 'bobodo_%') ORDER BY routine_name"
result = execute_sql(sql)
if result.get("ok") and result.get("rows"):
    for row in result["rows"]:
        print(f"  {row['routine_name']}")
else:
    print("❌ Erreur récupération RPCs")

# Vérifier tables whiteboard créées
print("\nTables whiteboard créées:")
sql = "SELECT table_name FROM information_schema.tables WHERE table_schema = 'app' AND table_name LIKE 'whiteboard_%' ORDER BY table_name"
result = execute_sql(sql)
if result.get("ok") and result.get("rows"):
    for row in result["rows"]:
        print(f"  {row['table_name']}")
else:
    print("❌ Erreur récupération tables whiteboard")

# Vérifier RPCs whiteboard créées
print("\nRPCs whiteboard créées:")
sql = "SELECT routine_name FROM information_schema.routines WHERE routine_schema = 'public' AND routine_name LIKE 'whiteboard_%' ORDER BY routine_name"
result = execute_sql(sql)
if result.get("ok") and result.get("rows"):
    for row in result["rows"]:
        print(f"  {row['routine_name']}")
else:
    print("❌ Erreur récupération RPCs whiteboard")

# Vérifier RLS policies existantes
print("\nRLS policies existantes (Challenge, Bobodo):")
sql = """
SELECT 
    schemaname, 
    tablename, 
    policyname 
FROM pg_policies 
WHERE schemaname = 'app' 
  AND (tablename LIKE 'challenge_%' OR tablename LIKE 'bobodo_%')
ORDER BY tablename, policyname
"""
result = execute_sql(sql)
if result.get("ok") and result.get("rows"):
    for row in result["rows"]:
        print(f"  {row['tablename']}.{row['policyname']}")
else:
    print("❌ Erreur récupération RLS policies")

print("\n=== VALIDATION NON-RÉGRESSION TERMINÉE ===\n")

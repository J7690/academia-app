import requests
import json

admin_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json",
}

print("=" * 80)
print("TEST DE admin_execute_sql")
print("=" * 80)

# Test 1: Vérifier si admin_execute_sql existe
print("\nTest 1: Vérifier si admin_execute_sql existe dans pg_proc...")
sql1 = """
SELECT
    proname,
    pg_get_function_identity_arguments(oid) as signature
FROM pg_proc
WHERE proname = 'admin_execute_sql';
"""

resp1 = requests.post(admin_url, headers=headers, json={"p_sql": sql1}, timeout=30)
print(f"STATUS: {resp1.status_code}")
print(f"RESPONSE: {resp1.text}")

# Test 2: Requête simple - compter toutes les fonctions
print("\nTest 2: Compter toutes les fonctions dans pg_proc...")
sql2 = "SELECT COUNT(*) FROM pg_proc;"

resp2 = requests.post(admin_url, headers=headers, json={"p_sql": sql2}, timeout=30)
print(f"STATUS: {resp2.status_code}")
print(f"RESPONSE: {resp2.text}")

# Test 3: Lister tous les schémas
print("\nTest 3: Lister tous les schémas...")
sql3 = """
SELECT schema_name
FROM information_schema.schemata
WHERE schema_name NOT IN ('pg_catalog', 'information_schema')
ORDER BY schema_name;
"""

resp3 = requests.post(admin_url, headers=headers, json={"p_sql": sql3}, timeout=30)
print(f"STATUS: {resp3.status_code}")
print(f"RESPONSE: {resp3.text}")

# Test 4: Vérifier pg_namespace directement
print("\nTest 4: Vérifier pg_namespace...")
sql4 = """
SELECT nspname, oid
FROM pg_namespace
WHERE nspname NOT LIKE 'pg_%'
AND nspname != 'information_schema'
ORDER BY nspname;
"""

resp4 = requests.post(admin_url, headers=headers, json={"p_sql": sql4}, timeout=30)
print(f"STATUS: {resp4.status_code}")
print(f"RESPONSE: {resp4.text}")

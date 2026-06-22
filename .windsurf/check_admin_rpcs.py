import requests

url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=" * 80)
print("VÉRIFICATION DES RPC ADMINISTRATEURS")
print("=" * 80)

# Lister tous les RPC admin
sql = """
SELECT proname, pg_get_function_identity_arguments(oid) as args
FROM pg_proc 
WHERE proname LIKE 'admin%' 
ORDER BY proname
"""
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
print("\nRPC admin disponibles:")
print("STATUS:", resp.status_code)
print("BODY:", resp.text[:1000])

# Chercher des RPC qui pourraient exécuter des fonctions
sql2 = """
SELECT proname, pg_get_function_identity_arguments(oid) as args
FROM pg_proc 
WHERE proname LIKE '%execute%' OR proname LIKE '%run%' OR proname LIKE '%function%'
ORDER BY proname
"""
resp2 = requests.post(url, headers=headers, json={"p_sql": sql2}, timeout=30)
print("\nRPC liés à l'exécution:")
print("STATUS:", resp2.status_code)
print("BODY:", resp2.text[:1000])

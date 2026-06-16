import requests

url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

# 1. Vérifier si le RPC existe
sql1 = "SELECT proname FROM pg_proc WHERE proname = 'app_append_bobodo_message';"
resp1 = requests.post(url, headers=headers, json={"p_sql": sql1}, timeout=30)
print("RPC EXISTS STATUS:", resp1.status_code)
print("RPC EXISTS BODY:", resp1.text[:500])

# 2. Vérifier la signature du RPC
sql2 = """SELECT pg_get_function_identity_arguments(oid) as args FROM pg_proc WHERE proname = 'app_append_bobodo_message';"""
resp2 = requests.post(url, headers=headers, json={"p_sql": sql2}, timeout=30)
print("\nRPC ARGS STATUS:", resp2.status_code)
print("RPC ARGS BODY:", resp2.text[:500])

# 3. Vérifier si les tables bobodo existent
sql3 = "SELECT tablename FROM pg_tables WHERE schemaname = 'app' AND tablename LIKE 'bobodo%';"
resp3 = requests.post(url, headers=headers, json={"p_sql": sql3}, timeout=30)
print("\nTABLES STATUS:", resp3.status_code)
print("TABLES BODY:", resp3.text[:500])

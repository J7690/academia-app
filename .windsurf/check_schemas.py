import requests

url = "https://thevdfcwlcqzdoybfvgs.supabase.co"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json",
}

print("Vérification des schémas...")

sql = """
SELECT schema_name
FROM information_schema.schemata
WHERE schema_name NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
ORDER BY schema_name;
"""

rpc_url = f"{url}/rest/v1/rpc/admin_execute_sql"
resp = requests.post(rpc_url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"STATUS: {resp.status_code}")
if resp.status_code == 200:
    data = resp.json()
    schemas = data.get('data', [])
    print(f"Schémas trouvés: {len(schemas)}")
    for schema in schemas:
        print(f"  {schema[0]}")
else:
    print(f"Error: {resp.text}")

import requests

admin_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json",
}

print("Finding user-related tables...")

sql = """
SELECT table_schema, table_name 
FROM information_schema.tables 
WHERE table_name LIKE '%user%' OR table_name LIKE '%student%' OR table_name LIKE '%profile%'
ORDER BY table_schema, table_name;
"""

resp = requests.post(admin_url, headers=headers, json={"p_sql": sql}, timeout=30)
print("STATUS:", resp.status_code)

if resp.status_code == 200:
    data = resp.json()
    tables = data.get('data', [])
    print(f"Found {len(tables)} user-related tables:")
    for table in tables:
        print(f"  - {table['table_schema']}.{table['table_name']}")
else:
    print("Error:", resp.text)

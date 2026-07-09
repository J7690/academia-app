import requests

admin_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json",
}

print("Checking if app.whiteboard_projects exists...")

sql = """
SELECT 
  schemaname,
  tablename 
FROM pg_tables 
WHERE schemaname = 'app' 
AND tablename = 'whiteboard_projects';
"""

resp = requests.post(admin_url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"STATUS: {resp.status_code}")

if resp.status_code == 200:
    data = resp.json()
    tables = data.get('data', [])
    print(f"Found {len(tables)} tables:")
    for table in tables:
        print(f"  {table[0]}.{table[1]}")
else:
    print(f"Error: {resp.text}")

# Check all tables in app schema
print("\nAll tables in app schema:")
sql2 = """
SELECT tablename 
FROM pg_tables 
WHERE schemaname = 'app' 
ORDER BY tablename;
"""

resp2 = requests.post(admin_url, headers=headers, json={"p_sql": sql2}, timeout=30)
print(f"STATUS: {resp2.status_code}")

if resp2.status_code == 200:
    data2 = resp2.json()
    tables2 = data2.get('data', [])
    print(f"Found {len(tables2)} tables:")
    for table in tables2:
        print(f"  {table[0]}")
else:
    print(f"Error: {resp2.text}")

import requests

admin_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json",
}

print("Getting table definition via direct SELECT...")

sql = """
SELECT * FROM app.whiteboard_projects LIMIT 0;
"""

resp = requests.post(admin_url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"STATUS: {resp.status_code}")
print(f"RESPONSE: {resp.text}")

# Try to get column info via pg_attribute
print("\nGetting columns via pg_attribute...")
sql2 = """
SELECT 
  a.attname as column_name,
  t.typname as data_type,
  a.attnotnull as not_null,
  a.atthasdef as has_default
FROM pg_attribute a
JOIN pg_type t ON a.atttypid = t.oid
WHERE a.attrelid = 'app.whiteboard_projects'::regclass
AND a.attnum > 0
AND NOT a.attisdropped
ORDER BY a.attnum;
"""

resp2 = requests.post(admin_url, headers=headers, json={"p_sql": sql2}, timeout=30)
print(f"STATUS: {resp2.status_code}")

if resp2.status_code == 200:
    data2 = resp2.json()
    columns = data2.get('data', [])
    print(f"Found {len(columns)} columns:")
    for col in columns:
        print(f"  {col[0]}: {col[1]} (not_null: {col[2]}, has_default: {col[3]})")
else:
    print(f"Error: {resp2.text}")

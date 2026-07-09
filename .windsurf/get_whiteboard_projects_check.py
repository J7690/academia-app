import requests

admin_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json",
}

print("=" * 80)
print("DÉFINITION TABLE app.whiteboard_projects")
print("=" * 80)

sql = """
SELECT 
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema = 'app' 
AND table_name = 'whiteboard_projects'
ORDER BY ordinal_position;
"""

resp = requests.post(admin_url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"\nSTATUS: {resp.status_code}")

if resp.status_code == 200:
    data = resp.json()
    columns = data.get('data', [])
    print(f"Found {len(columns)} columns:")
    for col in columns:
        print(f"  {col[0]}: {col[1]} (nullable: {col[2]}, default: {col[3]})")
else:
    print(f"Error: {resp.text}")

print("\n" + "=" * 80)
print("CONTRAINTES CHECK")
print("=" * 80)

sql2 = """
SELECT 
  conname as constraint_name,
  pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint
WHERE conrelid = 'app.whiteboard_projects'::regclass
AND contype = 'c'
ORDER BY conname;
"""

resp2 = requests.post(admin_url, headers=headers, json={"p_sql": sql2}, timeout=30)
print(f"\nSTATUS: {resp2.status_code}")

if resp2.status_code == 200:
    data2 = resp2.json()
    constraints = data2.get('data', [])
    print(f"Found {len(constraints)} CHECK constraints:")
    for constraint in constraints:
        print(f"\n  {constraint[0]}:")
        print(f"    {constraint[1]}")
else:
    print(f"Error: {resp2.text}")

print("\n" + "=" * 80)
print("CRÉATION TABLE COMPLÈTE")
print("=" * 80)

sql3 = """
SELECT pg_get_tabledef('app.whiteboard_projects'::regclass);
"""

resp3 = requests.post(admin_url, headers=headers, json={"p_sql": sql3}, timeout=30)
print(f"\nSTATUS: {resp3.status_code}")

if resp3.status_code == 200:
    data3 = resp3.json()
    tabledef = data3.get('data', [])
    if tabledef:
        print(f"Table definition:\n{tabledef[0][0]}")
else:
    print(f"Error: {resp3.text}")

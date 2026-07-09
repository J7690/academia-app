import requests

admin_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json",
}

print("=" * 80)
print("AUDIT DES RPCS WHITEBOARD")
print("=" * 80)

# Lister toutes les RPCs whiteboard
sql = """
SELECT 
  routine_name,
  routine_schema
FROM information_schema.routines
WHERE routine_name LIKE '%whiteboard%'
ORDER BY routine_schema, routine_name;
"""

resp = requests.post(admin_url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"\nSTATUS: {resp.status_code}")

if resp.status_code == 200:
    data = resp.json()
    rpcs = data.get('data', [])
    print(f"Found {len(rpcs)} whiteboard RPCs:")
    for rpc in rpcs:
        print(f"  {rpc[0]} (schema: {rpc[1]})")
else:
    print(f"Error: {resp.text}")

# Vérifier spécifiquement whiteboard_create_project
print("\n" + "=" * 80)
print("VÉRIFICATION whiteboard_create_project")
print("=" * 80)

sql2 = """
SELECT 
  routine_name,
  routine_schema,
  routine_type
FROM information_schema.routines
WHERE routine_name = 'whiteboard_create_project';
"""

resp2 = requests.post(admin_url, headers=headers, json={"p_sql": sql2}, timeout=30)
print(f"\nSTATUS: {resp2.status_code}")

if resp2.status_code == 200:
    data2 = resp2.json()
    rpcs2 = data2.get('data', [])
    print(f"Found {len(rpcs2)} RPCs:")
    for rpc in rpcs2:
        print(f"  {rpc[0]} (schema: {rpc[1]}, type: {rpc[2]})")
else:
    print(f"Error: {resp2.text}")

# Vérifier whiteboard_create_project
print("\n" + "=" * 80)
print("VÉRIFICATION whiteboard_create_project")
print("=" * 80)

sql3 = """
SELECT 
  routine_name,
  routine_schema,
  routine_type
FROM information_schema.routines
WHERE routine_name = 'whiteboard_create_project';
"""

resp3 = requests.post(admin_url, headers=headers, json={"p_sql": sql3}, timeout=30)
print(f"\nSTATUS: {resp3.status_code}")

if resp3.status_code == 200:
    data3 = resp3.json()
    rpcs3 = data3.get('data', [])
    print(f"Found {len(rpcs3)} RPCs:")
    for rpc in rpcs3:
        print(f"  {rpc[0]} (schema: {rpc[1]}, type: {rpc[2]})")
else:
    print(f"Error: {resp3.text}")

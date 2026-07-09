import requests

url = "https://thevdfcwlcqzdoybfvgs.supabase.co"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json",
}

print("=" * 80)
print("VÉRIFICATION LOT 1 - PHASE D.5")
print("=" * 80)

# 1. Vérifier les tables
print("\n1. Vérification des tables whiteboard...")
sql = """
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'app'
AND table_name LIKE 'whiteboard%'
ORDER BY table_name;
"""

rpc_url = f"{url}/rest/v1/rpc/admin_execute_sql"
resp = requests.post(rpc_url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"STATUS: {resp.status_code}")
if resp.status_code == 200:
    data = resp.json()
    tables = data.get('data', [])
    print(f"Tables trouvées: {len(tables)}")
    for table in tables:
        print(f"  - {table[0]}")
else:
    print(f"Error: {resp.text}")

# 2. Vérifier les colonnes de whiteboard_projects
print("\n2. Colonnes de whiteboard_projects...")
sql = """
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'app'
AND table_name = 'whiteboard_projects'
ORDER BY ordinal_position;
"""

resp = requests.post(rpc_url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"STATUS: {resp.status_code}")
if resp.status_code == 200:
    data = resp.json()
    columns = data.get('data', [])
    print(f"Colonnes trouvées: {len(columns)}")
    for col in columns:
        print(f"  - {col[0]}: {col[1]} (nullable: {col[2]})")
else:
    print(f"Error: {resp.text}")

# 3. Vérifier les RPCs
print("\n3. Vérification des RPCs whiteboard...")
sql = """
SELECT routine_name
FROM information_schema.routines
WHERE routine_schema IN ('app', 'public')
AND routine_name LIKE '%whiteboard%'
ORDER BY routine_schema, routine_name;
"""

resp = requests.post(rpc_url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"STATUS: {resp.status_code}")
if resp.status_code == 200:
    data = resp.json()
    rpcs = data.get('data', [])
    print(f"RPCs trouvées: {len(rpcs)}")
    for rpc in rpcs:
        print(f"  - {rpc[0]}")
else:
    print(f"Error: {resp.text}")

print("\n" + "=" * 80)
print("VÉRIFICATION TERMINÉE")
print("=" * 80)

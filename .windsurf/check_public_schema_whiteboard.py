import requests

url = "https://thevdfcwlcqzdoybfvgs.supabase.co"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json",
}

print("=" * 80)
print("VÉRIFICATION SCHÉMA PUBLIC - WHITEBOARD")
print("=" * 80)

# Chercher les tables whiteboard dans le schéma public
print("\nRecherche des tables whiteboard dans le schéma public...")
sql = """
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
AND table_name LIKE '%whiteboard%'
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

# Si tables trouvées, vérifier les colonnes
if tables:
    print("\nColonnes de whiteboard_projects...")
    sql = """
    SELECT column_name, data_type, is_nullable
    FROM information_schema.columns
    WHERE table_schema = 'public'
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

print("\n" + "=" * 80)

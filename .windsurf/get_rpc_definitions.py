import requests

admin_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json",
}

print("=" * 80)
print("RÉCUPÉRATION DES DÉFINITIONS RPC")
print("=" * 80)

# Récupérer toutes les fonctions whiteboard
sql = """
SELECT 
  routine_schema,
  routine_name,
  routine_type,
  data_type,
  external_language
FROM information_schema.routines
WHERE routine_name LIKE '%whiteboard%' OR routine_name LIKE '%create_project%'
ORDER BY routine_schema, routine_name;
"""

resp = requests.post(admin_url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"\nSTATUS: {resp.status_code}")

if resp.status_code == 200:
    data = resp.json()
    routines = data.get('data', [])
    print(f"Found {len(routines)} routines:")
    for routine in routines:
        print(f"\n  Schema: {routine[0]}")
        print(f"  Name: {routine[1]}")
        print(f"  Type: {routine[2]}")
        print(f"  Return type: {routine[3]}")
        print(f"  Language: {routine[4]}")
else:
    print(f"Error: {resp.text}")

# Récupérer les définitions complètes via pg_proc
print("\n" + "=" * 80)
print("DÉFINITIONS COMPLÈTES VIA pg_proc")
print("=" * 80)

sql2 = """
SELECT 
  n.nspname as schema_name,
  p.proname as function_name,
  pg_get_functiondef(p.oid) as definition
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname LIKE '%whiteboard%' OR p.proname LIKE '%create_project%'
ORDER BY n.nspname, p.proname;
"""

resp2 = requests.post(admin_url, headers=headers, json={"p_sql": sql2}, timeout=30)
print(f"\nSTATUS: {resp2.status_code}")

if resp2.status_code == 200:
    data2 = resp2.json()
    definitions = data2.get('data', [])
    print(f"Found {len(definitions)} definitions:")
    for defn in definitions:
        print(f"\n  Schema: {defn[0]}")
        print(f"  Function: {defn[1]}")
        print(f"  Definition:\n{defn[2]}")
else:
    print(f"Error: {resp2.text}")

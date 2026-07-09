import requests
import json

admin_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json",
}

print("=" * 80)
print("VÉRIFICATION DANS pg_namespace")
print("=" * 80)

# Vérifier dans pg_namespace
sql = """
SELECT nspname, oid
FROM pg_namespace
WHERE nspname = 'app';
"""

print("\nSQL exécuté :")
print(sql)

resp = requests.post(admin_url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"\nSTATUS: {resp.status_code}")

if resp.status_code == 200:
    data = resp.json()
    namespaces = data.get('data', [])
    print(f"\nSchéma 'app' dans pg_namespace : {len(namespaces) > 0}")
    if namespaces:
        print(f"  nspname: {namespaces[0][0]}")
        print(f"  oid: {namespaces[0][1]}")
else:
    print(f"Error: {resp.text}")

# Lister tous les namespaces
print("\n" + "=" * 80)
print("TOUS LES NAMESPACES")
print("=" * 80)

sql2 = """
SELECT nspname, oid
FROM pg_namespace
WHERE nspname NOT LIKE 'pg_%'
AND nspname != 'information_schema'
ORDER BY nspname;
"""

print("\nSQL exécuté :")
print(sql2)

resp2 = requests.post(admin_url, headers=headers, json={"p_sql": sql2}, timeout=30)
print(f"\nSTATUS: {resp2.status_code}")

if resp2.status_code == 200:
    data2 = resp2.json()
    namespaces = data2.get('data', [])
    print(f"\nNombre de namespaces trouvés : {len(namespaces)}")
    print("\n" + "=" * 80)
    print("NAMESPACES :")
    print("=" * 80)
    for ns in namespaces:
        print(f"  {ns[0]} (oid: {ns[1]})")
else:
    print(f"Error: {resp2.text}")

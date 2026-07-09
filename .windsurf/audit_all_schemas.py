import requests
import json

admin_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json",
}

print("=" * 80)
print("AUDIT DE TOUS LES SCHÉMAS")
print("=" * 80)

# Lister tous les schémas
sql1 = """
SELECT schema_name
FROM information_schema.schemata
WHERE schema_name NOT IN ('pg_catalog', 'information_schema')
ORDER BY schema_name;
"""

print("\nSQL exécuté (schémas) :")
print(sql1)

resp1 = requests.post(admin_url, headers=headers, json={"p_sql": sql1}, timeout=30)
print(f"\nSTATUS: {resp1.status_code}")

if resp1.status_code == 200:
    data1 = resp1.json()
    schemas = data1.get('data', [])
    print(f"\nNombre de schémas trouvés : {len(schemas)}")
    print("\n" + "=" * 80)
    print("SCHÉMAS TROUVÉS :")
    print("=" * 80)
    for schema in schemas:
        print(f"  {schema[0]}")
else:
    print(f"Error: {resp1.text}")

# Maintenant chercher toutes les fonctions dans tous les schémas
print("\n" + "=" * 80)
print("RECHERCHE DE TOUTES LES FONCTIONS")
print("=" * 80)

sql2 = """
SELECT
    oid,
    proname,
    pg_get_function_identity_arguments(oid) as signature,
    pronamespace::regnamespace as schema
FROM pg_proc
WHERE pronamespace::regnamespace NOT IN ('pg_catalog', 'information_schema')
ORDER BY schema, proname, oid;
"""

print("\nSQL exécuté (fonctions) :")
print(sql2)

resp2 = requests.post(admin_url, headers=headers, json={"p_sql": sql2}, timeout=30)
print(f"\nSTATUS: {resp2.status_code}")

if resp2.status_code == 200:
    data2 = resp2.json()
    functions = data2.get('data', [])
    print(f"\nNombre de fonctions trouvées : {len(functions)}")
    print("\n" + "=" * 80)
    print("FONCTIONS TROUVÉES :")
    print("=" * 80)
    for i, func in enumerate(functions, 1):
        print(f"\nFONCTION {i}:")
        print(f"  OID: {func[0]}")
        print(f"  NOM: {func[1]}")
        print(f"  SCHÉMA: {func[3]}")
        print(f"  SIGNATURE: {func[2]}")
else:
    print(f"Error: {resp2.text}")

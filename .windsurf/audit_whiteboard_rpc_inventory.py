import requests
import json

admin_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json",
}

def execute_sql(sql):
    resp = requests.post(admin_url, headers=headers, json={"p_sql": sql}, timeout=30)
    return resp.json()

print("=" * 80)
print("INVENTAIRE COMPLET DES RPC WHITEBOARD")
print("=" * 80)

# Interroger toutes les fonctions whiteboard dans tous les schémas
sql = """
SELECT
    oid,
    proname,
    pg_get_function_identity_arguments(oid) as signature,
    pg_get_functiondef(oid) as full_definition,
    pronamespace::regnamespace as schema
FROM pg_proc
WHERE proname LIKE '%whiteboard%'
ORDER BY schema, proname, oid;
"""

print("\nSQL exécuté :")
print(sql)

resp = execute_sql(sql)
print(f"\nSTATUS: OK")

functions = resp.get('data', [])
print(f"\nNombre total de fonctions whiteboard trouvées : {len(functions)}")
print("\n" + "=" * 80)
print("INVENTAIRE DÉTAILLÉ :")
print("=" * 80)

for i, func in enumerate(functions, 1):
    print(f"\n--- FONCTION {i} ---")
    print(f"OID: {func[0]}")
    print(f"NOM: {func[1]}")
    print(f"SCHÉMA: {func[4]}")
    print(f"SIGNATURE: {func[2]}")
    print(f"DÉFINITION: {func[3]}")

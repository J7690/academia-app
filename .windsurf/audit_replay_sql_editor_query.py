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
print("REJOUER EXACTEMENT LA REQUÊTE DU SQL EDITOR")
print("=" * 80)

# Requête exacte du SQL Editor
sql = """
SELECT
    n.nspname AS schema_name,
    p.proname AS function_name,
    pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n
ON n.oid = p.pronamespace
WHERE p.proname ILIKE '%whiteboard%'
ORDER BY
    n.nspname,
    p.proname;
"""

print("\nSQL exécuté :")
print(sql)

resp = execute_sql(sql)
print(f"\nSTATUS: OK")

functions = resp.get('data', [])
print(f"\nNombre total de fonctions whiteboard trouvées : {len(functions)}")
print("\n" + "=" * 80)
print("LISTE COMPLÈTE :")
print("=" * 80)

for i, func in enumerate(functions, 1):
    print(f"\n--- FONCTION {i} ---")
    print(f"SCHÉMA: {func[0]}")
    print(f"NOM: {func[1]}")
    print(f"ARGUMENTS: {func[2]}")

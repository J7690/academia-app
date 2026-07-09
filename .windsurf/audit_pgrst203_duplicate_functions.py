import requests
import json

admin_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json",
}

print("=" * 80)
print("MISSION 1 - PREUVE DIRECTE DES RPC DUPLIQUÉES")
print("=" * 80)

# Interroger pg_proc pour obtenir les fonctions whiteboard_create_project
sql = """
SELECT
    oid,
    proname,
    pg_get_function_identity_arguments(oid) as signature,
    pg_get_functiondef(oid) as full_definition
FROM pg_proc
WHERE proname='whiteboard_create_project'
ORDER BY oid;
"""

print("\nSQL exécuté :")
print(sql)

resp = requests.post(admin_url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"\nSTATUS: {resp.status_code}")

if resp.status_code == 200:
    data = resp.json()
    functions = data.get('data', [])
    print(f"\nNombre de fonctions trouvées : {len(functions)}")
    print("\n" + "=" * 80)
    print("FONCTIONS TROUVÉES :")
    print("=" * 80)
    for i, func in enumerate(functions, 1):
        print(f"\nFONCTION {i}:")
        print(f"  OID: {func[0]}")
        print(f"  NOM: {func[1]}")
        print(f"  SIGNATURE: {func[2]}")
        print(f"  DÉFINITION: {func[3]}")
else:
    print(f"Error: {resp.text}")

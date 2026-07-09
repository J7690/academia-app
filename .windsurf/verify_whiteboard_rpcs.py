import requests

url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=" * 80)
print("VÉRIFICATION DES RPCs WHITEBOARD")
print("=" * 80)

# Vérifier les RPCs whiteboard via information_schema.routines
print("\n--- RPCs whiteboard (information_schema) ---")
sql_routines = """
SELECT 
    routine_schema,
    routine_name,
    routine_type
FROM information_schema.routines
WHERE routine_name LIKE '%whiteboard%'
ORDER BY routine_schema, routine_name;
"""

resp = requests.post(url, headers=headers, json={"p_sql": sql_routines}, timeout=30)
data = resp.json()

if data.get("ok") and data.get("rows"):
    print(f"✅ {len(data['rows'])} RPCs whiteboard trouvées:")
    for row in data["rows"]:
        print(f"  - {row['routine_schema']}.{row['routine_name']} ({row['routine_type']})")
elif data.get("ok") and data.get("affected_rows") > 0:
    print(f"✅ {data['affected_rows']} RPCs whiteboard trouvées (affected_rows)")
else:
    print(f"❌ Aucune RPC whiteboard trouvée")

# Vérifier aussi whiteboard_create_project spécifiquement
print("\n--- RPC whiteboard_create_project ---")
sql_create = """
SELECT 
    routine_schema,
    routine_name,
    routine_type
FROM information_schema.routines
WHERE routine_name = 'whiteboard_create_project';
"""

resp = requests.post(url, headers=headers, json={"p_sql": sql_create}, timeout=30)
data = resp.json()

if data.get("ok") and data.get("rows"):
    print(f"✅ whiteboard_create_project trouvée:")
    for row in data["rows"]:
        print(f"  - {row['routine_schema']}.{row['routine_name']} ({row['routine_type']})")
elif data.get("ok") and data.get("affected_rows") > 0:
    print(f"✅ whiteboard_create_project trouvée (affected_rows)")
else:
    print(f"❌ whiteboard_create_project non trouvée")

print("\n" + "=" * 80)
print("VÉRIFICATION TERMINÉE")
print("=" * 80)

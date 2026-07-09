import requests

supabase_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=" * 80)
print("SCHEMA TABLE whiteboard_projects")
print("=" * 80)

sql = """
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'app' 
AND table_name = 'whiteboard_projects'
ORDER BY ordinal_position;
"""

resp = requests.post(supabase_url, headers=headers, json={"p_sql": sql}, timeout=30)
data = resp.json()

print(f"\nSTATUS: {resp.status_code}")

if data.get("ok") and data.get("rows"):
    print("✅ Colonnes:")
    for row in data["rows"]:
        print(f"  {row['column_name']}: {row['data_type']} (nullable: {row['is_nullable']}, default: {row['column_default']})")
elif data.get("ok") and data.get("affected_rows") > 0:
    print(f"✅ {data['affected_rows']} colonnes trouvées (affected_rows)")
else:
    print(f"❌ Erreur")

# Check constraints
sql_constraints = """
SELECT conname, pg_get_constraintdef(oid)
FROM pg_constraint
JOIN pg_class ON pg_constraint.conrelid = pg_class.oid
JOIN pg_namespace ON pg_class.relnamespace = pg_namespace.oid
WHERE pg_namespace.nspname = 'app'
AND pg_class.relname = 'whiteboard_projects'
AND conname LIKE '%renderer_id%';
"""

resp_constraints = requests.post(supabase_url, headers=headers, json={"p_sql": sql_constraints}, timeout=30)
data_constraints = resp_constraints.json()

print(f"\n--- Contraintes renderer_id ---")
print(f"STATUS: {resp_constraints.status_code}")

if data_constraints.get("ok") and data_constraints.get("rows"):
    print("✅ Contraintes:")
    for row in data_constraints["rows"]:
        print(f"  {row['conname']}: {row['pg_get_constraintdef']}")
elif data_constraints.get("ok") and data_constraints.get("affected_rows") > 0:
    print(f"✅ {data_constraints['affected_rows']} contraintes trouvées (affected_rows)")
else:
    print(f"❌ Aucune contrainte trouvée")

print("\n" + "=" * 80)

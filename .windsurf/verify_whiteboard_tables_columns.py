import requests

url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=" * 80)
print("VÉRIFICATION DES COLONNES DES TABLES WHITEBOARD")
print("=" * 80)

tables = [
    "whiteboard_projects",
    "whiteboard_renders",
    "whiteboard_ai_generations"
]

for table in tables:
    print(f"\n--- Table: app.{table} ---")
    
    sql = f"""
    SELECT 
        column_name,
        data_type,
        is_nullable,
        column_default
    FROM information_schema.columns
    WHERE table_schema = 'app' 
    AND table_name = '{table}'
    ORDER BY ordinal_position;
    """
    
    resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
    data = resp.json()
    
    if data.get("ok") and data.get("rows"):
        print(f"✅ Colonnes trouvées ({len(data['rows'])}):")
        for row in data["rows"]:
            print(f"  - {row['column_name']}: {row['data_type']} (nullable: {row['is_nullable']}, default: {row['column_default']})")
    elif data.get("ok") and data.get("affected_rows") > 0:
        print(f"✅ {data['affected_rows']} colonnes trouvées (affected_rows)")
    else:
        print(f"❌ Aucune colonne trouvée")
        print(f"STATUS: {resp.status_code}")
        print(f"BODY: {resp.text}")

print("\n" + "=" * 80)
print("VÉRIFICATION TERMINÉE")
print("=" * 80)

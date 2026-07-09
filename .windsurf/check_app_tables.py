import requests

url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json",
}

print("Vérification des tables dans le schéma 'app'...")

sql = """
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'app'
AND table_name LIKE '%whiteboard%'
ORDER BY table_name;
"""

resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
print("STATUS:", resp.status_code)
data = resp.json()
print("BODY:", resp.text)

if data.get("ok") and data.get("rows"):
    print("\nTables whiteboard trouvées:")
    for row in data["rows"]:
        print(f"  - {row['table_name']}")
elif data.get("ok") and data.get("affected_rows") > 0:
    print(f"\n✅ {data['affected_rows']} tables whiteboard trouvées (affected_rows)")
    print("Note: admin_execute_sql ne retourne pas les rows, mais affected_rows indique {data['affected_rows']} résultats")
else:
    print("\n❌ Aucune table whiteboard trouvée")
    print("Vérification directe via pg_class...")
    
    sql2 = """
    SELECT relname
    FROM pg_class
    JOIN pg_namespace ON pg_class.relnamespace = pg_namespace.oid
    WHERE pg_namespace.nspname = 'app'
    AND relname LIKE '%whiteboard%'
    """
    resp2 = requests.post(url, headers=headers, json={"p_sql": sql2}, timeout=30)
    print("STATUS:", resp2.status_code)
    print("BODY:", resp2.text)
    data2 = resp2.json()
    if data2.get("ok") and data2.get("rows"):
        print("\nTables whiteboard trouvées via pg_class:")
        for row in data2["rows"]:
            print(f"  - {row['relname']}")
    elif data2.get("ok") and data2.get("affected_rows") > 0:
        print(f"\n✅ {data2['affected_rows']} tables whiteboard trouvées via pg_class (affected_rows)")

import requests

url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=== RECHERCHE TABLES VIDÉO ===\n")

# 1. Lister toutes les tables dans tous les schémas
sql1 = """
SELECT table_schema, table_name 
FROM information_schema.tables 
WHERE table_name LIKE '%video%'
ORDER BY table_schema, table_name
"""
resp1 = requests.post(url, headers=headers, json={"p_sql": sql1}, timeout=30)
data1 = resp1.json()
if data1.get("ok") and data1.get("rows"):
    print('Toutes les tables vidéo (tous schémas):')
    for row in data1["rows"]:
        print(f"  Schema: {row['table_schema']}, Table: {row['table_name']}")
    print()
else:
    print('Tables vidéo: NOT FOUND')
    print()

# 2. Lister tous les schémas
sql2 = """
SELECT schema_name 
FROM information_schema.schemata 
WHERE schema_name NOT IN ('pg_catalog', 'information_schema')
ORDER BY schema_name
"""
resp2 = requests.post(url, headers=headers, json={"p_sql": sql2}, timeout=30)
data2 = resp2.json()
if data2.get("ok") and data2.get("rows"):
    print('Schémas disponibles:')
    for row in data2["rows"]:
        print(f"  {row['schema_name']}")
    print()
else:
    print('Schémas: NOT FOUND')
    print()

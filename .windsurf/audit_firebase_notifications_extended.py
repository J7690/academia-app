import requests
import json
from datetime import datetime

admin_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json",
}

print("=" * 80)
print("AUDIT ÉTENDU - RECHERCHE TABLES NOTIFICATIONS TOUS SCHÉMAS")
print("=" * 80)

# Chercher toutes les tables contenant "token" ou "notification" dans tous les schémas
sql_search = """
SELECT 
    table_schema,
    table_name,
    table_type
FROM information_schema.tables
WHERE (table_name LIKE '%token%' OR table_name LIKE '%notification%')
AND table_schema NOT IN ('pg_catalog', 'information_schema')
ORDER BY table_schema, table_name;
"""

resp = requests.post(admin_url, headers=headers, json={"p_sql": sql_search}, timeout=30)
if resp.status_code == 200:
    tables = resp.json().get('data', [])
    print(f"\nTables trouvées: {len(tables)}")
    for table in tables:
        print(f"  - {table[0]}.{table[1]} ({table[2]})")
else:
    print(f"Erreur: {resp.text}")

# Lister toutes les tables du schéma app
print("\n" + "=" * 80)
print("TOUTES LES TABLES DU SCHÉMA APP")
print("=" * 80)

sql_app_tables = """
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'app'
ORDER BY table_name;
"""

resp_app = requests.post(admin_url, headers=headers, json={"p_sql": sql_app_tables}, timeout=30)
if resp_app.status_code == 200:
    app_tables = resp_app.json().get('data', [])
    print(f"\nNombre de tables dans app: {len(app_tables)}")
    for i, table in enumerate(app_tables, 1):
        print(f"  {i}. {table[0]}")
else:
    print(f"Erreur: {resp_app.text}")

# Chercher toutes les RPCs dans le schéma public et app
print("\n" + "=" * 80)
print("TOUTES LES RPCs CONTENANT 'token' OU 'notification'")
print("=" * 80)

sql_rpcs = """
SELECT 
    proname,
    pronamespace::regnamespace as schema,
    pg_get_function_identity_arguments(oid) as signature
FROM pg_proc
WHERE pronamespace::regnamespace NOT IN ('pg_catalog', 'information_schema')
AND (proname LIKE '%token%' OR proname LIKE '%notification%' OR proname LIKE '%device%')
ORDER BY schema, proname;
"""

resp_rpcs = requests.post(admin_url, headers=headers, json={"p_sql": sql_rpcs}, timeout=30)
if resp_rpcs.status_code == 200:
    rpcs = resp_rpcs.json().get('data', [])
    print(f"\nRPCs trouvées: {len(rpcs)}")
    for rpc in rpcs:
        print(f"  - {rpc[1]}.{rpc[0]}({rpc[2]})")
else:
    print(f"Erreur: {resp_rpcs.text}")

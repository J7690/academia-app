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
print("AUDIT COMPLET - TOUS LES SCHÉMAS")
print("=" * 80)

# Lister tous les schémas
sql_schemas = """
SELECT schema_name
FROM information_schema.schemata
WHERE schema_name NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
ORDER BY schema_name;
"""

resp = requests.post(admin_url, headers=headers, json={"p_sql": sql_schemas}, timeout=30)
if resp.status_code == 200:
    schemas = resp.json().get('data', [])
    print(f"\nSchémas trouvés: {len(schemas)}")
    for schema in schemas:
        print(f"  - {schema[0]}")
else:
    print(f"Erreur: {resp.text}")

# Pour chaque schéma, compter les tables
print("\n" + "=" * 80)
print("NOMBRE DE TABLES PAR SCHÉMA")
print("=" * 80)

for schema in schemas:
    schema_name = schema[0]
    sql_count = f"""
    SELECT COUNT(*) FROM information_schema.tables 
    WHERE table_schema = '{schema_name}';
    """
    resp_count = requests.post(admin_url, headers=headers, json={"p_sql": sql_count}, timeout=30)
    if resp_count.status_code == 200:
        count = resp_count.json().get('data', [[0]])[0][0]
        print(f"  {schema_name}: {count} tables")
        
        # Si > 0 tables, lister les 10 premières
        if count > 0:
            sql_list = f"""
            SELECT table_name FROM information_schema.tables 
            WHERE table_schema = '{schema_name}'
            ORDER BY table_name
            LIMIT 10;
            """
            resp_list = requests.post(admin_url, headers=headers, json={"p_sql": sql_list}, timeout=30)
            if resp_list.status_code == 200:
                tables = resp_list.json().get('data', [])
                for table in tables:
                    print(f"    - {table[0]}")

#!/usr/bin/env python3
"""Live Check All Schemas Tables - Find whiteboard tables anywhere"""
import requests
from datetime import datetime

url = "https://thevdfcwlcqzdoybfvgs.supabase.co"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json",
}

OUTPUT_FILE = "c:\\Users\\fasop\\AndroidStudioProjects\\academia\\.windsurf\\live_check_all_schemas_tables_output.txt"

results = []
results.append("=" * 80)
results.append("LIVE CHECK ALL SCHEMAS TABLES")
results.append(datetime.now().isoformat())
results.append("=" * 80)
results.append("")

rpc_url = f"{url}/rest/v1/rpc/admin_execute_sql"

# 1. Lister tous les schémas
results.append("1. TOUS LES SCHÉMAS")
results.append("-" * 80)
sql = """
SELECT schema_name
FROM information_schema.schemata
WHERE schema_name NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
ORDER BY schema_name;
"""
resp = requests.post(rpc_url, headers=headers, json={"p_sql": sql}, timeout=30)
results.append(f"STATUS: {resp.status_code}")
if resp.status_code == 200:
    data = resp.json()
    schemas = data.get('data', [])
    results.append(f"Schémas: {len(schemas)}")
    for schema in schemas:
        results.append(f"  - {schema[0]}")
else:
    results.append(f"Error: {resp.text}")
results.append("")

# 2. Rechercher tables whiteboard dans tous les schémas
results.append("2. TABLES WHITEBOARD DANS TOUS LES SCHÉMAS")
results.append("-" * 80)
sql = """
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_name LIKE '%whiteboard%'
ORDER BY table_schema, table_name;
"""
resp = requests.post(rpc_url, headers=headers, json={"p_sql": sql}, timeout=30)
results.append(f"STATUS: {resp.status_code}")
if resp.status_code == 200:
    data = resp.json()
    tables = data.get('data', [])
    results.append(f"Tables trouvées: {len(tables)}")
    for table in tables:
        results.append(f"  - {table[0]}.{table[1]}")
else:
    results.append(f"Error: {resp.text}")
results.append("")

# 3. Rechercher tables projects dans tous les schémas
results.append("3. TABLES PROJECTS DANS TOUS LES SCHÉMAS")
results.append("-" * 80)
sql = """
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_name LIKE '%projects%'
ORDER BY table_schema, table_name;
"""
resp = requests.post(rpc_url, headers=headers, json={"p_sql": sql}, timeout=30)
results.append(f"STATUS: {resp.status_code}")
if resp.status_code == 200:
    data = resp.json()
    tables = data.get('data', [])
    results.append(f"Tables trouvées: {len(tables)}")
    for table in tables:
        results.append(f"  - {table[0]}.{table[1]}")
else:
    results.append(f"Error: {resp.text}")
results.append("")

# 4. Rechercher tables renders dans tous les schémas
results.append("4. TABLES RENDERS DANS TOUS LES SCHÉMAS")
results.append("-" * 80)
sql = """
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_name LIKE '%renders%'
ORDER BY table_schema, table_name;
"""
resp = requests.post(rpc_url, headers=headers, json={"p_sql": sql}, timeout=30)
results.append(f"STATUS: {resp.status_code}")
if resp.status_code == 200:
    data = resp.json()
    tables = data.get('data', [])
    results.append(f"Tables trouvées: {len(tables)}")
    for table in tables:
        results.append(f"  - {table[0]}.{table[1]}")
else:
    results.append(f"Error: {resp.text}")
results.append("")

# 5. Vérifier si admin_execute_sql existe
results.append("5. VÉRIFICATION ADMIN_EXECUTE_SQL")
results.append("-" * 80)
sql = """
SELECT routine_schema, routine_name, routine_type
FROM information_schema.routines
WHERE routine_name = 'admin_execute_sql';
"""
resp = requests.post(rpc_url, headers=headers, json={"p_sql": sql}, timeout=30)
results.append(f"STATUS: {resp.status_code}")
if resp.status_code == 200:
    data = resp.json()
    rpcs = data.get('data', [])
    results.append(f"admin_execute_sql trouvée: {len(rpcs)}")
    for rpc in rpcs:
        results.append(f"  - {rpc[0]}.{rpc[1]} ({rpc[2]})")
else:
    results.append(f"Error: {resp.text}")
results.append("")

# Sauvegarder les résultats
with open(OUTPUT_FILE, 'w') as f:
    f.write('\n'.join(results))

print("VÉRIFICATION TERMINÉE")
print(f"Résultats sauvegardés dans: {OUTPUT_FILE}")

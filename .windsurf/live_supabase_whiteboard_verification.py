#!/usr/bin/env python3
"""Live Supabase Verification - Smart Whiteboard"""
import requests
import json
from datetime import datetime

url = "https://thevdfcwlcqzdoybfvgs.supabase.co"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json",
}

OUTPUT_FILE = "c:\\Users\\fasop\\AndroidStudioProjects\\academia\\.windsurf\\live_supabase_whiteboard_verification_output.txt"

results = []
results.append("=" * 80)
results.append("LIVE SUPABASE VERIFICATION - SMART WHITEBOARD")
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
    results.append(f"Schémas trouvés: {len(schemas)}")
    for schema in schemas:
        results.append(f"  - {schema[0]}")
else:
    results.append(f"Error: {resp.text}")
results.append("")

# 2. Rechercher tables whiteboard dans tous les schémas
results.append("2. TABLES WHITEBOARD")
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

# 3. Pour chaque table trouvée, obtenir les colonnes
if tables:
    for table in tables:
        schema = table[0]
        table_name = table[1]
        results.append(f"\n3. COLONNES DE {schema}.{table_name}")
        results.append("-" * 80)
        sql = f"""
        SELECT column_name, data_type, is_nullable, column_default
        FROM information_schema.columns
        WHERE table_schema = '{schema}' AND table_name = '{table_name}'
        ORDER BY ordinal_position;
        """
        resp = requests.post(rpc_url, headers=headers, json={"p_sql": sql}, timeout=30)
        results.append(f"STATUS: {resp.status_code}")
        if resp.status_code == 200:
            data = resp.json()
            columns = data.get('data', [])
            results.append(f"Colonnes trouvées: {len(columns)}")
            for col in columns:
                results.append(f"  - {col[0]}: {col[1]} (nullable: {col[2]}, default: {col[3]})")
        else:
            results.append(f"Error: {resp.text}")
        
        # Compter les enregistrements
        results.append(f"\nComptage enregistrements {schema}.{table_name}:")
        sql = f"SELECT COUNT(*) FROM {schema}.{table_name};"
        resp = requests.post(rpc_url, headers=headers, json={"p_sql": sql}, timeout=30)
        results.append(f"STATUS: {resp.status_code}")
        if resp.status_code == 200:
            data = resp.json()
            count = data.get('data', [[0]])[0][0]
            results.append(f"Enregistrements: {count}")
        else:
            results.append(f"Error: {resp.text}")
else:
    results.append("3. COLONNES - Aucune table trouvée")

# 4. Rechercher RPCs whiteboard
results.append("\n\n4. RPCS WHITEBOARD")
results.append("-" * 80)
sql = """
SELECT routine_schema, routine_name, routine_type, created
FROM information_schema.routines
WHERE routine_name LIKE '%whiteboard%'
ORDER BY routine_schema, routine_name;
"""
resp = requests.post(rpc_url, headers=headers, json={"p_sql": sql}, timeout=30)
results.append(f"STATUS: {resp.status_code}")
if resp.status_code == 200:
    data = resp.json()
    rpcs = data.get('data', [])
    results.append(f"RPCs trouvées: {len(rpcs)}")
    for rpc in rpcs:
        results.append(f"  - {rpc[0]}.{rpc[1]} ({rpc[2]}, created: {rpc[3]})")
else:
    results.append(f"Error: {resp.text}")
results.append("")

# 5. Rechercher RPCs storyboard
results.append("5. RPCS STORYBOARD")
results.append("-" * 80)
sql = """
SELECT routine_schema, routine_name, routine_type, created
FROM information_schema.routines
WHERE routine_name LIKE '%storyboard%'
ORDER BY routine_schema, routine_name;
"""
resp = requests.post(rpc_url, headers=headers, json={"p_sql": sql}, timeout=30)
results.append(f"STATUS: {resp.status_code}")
if resp.status_code == 200:
    data = resp.json()
    rpcs = data.get('data', [])
    results.append(f"RPCs trouvées: {len(rpcs)}")
    for rpc in rpcs:
        results.append(f"  - {rpc[0]}.{rpc[1]} ({rpc[2]}, created: {rpc[3]})")
else:
    results.append(f"Error: {resp.text}")
results.append("")

# 6. Vérifier admin_execute_sql
results.append("6. VÉRIFICATION ADMIN_EXECUTE_SQL")
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

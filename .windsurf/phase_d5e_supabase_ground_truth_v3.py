#!/usr/bin/env python3
"""PHASE D.5E – SUPABASE GROUND TRUTH V3 (SANS POINTS-VIRGULES)"""
import requests
from datetime import datetime

url = "https://thevdfcwlcqzdoybfvgs.supabase.co"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json",
}

OUTPUT_FILE = "c:\\Users\\fasop\\AndroidStudioProjects\\academia\\.windsurf\\phase_d5e_supabase_ground_truth_v3_output.txt"

results = []
results.append("=" * 80)
results.append("PHASE D.5E – SUPABASE GROUND TRUTH V3")
results.append(datetime.now().isoformat())
results.append("=" * 80)
results.append("")

rpc_url = f"{url}/rest/v1/rpc/admin_execute_sql"

# SECTION 0 – TOUS LES SCHÉMAS
results.append("SECTION 0 – TOUS LES SCHÉMAS")
results.append("-" * 80)

sql = """
SELECT n.nspname as schema_name
FROM pg_namespace n
WHERE n.nspname NOT LIKE 'pg_%'
AND n.nspname NOT LIKE 'information_schema'
ORDER BY n.nspname
"""
resp = requests.post(rpc_url, headers=headers, json={"p_sql": sql}, timeout=30)
results.append(f"STATUS: {resp.status_code}")
if resp.status_code == 200:
    data = resp.json()
    if data.get("ok") and data.get("rows"):
        schemas = [row['schema_name'] for row in data["rows"]]
        results.append(f"Schémas trouvés: {len(schemas)}")
        for schema in schemas:
            results.append(f"  - {schema}")
    else:
        results.append("Aucun schéma trouvé")
else:
    results.append(f"Error: {resp.text}")

# SECTION A – TABLES RÉELLES (pg_class) TOUS SCHÉMAS
results.append("\n\nSECTION A – TABLES RÉELLES (pg_class) TOUS SCHÉMAS")
results.append("-" * 80)

sql = """
SELECT n.nspname as schema, c.relname as table_name
FROM pg_class c
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE c.relkind = 'r'
AND n.nspname NOT LIKE 'pg_%'
AND n.nspname NOT LIKE 'information_schema'
ORDER BY n.nspname, c.relname
"""
resp = requests.post(rpc_url, headers=headers, json={"p_sql": sql}, timeout=30)
results.append(f"STATUS: {resp.status_code}")
if resp.status_code == 200:
    data = resp.json()
    if data.get("ok") and data.get("rows"):
        tables = data["rows"]
        results.append(f"Tables totales: {len(tables)}")
        for table in tables:
            results.append(f"  - {table['schema']}.{table['table_name']}")
    else:
        results.append("Aucune table trouvée")
else:
    results.append(f"Error: {resp.text}")

# SECTION B – RPC RÉELLES (pg_proc) TOUS SCHÉMAS
results.append("\n\nSECTION B – RPC RÉELLES (pg_proc) TOUS SCHÉMAS")
results.append("-" * 80)

sql = """
SELECT n.nspname as schema, p.proname as rpc_name, pg_get_function_arguments(p.oid) as parameters
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.prokind = 'f'
AND n.nspname NOT LIKE 'pg_%'
AND n.nspname NOT LIKE 'information_schema'
ORDER BY n.nspname, p.proname
"""
resp = requests.post(rpc_url, headers=headers, json={"p_sql": sql}, timeout=30)
results.append(f"STATUS: {resp.status_code}")
if resp.status_code == 200:
    data = resp.json()
    if data.get("ok") and data.get("rows"):
        rpcs = data["rows"]
        results.append(f"RPCs totales: {len(rpcs)}")
        for rpc in rpcs:
            results.append(f"  - {rpc['schema']}.{rpc['rpc_name']}({rpc['parameters']})")
    else:
        results.append("Aucune RPC trouvée")
else:
    results.append(f"Error: {resp.text}")

# SECTION C – OBJETS WHITEBOARD (pg_class + pg_proc)
results.append("\n\nSECTION C – OBJETS WHITEBOARD")
results.append("-" * 80)

# Tables whiteboard
results.append("\n--- Tables whiteboard (pg_class) ---")
sql = """
SELECT n.nspname as schema, c.relname as table_name
FROM pg_class c
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE c.relname LIKE '%whiteboard%'
AND c.relkind = 'r'
ORDER BY n.nspname, c.relname
"""
resp = requests.post(rpc_url, headers=headers, json={"p_sql": sql}, timeout=30)
results.append(f"STATUS: {resp.status_code}")
if resp.status_code == 200:
    data = resp.json()
    if data.get("ok") and data.get("rows"):
        tables = data["rows"]
        results.append(f"Tables trouvées: {len(tables)}")
        for table in tables:
            results.append(f"  - {table['schema']}.{table['table_name']}")
    else:
        results.append("Aucune table trouvée")
else:
    results.append(f"Error: {resp.text}")

# Tables storyboard
results.append("\n--- Tables storyboard (pg_class) ---")
sql = """
SELECT n.nspname as schema, c.relname as table_name
FROM pg_class c
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE c.relname LIKE '%storyboard%'
AND c.relkind = 'r'
ORDER BY n.nspname, c.relname
"""
resp = requests.post(rpc_url, headers=headers, json={"p_sql": sql}, timeout=30)
results.append(f"STATUS: {resp.status_code}")
if resp.status_code == 200:
    data = resp.json()
    if data.get("ok") and data.get("rows"):
        tables = data["rows"]
        results.append(f"Tables trouvées: {len(tables)}")
        for table in tables:
            results.append(f"  - {table['schema']}.{table['table_name']}")
    else:
        results.append("Aucune table trouvée")
else:
    results.append(f"Error: {resp.text}")

# Tables render
results.append("\n--- Tables render (pg_class) ---")
sql = """
SELECT n.nspname as schema, c.relname as table_name
FROM pg_class c
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE c.relname LIKE '%render%'
AND c.relkind = 'r'
ORDER BY n.nspname, c.relname
"""
resp = requests.post(rpc_url, headers=headers, json={"p_sql": sql}, timeout=30)
results.append(f"STATUS: {resp.status_code}")
if resp.status_code == 200:
    data = resp.json()
    if data.get("ok") and data.get("rows"):
        tables = data["rows"]
        results.append(f"Tables trouvées: {len(tables)}")
        for table in tables:
            results.append(f"  - {table['schema']}.{table['table_name']}")
    else:
        results.append("Aucune table trouvée")
else:
    results.append(f"Error: {resp.text}")

# RPCs whiteboard
results.append("\n--- RPCs whiteboard (pg_proc) ---")
sql = """
SELECT n.nspname as schema, p.proname as rpc_name, pg_get_function_arguments(p.oid) as parameters
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname LIKE '%whiteboard%'
AND p.prokind = 'f'
ORDER BY n.nspname, p.proname
"""
resp = requests.post(rpc_url, headers=headers, json={"p_sql": sql}, timeout=30)
results.append(f"STATUS: {resp.status_code}")
if resp.status_code == 200:
    data = resp.json()
    if data.get("ok") and data.get("rows"):
        rpcs = data["rows"]
        results.append(f"RPCs trouvées: {len(rpcs)}")
        for rpc in rpcs:
            results.append(f"  - {rpc['schema']}.{rpc['rpc_name']}({rpc['parameters']})")
    else:
        results.append("Aucune RPC trouvée")
else:
    results.append(f"Error: {resp.text}")

# RPCs storyboard
results.append("\n--- RPCs storyboard (pg_proc) ---")
sql = """
SELECT n.nspname as schema, p.proname as rpc_name, pg_get_function_arguments(p.oid) as parameters
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname LIKE '%storyboard%'
AND p.prokind = 'f'
ORDER BY n.nspname, p.proname
"""
resp = requests.post(rpc_url, headers=headers, json={"p_sql": sql}, timeout=30)
results.append(f"STATUS: {resp.status_code}")
if resp.status_code == 200:
    data = resp.json()
    if data.get("ok") and data.get("rows"):
        rpcs = data["rows"]
        results.append(f"RPCs trouvées: {len(rpcs)}")
        for rpc in rpcs:
            results.append(f"  - {rpc['schema']}.{rpc['rpc_name']}({rpc['parameters']})")
    else:
        results.append("Aucune RPC trouvée")
else:
    results.append(f"Error: {resp.text}")

# Sauvegarder les résultats
with open(OUTPUT_FILE, 'w') as f:
    f.write('\n'.join(results))

print("PHASE D.5E V3 TERMINÉE")
print(f"Résultats sauvegardés dans: {OUTPUT_FILE}")

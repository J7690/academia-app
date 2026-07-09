#!/usr/bin/env python3
"""Live Deploy Whiteboard Tables - Create schema and tables"""
import requests
from datetime import datetime

url = "https://thevdfcwlcqzdoybfvgs.supabase.co"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json",
}

OUTPUT_FILE = "c:\\Users\\fasop\\AndroidStudioProjects\\academia\\.windsurf\\live_deploy_whiteboard_tables_output.txt"

results = []
results.append("=" * 80)
results.append("LIVE DEPLOY WHITEBOARD TABLES")
results.append(datetime.now().isoformat())
results.append("=" * 80)
results.append("")

# 1. Créer le schéma 'app'
results.append("1. CRÉATION SCHÉMA 'app'")
results.append("-" * 80)
sql = "CREATE SCHEMA IF NOT EXISTS app;"
rpc_url = f"{url}/rest/v1/rpc/admin_execute_sql"
resp = requests.post(rpc_url, headers=headers, json={"p_sql": sql}, timeout=30)
results.append(f"STATUS: {resp.status_code}")
results.append(f"BODY: {resp.text}")
results.append("")

# 2. Déployer la migration (tables)
results.append("2. DÉPLOIEMENT TABLES WHITEBOARD")
results.append("-" * 80)
with open('../supabase/migrations/20260623000001_create_whiteboard_tables.sql', 'r') as f:
    sql_tables = f.read()

resp = requests.post(rpc_url, headers=headers, json={"p_sql": sql_tables}, timeout=30)
results.append(f"STATUS: {resp.status_code}")
results.append(f"BODY: {resp.text}")
results.append("")

# 3. Déployer les RPCs worker
results.append("3. DÉPLOIEMENT RPCS WORKER")
results.append("-" * 80)
with open('sql_changes/change_20260623_whiteboard_worker_rpcs.sql', 'r') as f:
    sql_worker_rpcs = f.read()

resp = requests.post(rpc_url, headers=headers, json={"p_sql": sql_worker_rpcs}, timeout=30)
results.append(f"STATUS: {resp.status_code}")
results.append(f"BODY: {resp.text}")
results.append("")

# 4. Déployer les RPCs editor
results.append("4. DÉPLOIEMENT RPCS EDITOR")
results.append("-" * 80)
with open('sql_changes/change_20260624_whiteboard_editor_rpcs.sql', 'r') as f:
    sql_editor_rpcs = f.read()

resp = requests.post(rpc_url, headers=headers, json={"p_sql": sql_editor_rpcs}, timeout=30)
results.append(f"STATUS: {resp.status_code}")
results.append(f"BODY: {resp.text}")
results.append("")

# 5. Vérifier le schéma 'app'
results.append("5. VÉRIFICATION SCHÉMA 'app'")
results.append("-" * 80)
sql = """
SELECT schema_name
FROM information_schema.schemata
WHERE schema_name = 'app';
"""
resp = requests.post(rpc_url, headers=headers, json={"p_sql": sql}, timeout=30)
results.append(f"STATUS: {resp.status_code}")
results.append(f"BODY: {resp.text}")
results.append("")

# 6. Vérifier les tables
results.append("6. VÉRIFICATION TABLES")
results.append("-" * 80)
sql = """
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_schema = 'app' AND table_name LIKE 'whiteboard%'
ORDER BY table_name;
"""
resp = requests.post(rpc_url, headers=headers, json={"p_sql": sql}, timeout=30)
results.append(f"STATUS: {resp.status_code}")
results.append(f"BODY: {resp.text}")
results.append("")

# 7. Vérifier les RPCs
results.append("7. VÉRIFICATION RPCS")
results.append("-" * 80)
sql = """
SELECT routine_schema, routine_name
FROM information_schema.routines
WHERE routine_schema = 'app' AND routine_name LIKE '%whiteboard%'
ORDER BY routine_name;
"""
resp = requests.post(rpc_url, headers=headers, json={"p_sql": sql}, timeout=30)
results.append(f"STATUS: {resp.status_code}")
results.append(f"BODY: {resp.text}")
results.append("")

# Sauvegarder les résultats
with open(OUTPUT_FILE, 'w') as f:
    f.write('\n'.join(results))

print("DÉPLOIEMENT TERMINÉ")
print(f"Résultats sauvegardés dans: {OUTPUT_FILE}")

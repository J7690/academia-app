#!/usr/bin/env python3
"""Live Verify Whiteboard Details - Tables and RPCs"""
import requests
from datetime import datetime

url = "https://thevdfcwlcqzdoybfvgs.supabase.co"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json",
}

OUTPUT_FILE = "c:\\Users\\fasop\\AndroidStudioProjects\\academia\\.windsurf\\live_verify_whiteboard_details_output.txt"

results = []
results.append("=" * 80)
results.append("LIVE VERIFY WHITEBOARD DETAILS")
results.append(datetime.now().isoformat())
results.append("=" * 80)
results.append("")

rpc_url = f"{url}/rest/v1/rpc/admin_execute_sql"

# 1. Lister les tables dans app
results.append("1. TABLES DANS SCHÉMA 'app'")
results.append("-" * 80)
sql = """
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'app'
ORDER BY table_name;
"""
resp = requests.post(rpc_url, headers=headers, json={"p_sql": sql}, timeout=30)
results.append(f"STATUS: {resp.status_code}")
if resp.status_code == 200:
    data = resp.json()
    tables = data.get('data', [])
    results.append(f"Tables trouvées: {len(tables)}")
    for table in tables:
        results.append(f"  - {table[0]}")
else:
    results.append(f"Error: {resp.text}")
results.append("")

# 2. Détails de whiteboard_projects
results.append("2. DÉTAILS TABLE whiteboard_projects")
results.append("-" * 80)
sql = """
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'app' AND table_name = 'whiteboard_projects'
ORDER BY ordinal_position;
"""
resp = requests.post(rpc_url, headers=headers, json={"p_sql": sql}, timeout=30)
results.append(f"STATUS: {resp.status_code}")
if resp.status_code == 200:
    data = resp.json()
    columns = data.get('data', [])
    results.append(f"Colonnes: {len(columns)}")
    for col in columns:
        results.append(f"  - {col[0]}: {col[1]} (nullable: {col[2]}, default: {col[3]})")
else:
    results.append(f"Error: {resp.text}")
results.append("")

# 3. Comptage whiteboard_projects
results.append("3. COMPTAGE whiteboard_projects")
results.append("-" * 80)
sql = "SELECT COUNT(*) FROM app.whiteboard_projects;"
resp = requests.post(rpc_url, headers=headers, json={"p_sql": sql}, timeout=30)
results.append(f"STATUS: {resp.status_code}")
if resp.status_code == 200:
    data = resp.json()
    count = data.get('data', [[0]])[0][0]
    results.append(f"Enregistrements: {count}")
else:
    results.append(f"Error: {resp.text}")
results.append("")

# 4. Détails de whiteboard_renders
results.append("4. DÉTAILS TABLE whiteboard_renders")
results.append("-" * 80)
sql = """
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'app' AND table_name = 'whiteboard_renders'
ORDER BY ordinal_position;
"""
resp = requests.post(rpc_url, headers=headers, json={"p_sql": sql}, timeout=30)
results.append(f"STATUS: {resp.status_code}")
if resp.status_code == 200:
    data = resp.json()
    columns = data.get('data', [])
    results.append(f"Colonnes: {len(columns)}")
    for col in columns:
        results.append(f"  - {col[0]}: {col[1]} (nullable: {col[2]}, default: {col[3]})")
else:
    results.append(f"Error: {resp.text}")
results.append("")

# 5. Comptage whiteboard_renders
results.append("5. COMPTAGE whiteboard_renders")
results.append("-" * 80)
sql = "SELECT COUNT(*) FROM app.whiteboard_renders;"
resp = requests.post(rpc_url, headers=headers, json={"p_sql": sql}, timeout=30)
results.append(f"STATUS: {resp.status_code}")
if resp.status_code == 200:
    data = resp.json()
    count = data.get('data', [[0]])[0][0]
    results.append(f"Enregistrements: {count}")
else:
    results.append(f"Error: {resp.text}")
results.append("")

# 6. Lister les RPCs whiteboard
results.append("6. RPCS WHITEBOARD")
results.append("-" * 80)
sql = """
SELECT routine_schema, routine_name, routine_type
FROM information_schema.routines
WHERE routine_schema = 'app' AND routine_name LIKE '%whiteboard%'
ORDER BY routine_name;
"""
resp = requests.post(rpc_url, headers=headers, json={"p_sql": sql}, timeout=30)
results.append(f"STATUS: {resp.status_code}")
if resp.status_code == 200:
    data = resp.json()
    rpcs = data.get('data', [])
    results.append(f"RPCs trouvées: {len(rpcs)}")
    for rpc in rpcs:
        results.append(f"  - {rpc[0]}.{rpc[1]} ({rpc[2]})")
else:
    results.append(f"Error: {resp.text}")
results.append("")

# 7. Lister les RPCs storyboard
results.append("7. RPCS STORYBOARD")
results.append("-" * 80)
sql = """
SELECT routine_schema, routine_name, routine_type
FROM information_schema.routines
WHERE routine_schema = 'app' AND routine_name LIKE '%storyboard%'
ORDER BY routine_name;
"""
resp = requests.post(rpc_url, headers=headers, json={"p_sql": sql}, timeout=30)
results.append(f"STATUS: {resp.status_code}")
if resp.status_code == 200:
    data = resp.json()
    rpcs = data.get('data', [])
    results.append(f"RPCs trouvées: {len(rpcs)}")
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

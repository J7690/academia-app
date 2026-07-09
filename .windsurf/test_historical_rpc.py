#!/usr/bin/env python3
"""Test Historical RPC - Verify RPC layer works"""
import requests
from datetime import datetime

url = "https://thevdfcwlcqzdoybfvgs.supabase.co"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json",
}

OUTPUT_FILE = "c:\\Users\\fasop\\AndroidStudioProjects\\academia\\.windsurf\\test_historical_rpc_output.txt"

results = []
results.append("=" * 80)
results.append("TEST HISTORICAL RPC - VERIFY RPC LAYER")
results.append(datetime.now().isoformat())
results.append("=" * 80)
results.append("")

# 1. Tester app_student_get_credit_balance (RPC historique)
results.append("1. TEST RPC HISTORIQUE: app_student_get_credit_balance")
results.append("-" * 80)
rpc_url = f"{url}/rest/v1/rpc/app_student_get_credit_balance"
resp = requests.post(rpc_url, headers=headers, json={"p_student_id": "test"}, timeout=30)
results.append(f"STATUS: {resp.status_code}")
results.append(f"BODY: {resp.text[:500]}")
results.append("")

# 2. Tester admin_execute_sql via RPC direct
results.append("2. TEST RPC DIRECT: admin_execute_sql")
results.append("-" * 80)
rpc_url = f"{url}/rest/v1/rpc/admin_execute_sql"
resp = requests.post(rpc_url, headers=headers, json={"p_sql": "SELECT 1"}, timeout=30)
results.append(f"STATUS: {resp.status_code}")
results.append(f"BODY: {resp.text[:500]}")
results.append("")

# 3. Tester via REST API direct (sans RPC)
results.append("3. TEST REST API DIRECT")
results.append("-" * 80)
rest_url = f"{url}/rest/v1/students"
resp = requests.get(rest_url, headers=headers, timeout=30)
results.append(f"STATUS: {resp.status_code}")
results.append(f"BODY: {resp.text[:500]}")
results.append("")

# 4. Vérifier si admin_execute_sql existe dans pg_proc
results.append("4. VÉRIFICATION PG_PROC")
results.append("-" * 80)
rpc_url = f"{url}/rest/v1/rpc/admin_execute_sql"
sql = """
SELECT proname, pronamespace, nspname
FROM pg_proc
JOIN pg_namespace ON pg_proc.pronamespace = pg_namespace.oid
WHERE proname = 'admin_execute_sql';
"""
resp = requests.post(rpc_url, headers=headers, json={"p_sql": sql}, timeout=30)
results.append(f"STATUS: {resp.status_code}")
results.append(f"BODY: {resp.text[:500]}")
results.append("")

# 5. Vérifier si admin_execute_sql existe dans tous les schémas
results.append("5. VÉRIFICATION TOUS SCHÉMAS")
results.append("-" * 80)
sql = """
SELECT routine_schema, routine_name
FROM information_schema.routines
WHERE routine_name = 'admin_execute_sql';
"""
resp = requests.post(rpc_url, headers=headers, json={"p_sql": sql}, timeout=30)
results.append(f"STATUS: {resp.status_code}")
results.append(f"BODY: {resp.text[:500]}")
results.append("")

# Sauvegarder les résultats
with open(OUTPUT_FILE, 'w') as f:
    f.write('\n'.join(results))

print("TEST TERMINÉ")
print(f"Résultats sauvegardés dans: {OUTPUT_FILE}")

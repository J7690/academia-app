import requests
import os

url = "https://thevdfcwlcqzdoybfvgs.supabase.co"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json",
}

print("=" * 80)
print("LOT 1 - DÉPLOIEMENT SUPABASE - PHASE D.5")
print("=" * 80)

# 1. Déployer la migration (tables)
print("\n1. Déploiement des tables whiteboard...")
with open('../supabase/migrations/20260623000001_create_whiteboard_tables.sql', 'r') as f:
    sql_tables = f.read()

rpc_url = f"{url}/rest/v1/rpc/admin_execute_sql"
resp = requests.post(rpc_url, headers=headers, json={"p_sql": sql_tables}, timeout=30)
print(f"STATUS: {resp.status_code}")
print(f"BODY: {resp.text}")

# 2. Déployer les RPCs worker
print("\n2. Déploiement des RPCs worker...")
with open('sql_changes/change_20260623_whiteboard_worker_rpcs.sql', 'r') as f:
    sql_worker_rpcs = f.read()

resp = requests.post(rpc_url, headers=headers, json={"p_sql": sql_worker_rpcs}, timeout=30)
print(f"STATUS: {resp.status_code}")
print(f"BODY: {resp.text}")

# 3. Déployer les RPCs editor
print("\n3. Déploiement des RPCs editor...")
with open('sql_changes/change_20260624_whiteboard_editor_rpcs.sql', 'r') as f:
    sql_editor_rpcs = f.read()

resp = requests.post(rpc_url, headers=headers, json={"p_sql": sql_editor_rpcs}, timeout=30)
print(f"STATUS: {resp.status_code}")
print(f"BODY: {resp.text}")

print("\n" + "=" * 80)
print("LOT 1 TERMINÉ")
print("=" * 80)

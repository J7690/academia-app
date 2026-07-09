"""
Phase C.3H – Storyboard Serialization Trace
Trace le cycle complet du Storyboard : Supabase → RPC → Worker → Renderer
"""

import requests
import json

admin_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

def execute_sql(sql):
    resp = requests.post(admin_url, headers=headers, json={"p_sql": sql}, timeout=30)
    return resp.json()

print("=== PHASE C.3H – STORYBOARD SERIALIZATION TRACE ===\n")

# 1. Vérifier le Storyboard stocké dans la table
print("1. STORYBOARD STOCKÉ DANS LA TABLE")
render_id = "5ab36d99-05df-40d6-8a7b-dfe6dc89de6c"
sql = f"""
SELECT wp.storyboard_json, pg_typeof(wp.storyboard_json) as type
FROM app.whiteboard_renders wr
JOIN app.whiteboard_projects wp ON wr.project_id = wp.id
WHERE wr.id = '{render_id}';
"""
result = execute_sql(sql)
print(f"   Résultat : {result}")
print()

# 2. Vérifier ce que retourne la RPC
print("2. RPC whiteboard_fetch_queued_jobs")
rpc_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/whiteboard_fetch_queued_jobs"
resp = requests.post(rpc_url, headers=headers, json={"p_limit": 1}, timeout=30)
print(f"   Status : {resp.status_code}")
if resp.status_code == 200:
    rpc_result = resp.json()
    print(f"   Résultat RPC : {json.dumps(rpc_result, indent=2)[:1000]}")
    if rpc_result and len(rpc_result) > 0:
        storyboard = rpc_result[0].get("storyboard")
        print(f"   Type storyboard : {type(storyboard)}")
        print(f"   Valeur storyboard : {str(storyboard)[:200]}")
print()

# 3. Simuler ce que fait le worker
print("3. SIMULATION WORKER (resp.json())")
if resp.status_code == 200:
    worker_result = resp.json()
    if worker_result and len(worker_result) > 0:
        storyboard_from_worker = worker_result[0].get("storyboard")
        print(f"   Type après resp.json() : {type(storyboard_from_worker)}")
        print(f"   Valeur après resp.json() : {str(storyboard_from_worker)[:200]}")
print()

print("=== TRACE TERMINÉ ===\n")

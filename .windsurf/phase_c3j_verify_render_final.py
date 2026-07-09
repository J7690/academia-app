"""
Phase C.3J – Verify Render Final
Vérifie les données du render job via admin_execute_sql
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

print("=== PHASE C.3J – VÉRIFICATION RENDER FINAL ===\n")

# Vérifier le statut du job traité
render_id = "5ab36d99-05df-40d6-8a7b-dfe6dc89de6c"
sql = f"""
SELECT id, status, video_url, duration_ms, error_message, created_at, completed_at
FROM app.whiteboard_renders
WHERE id = '{render_id}';
"""
result = execute_sql(sql)
print(f"Statut render job 5ab36d99-05df-40d6-8a7b-dfe6dc89de6c :")
print(f"   {json.dumps(result, indent=2)}")
print()

# Vérifier le statut du nouveau job
render_id_new = "fd9e3969-be64-45a9-8e95-00606ac51446"
sql = f"""
SELECT id, status, video_url, duration_ms, error_message, created_at, completed_at
FROM app.whiteboard_renders
WHERE id = '{render_id_new}';
"""
result = execute_sql(sql)
print(f"Statut nouveau render job fd9e3969-be64-45a9-8e95-00606ac51446 :")
print(f"   {json.dumps(result, indent=2)}")
print()

print("=== VÉRIFICATION TERMINÉ ===\n")

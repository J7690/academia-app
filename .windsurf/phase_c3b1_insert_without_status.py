"""
Phase C.3B.1 – Insert Without Status
Teste l'insertion sans spécifier le status
"""

import requests
import uuid

admin_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=== INSERT WITHOUT STATUS ===\n")

project_id = "c2ae6bd1-5022-4d85-bac2-4fdbceae91e9"
render_id = str(uuid.uuid4())

# Essayer sans spécifier status (devrait utiliser le défaut)
sql_render = f"""
INSERT INTO app.whiteboard_renders (id, project_id)
VALUES ('{render_id}', '{project_id}');
"""

print(f"Insertion sans status...")
resp = requests.post(admin_url, headers=headers, json={"p_sql": sql_render}, timeout=30)
print(f"   Status : {resp.status_code}")
print(f"   Résultat : {resp.json()}")

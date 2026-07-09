"""
Phase C.3B.1 – Check Job Exists
Vérifie si le job 4082281a-b8a2-4ed2-88fe-98df8c5d7301 existe
"""

import requests

admin_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=== CHECK JOB EXISTS ===\n")

job_id = "4082281a-b8a2-4ed2-88fe-98df8c5d7301"

sql = f"""
SELECT id, project_id, status, created_at
FROM app.whiteboard_renders
WHERE id = '{job_id}';
"""

print(f"Vérification du job {job_id}...")
resp = requests.post(admin_url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"Status : {resp.status_code}")
print(f"Résultat : {resp.json()}")

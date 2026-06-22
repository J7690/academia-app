import requests

url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=== PHASE C: AUDIT CRÉATION JOBS - TYPES DE JOBS ===\n")

# 1. Tous les types de jobs créés
sql1 = "SELECT job_type, COUNT(*) as count FROM app.video_processing_jobs GROUP BY job_type"
resp1 = requests.post(url, headers=headers, json={"p_sql": sql1}, timeout=30)
print('TYPES DE JOBS (tous):')
print(resp1.text)
print()

# 2. Jobs par statut et type
sql2 = "SELECT job_type, status, COUNT(*) as count FROM app.video_processing_jobs GROUP BY job_type, status ORDER BY job_type, status"
resp2 = requests.post(url, headers=headers, json={"p_sql": sql2}, timeout=30)
print('JOBS PAR STATUT ET TYPE:')
print(resp2.text)
print()

# 3. Vérifier si le type 'transcode_resolution' existe
sql3 = "SELECT * FROM app.video_processing_jobs WHERE job_type = 'transcode_resolution' LIMIT 5"
resp3 = requests.post(url, headers=headers, json={"p_sql": sql3}, timeout=30)
print('JOBS TYPE=transcode_resolution:')
print(resp3.text)
print()

# 4. Jobs récents avec leur payload
sql4 = "SELECT id, job_type, status, created_at, updated_at, payload FROM app.video_processing_jobs ORDER BY created_at DESC LIMIT 5"
resp4 = requests.post(url, headers=headers, json={"p_sql": sql4}, timeout=30)
print('JOBS RÉCENTS AVEC PAYLOAD:')
print(resp4.text)
print()

import requests

url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=== PHASE C: VALIDATION QUEUE video_processing_jobs ===\n")

# 1. Répartition par status
sql1 = "SELECT status, COUNT(*) as count FROM app.video_processing_jobs GROUP BY status"
resp1 = requests.post(url, headers=headers, json={"p_sql": sql1}, timeout=30)
print('RÉPARTITION PAR STATUS:')
print(resp1.text)
print()

# 2. Job le plus ancien
sql2 = "SELECT id, job_type, status, created_at FROM app.video_processing_jobs ORDER BY created_at ASC LIMIT 1"
resp2 = requests.post(url, headers=headers, json={"p_sql": sql2}, timeout=30)
print('JOB LE PLUS ANCIEN:')
print(resp2.text)
print()

# 3. Job le plus récent
sql3 = "SELECT id, job_type, status, created_at FROM app.video_processing_jobs ORDER BY created_at DESC LIMIT 1"
resp3 = requests.post(url, headers=headers, json={"p_sql": sql3}, timeout=30)
print('JOB LE PLUS RÉCENT:')
print(resp3.text)
print()

# 4. Types de jobs
sql4 = "SELECT job_type, COUNT(*) as count FROM app.video_processing_jobs GROUP BY job_type"
resp4 = requests.post(url, headers=headers, json={"p_sql": sql4}, timeout=30)
print('TYPES DE JOBS:')
print(resp4.text)
print()

# 5. Jobs par status et type
sql5 = "SELECT status, job_type, COUNT(*) as count FROM app.video_processing_jobs GROUP BY status, job_type ORDER BY status, job_type"
resp5 = requests.post(url, headers=headers, json={"p_sql": sql5}, timeout=30)
print('JOBS PAR STATUS ET TYPE:')
print(resp5.text)
print()

# 6. Ancienneté des jobs queued
sql6 = "SELECT MIN(created_at) as oldest_queued, MAX(created_at) as newest_queued, COUNT(*) as queued_count FROM app.video_processing_jobs WHERE status = 'queued'"
resp6 = requests.post(url, headers=headers, json={"p_sql": sql6}, timeout=30)
print('ANCIENNETÉ JOBS QUEUED:')
print(resp6.text)
print()

# 7. Jobs failed
sql7 = "SELECT COUNT(*) as failed_count FROM app.video_processing_jobs WHERE status = 'failed'"
resp7 = requests.post(url, headers=headers, json={"p_sql": sql7}, timeout=30)
print('JOBS FAILED:')
print(resp7.text)
print()

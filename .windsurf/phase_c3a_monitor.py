"""
Script pour Phase C.3A – Real Pipeline Validation
Surveille le traitement d'un RenderJob en temps réel
"""

import requests
import time
import sys

# Configuration
admin_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

def execute_sql(sql):
    resp = requests.post(admin_url, headers=headers, json={"p_sql": sql}, timeout=30)
    return resp.json()

def get_job_status(job_id):
    sql = f"""
    SELECT status, video_url, duration_ms, error_message, started_at, completed_at
    FROM app.whiteboard_renders
    WHERE id = '{job_id}';
    """
    result = execute_sql(sql)
    if result and len(result) > 0:
        return result[0]
    return None

# Récupérer le job_id depuis les arguments
if len(sys.argv) > 1:
    job_id = sys.argv[1]
else:
    # Sinon, récupérer le job le plus récent
    sql = """
    SELECT id FROM app.whiteboard_renders 
    ORDER BY created_at DESC 
    LIMIT 1;
    """
    result = execute_sql(sql)
    if result and len(result) > 0:
        job_id = result[0].get("id")
    else:
        print("Aucun job trouvé")
        sys.exit(1)

print(f"=== PHASE C.3A – SURVEILLANCE RENDERJOB ===\n")
print(f"Job ID : {job_id}\n")

# Surveiller le job
print("Surveillance du traitement (timeout 120 secondes)...\n")

start_time = time.time()
last_status = None

while True:
    job = get_job_status(job_id)
    
    if not job:
        print(f"❌ Job non trouvé : {job_id}")
        break
    
    status = job.get("status")
    
    if status != last_status:
        print(f"[{int(time.time() - start_time)}s] Statut : {status}")
        last_status = status
    
    if status == "done":
        print("\n✅ VALIDATION RÉUSSIE !")
        print(f"   video_url : {job.get('video_url')}")
        print(f"   duration_ms : {job.get('duration_ms')}")
        print(f"   started_at : {job.get('started_at')}")
        print(f"   completed_at : {job.get('completed_at')}")
        
        # Calculer la durée réelle
        if job.get('started_at') and job.get('completed_at'):
            from datetime import datetime
            started = datetime.fromisoformat(job['started_at'].replace('Z', '+00:00'))
            completed = datetime.fromisoformat(job['completed_at'].replace('Z', '+00:00'))
            duration = (completed - started).total_seconds()
            print(f"   Durée réelle : {duration:.2f}s")
        
        break
    elif status == "failed":
        print("\n❌ VALIDATION ÉCHOUÉE !")
        print(f"   error_message : {job.get('error_message')}")
        break
    
    # Timeout
    if time.time() - start_time > 120:
        print("\n⏱️ TIMEOUT : Le job n'a pas été traité dans les 120 secondes")
        break
    
    time.sleep(1)

print("\n=== FIN SURVEILLANCE ===\n")

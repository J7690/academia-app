#!/usr/bin/env python3
"""
Phase C.3B – Monitor Worker Logs on Kamatera
Surveille les logs du worker en temps réel pour déterminer les problèmes et la progression
"""

import paramiko
import time

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('185.167.97.144', username='root', password='Nexiomgroup@Academia0', timeout=15)

print("=== PHASE C.3B – SURVEILLANCE LOGS WORKER ===\n")

# Vérifier si le worker tourne
print("1. Vérification processus worker...")
stdin, stdout, stderr = client.exec_command('ps aux | grep whiteboard_render_worker | grep -v grep 2>&1')
ps_result = stdout.read().decode().strip()
print(f"   Processus : {ps_result if ps_result else 'AUCUN'}")
print()

# Vérifier les logs existants
print("2. Logs du worker...")
stdin, stdout, stderr = client.exec_command('cat /opt/whiteboard-worker/worker.log 2>&1')
logs = stdout.read().decode().strip()
print(f"   Logs :")
print(f"   {logs}")
print()

# Vérifier les erreurs potentielles
print("3. Vérification erreurs...")
if "Traceback" in logs or "Error" in logs or "Exception" in logs:
    print("   ⚠️ ERREURS DÉTECTÉES DANS LES LOGS")
    # Extraire les lignes d'erreur
    error_lines = [line for line in logs.split('\n') if 'Traceback' in line or 'Error' in line or 'Exception' in line]
    for line in error_lines:
        print(f"   {line}")
else:
    print("   ✅ Aucune erreur détectée")
print()

# Vérifier la progression
print("4. Vérification progression...")
if "Found" in logs and "queued job" in logs:
    print("   ✅ Worker détecte les jobs")
if "Processing job" in logs:
    print("   ✅ Worker traite un job")
if "Generating PNGs" in logs:
    print("   ✅ Génération PNGs en cours")
if "Assembling MP4" in logs:
    print("   ✅ Assemblage MP4 en cours")
if "Uploading MP4" in logs:
    print("   ✅ Upload en cours")
if "completed successfully" in logs:
    print("   ✅ Job terminé avec succès")
if "failed" in logs:
    print("   ❌ Job échoué")
print()

# Vérifier le statut du job dans Supabase
print("5. Vérification statut job dans Supabase...")
job_id = "4082281a-b8a2-4ed2-88fe-98df8c5d7301"
import requests
admin_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

sql_check = f"""
SELECT status, video_url, duration_ms, error_message, started_at, completed_at
FROM app.whiteboard_renders
WHERE id = '{job_id}';
"""

resp = requests.post(admin_url, headers=headers, json={"p_sql": sql_check}, timeout=30)
result = resp.json()

if result and len(result) > 0:
    job = result[0]
    print(f"   Statut : {job.get('status')}")
    print(f"   video_url : {job.get('video_url')}")
    print(f"   duration_ms : {job.get('duration_ms')}")
    print(f"   error_message : {job.get('error_message')}")
    print(f"   started_at : {job.get('started_at')}")
    print(f"   completed_at : {job.get('completed_at')}")
else:
    print(f"   Job non trouvé dans Supabase")
print()

client.close()

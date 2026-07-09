#!/usr/bin/env python3
"""
Phase C.3B – Quick Execute
Lance le worker et surveille les logs en une seule commande
"""

import paramiko
import time
import requests

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('185.167.97.144', username='root', password='Nexiomgroup@Academia0', timeout=15)

print("=== PHASE C.3B – EXÉCUTION RAPIDE ===\n")

# Job ID
job_id = "4082281a-b8a2-4ed2-88fe-98df8c5d7301"

# 1. Lancer le worker
print("1. Lancement worker...")
stdin, stdout, stderr = client.exec_command('cd /opt/whiteboard-worker && python3 whiteboard_render_worker.py > worker.log 2>&1 &')
print("   Worker lancé")
print()

# 2. Attendre et surveiller
print("2. Surveillance (30 secondes)...")
for i in range(30):
    time.sleep(1)
    
    # Vérifier les logs
    stdin, stdout, stderr = client.exec_command('tail -5 /opt/whiteboard-worker/worker.log 2>&1')
    logs = stdout.read().decode().strip()
    
    if logs:
        print(f"   [{i}s] {logs[-100:]}")
    
    # Vérifier le statut du job
    admin_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
    headers = {
        "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
        "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
        "Content-Type": "application/json"
    }
    
    sql_check = f"SELECT status FROM app.whiteboard_renders WHERE id = '{job_id}';"
    resp = requests.post(admin_url, headers=headers, json={"p_sql": sql_check}, timeout=10)
    result = resp.json()
    
    if result and len(result) > 0:
        status = result[0].get("status")
        if status in ["done", "failed"]:
            print(f"\n   Statut final : {status}")
            break

print()

# 3. Résultat final
print("3. Résultat final...")
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
else:
    print("   Job non trouvé")

print()

# 4. Logs complets
print("4. Logs complets...")
stdin, stdout, stderr = client.exec_command('cat /opt/whiteboard-worker/worker.log 2>&1')
logs = stdout.read().decode().strip()
print(f"   {logs}")

client.close()

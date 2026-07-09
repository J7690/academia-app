#!/usr/bin/env python3
"""
Phase C.3B.1 – Redeploy Fixed Worker
Redéploie le worker corrigé (schema app) sur Kamatera
"""

import paramiko

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('185.167.97.144', username='root', password='Nexiomgroup@Academia0', timeout=15)

print("=== PHASE C.3B.1 – REDÉPLOIEMENT WORKER CORRIGÉ ===\n")

# Upload du fichier corrigé
print("1. Upload whiteboard_render_worker.py corrigé...")
sftp = client.open_sftp()
sftp.put(r"c:\Users\fasop\AndroidStudioProjects\academia\academia_bobodo_backend\whiteboard_render_worker.py", "/opt/whiteboard-worker/whiteboard_render_worker.py")
sftp.close()
print("   Upload terminé")
print()

# Vérifier le fichier
print("2. Vérification fichier...")
stdin, stdout, stderr = client.exec_command('cat /opt/whiteboard-worker/whiteboard_render_worker.py | grep -A 2 "_fetch_queued_jobs" 2>&1')
check = stdout.read().decode().strip()
print(f"   {check}")
print()

client.close()

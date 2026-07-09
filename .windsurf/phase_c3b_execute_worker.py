#!/usr/bin/env python3
"""
Phase C.3B – Execute Worker on Kamatera
Exécute le worker whiteboard_render_worker.py sur Kamatera via SSH
"""

import paramiko
import time

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('185.167.97.144', username='root', password='Nexiomgroup@Academia0', timeout=15)

print("=== PHASE C.3B – EXÉCUTION WORKER ===\n")

# Exécuter le worker en arrière-plan
print("Lancement du worker sur Kamatera...")
stdin, stdout, stderr = client.exec_command('cd /opt/whiteboard-worker && nohup python3 whiteboard_render_worker.py > worker.log 2>&1 &')
result = stdout.read().decode().strip()
print(f"Résultat : {result}")
print()

# Attendre un peu pour que le worker démarre
time.sleep(3)

# Vérifier que le worker tourne
print("Vérification processus worker...")
stdin, stdout, stderr = client.exec_command('ps aux | grep whiteboard_render_worker | grep -v grep 2>&1')
ps_result = stdout.read().decode().strip()
print(f"Processus : {ps_result}")
print()

# Vérifier les logs
print("Logs du worker (premières lignes)...")
stdin, stdout, stderr = client.exec_command('tail -20 /opt/whiteboard-worker/worker.log 2>&1')
logs = stdout.read().decode().strip()
print(f"Logs : {logs}")
print()

print("=== WORKER LANCÉ ===")
print("Surveiller avec : python .windsurf/phase_c3a_monitor.py 4082281a-b8a2-4ed2-88fe-98df8c5d7301")
print()

client.close()

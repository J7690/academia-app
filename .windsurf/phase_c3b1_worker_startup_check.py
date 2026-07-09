#!/usr/bin/env python3
"""
Phase C.3B.1 – Worker Startup Check
Vérifie que le worker démarre réellement
"""

import paramiko
import time

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('185.167.97.144', username='root', password='Nexiomgroup@Academia0', timeout=15)

print("=== PHASE C.3B.1 – WORKER STARTUP CHECK ===\n")

# 1. Tuer tout worker existant
print("1. Nettoyage workers existants...")
stdin, stdout, stderr = client.exec_command('pkill -f whiteboard_render_worker 2>&1')
kill_result = stdout.read().decode().strip()
print(f"   Résultat : {kill_result if kill_result else 'Aucun worker tué'}")
print()

# 2. Lancer le worker en foreground pour voir les logs
print("2. Lancement worker (foreground, 10 secondes)...")
stdin, stdout, stderr = client.exec_command('cd /opt/whiteboard-worker && timeout 10 python3 whiteboard_render_worker.py 2>&1', get_pty=True)

# Attendre 10 secondes
time.sleep(10)

# Lire les logs
logs = stdout.read().decode().strip()
print(f"   Logs :")
print(f"   {logs}")
print()

# 3. Vérifier les processus
print("3. Vérification processus...")
stdin, stdout, stderr = client.exec_command('ps aux | grep whiteboard_render_worker | grep -v grep 2>&1')
ps_result = stdout.read().decode().strip()
print(f"   Processus : {ps_result if ps_result else 'Aucun'}")
print()

client.close()

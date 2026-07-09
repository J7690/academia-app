#!/usr/bin/env python3
"""
Phase C.3J – Execute Worker Full
Exécute le worker sur Kamatera pour traiter le nouveau job queued
"""

import paramiko

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('185.167.97.144', username='root', password='Nexiomgroup@Academia0', timeout=15)

print("=== PHASE C.3J – EXÉCUTION WORKER FULL ===\n")

# Exécuter le worker en mode unique
print("Exécution worker (mode unique)...")
stdin, stdout, stderr = client.exec_command('cd /opt/whiteboard-worker && WORKER_LOOP=0 python3 whiteboard_render_worker.py 2>&1')
result = stdout.read().decode().strip()
print(f"Résultat :")
print(f"{result}")
print()

client.close()

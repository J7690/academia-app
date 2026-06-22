#!/usr/bin/env python3
import paramiko

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('185.167.97.144', username='root', password='Nexiomgroup@Academia0', timeout=15)

print("=== PHASE D: LOGS WORKER COMPLETS (Dernière heure) ===\n")

# Logs complets de la dernière heure
stdin, stdout, stderr = client.exec_command('journalctl -u video-worker.service --since "1 hour ago" --no-pager')
logs_1h = stdout.read().decode().strip()
print('LOGS 1 HEURE COMPLETS:')
print(logs_1h)
print()

client.close()

#!/usr/bin/env python3
import paramiko

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('185.167.97.144', username='root', password='Nexiomgroup@Academia0', timeout=15)

print("=== PHASE D: AUDIT WORKER KAMATERA (24 HEURES) ===\n")

# 1. Logs 24 heures complets
stdin, stdout, stderr = client.exec_command('journalctl -u video-worker.service --since "24 hours ago" --no-pager')
logs_24h = stdout.read().decode().strip()
print('LOGS 24 HEURES:')
print(logs_24h[:10000])
print()

# 2. Logs avec filtre "job" pour voir les jobs traités
stdin, stdout, stderr = client.exec_command('journalctl -u video-worker.service --since "24 hours ago" --no-pager | grep -i job')
logs_jobs = stdout.read().decode().strip()
print('LOGS AVEC FILTRE "JOB":')
print(logs_jobs[:5000])
print()

# 3. Logs avec filtre "done" pour voir les jobs réussis
stdin, stdout, stderr = client.exec_command('journalctl -u video-worker.service --since "24 hours ago" --no-pager | grep -i done')
logs_done = stdout.read().decode().strip()
print('LOGS AVEC FILTRE "DONE":')
print(logs_done[:5000])
print()

# 4. Logs avec filtre "error" pour voir les erreurs
stdin, stdout, stderr = client.exec_command('journalctl -u video-worker.service --since "24 hours ago" --no-pager | grep -i error')
logs_error = stdout.read().decode().strip()
print('LOGS AVEC FILTRE "ERROR":')
print(logs_error[:5000])
print()

client.close()

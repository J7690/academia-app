#!/usr/bin/env python3
import paramiko

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('185.167.97.144', username='root', password='Nexiomgroup@Academia0', timeout=15)

print("=== PHASE D: LOGS WORKER ===\n")

# 1. Logs du service systemd (1 heure)
stdin, stdout, stderr = client.exec_command('journalctl -u video-worker.service --since "1 hour ago" --no-pager')
logs_systemd = stdout.read().decode().strip()
print('SYSTEMD LOGS (1 heure):')
print(logs_systemd[:3000])
print()

# 2. Logs du service systemd (24 heures)
stdin, stdout, stderr = client.exec_command('journalctl -u video-worker.service --since "24 hours ago" --no-pager | tail -100')
logs_systemd_24h = stdout.read().decode().strip()
print('SYSTEMD LOGS (24 heures, tail 100):')
print(logs_systemd_24h[:3000])
print()

# 3. Vérifier le fichier de log du worker s'il existe
stdin, stdout, stderr = client.exec_command('ls -la /opt/video-worker/*.log 2>/dev/null || echo NO_LOG_FILES')
log_files = stdout.read().decode().strip()
print('LOG FILES:')
print(log_files)
print()

client.close()

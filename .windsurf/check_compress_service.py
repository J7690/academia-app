#!/usr/bin/env python3
import paramiko

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('185.167.97.144', username='root', password='Nexiomgroup@Academia0', timeout=15)

print("=== LOGS SERVICE COMPRESS ===\n")

# Vérifier les logs du service
stdin, stdout, stderr = client.exec_command('journalctl -u academia-compress -n 50 --no-pager')
logs = stdout.read().decode()
print(logs)

client.close()

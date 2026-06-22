#!/usr/bin/env python3
import paramiko

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('185.167.97.144', username='root', password='Nexiomgroup@Academia0', timeout=15)

print("=== OUVERTURE PORT 8001 SUR PARE-FEU ===\n")

# 1. Ouvrir le port 8001 sur ufw
stdin, stdout, stderr = client.exec_command('ufw allow 8001/tcp')
stdout.read()
print("✓ Port 8001 ouvert sur ufw")

# 2. Vérifier le statut ufw
stdin, stdout, stderr = client.exec_command('ufw status')
status = stdout.read().decode()
print("\n=== STATUT UFW ===")
print(status)

client.close()
print("\n=== TERMINÉ ===")

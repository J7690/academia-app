#!/usr/bin/env python3
import paramiko

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('185.167.97.144', username='root', password='Nexiomgroup@Academia0', timeout=15)

print("=== DIAGNOSTIC PYTHON ===\n")

# Vérifier quel Python est utilisé
stdin, stdout, stderr = client.exec_command('which python3 && python3 --version')
result = stdout.read().decode()
print(f"Python: {result}")

# Vérifier si Flask est installé pour python3
stdin, stdout, stderr = client.exec_command('python3 -c "import flask; print(flask.__version__)"')
result = stdout.read().decode()
print(f"Flask check: {result}")

# Vérifier les logs récents
stdin, stdout, stderr = client.exec_command('journalctl -u academia-compress -n 10 --no-pager')
logs = stdout.read().decode()
print(f"\nLogs récents:\n{logs}")

client.close()

#!/usr/bin/env python3
import paramiko

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('185.167.97.144', username='root', password='Nexiomgroup@Academia0', timeout=15)

print("=== INSTALLATION FLASK V2 ===\n")

# Arrêter le service
stdin, stdout, stderr = client.exec_command('systemctl stop academia-compress')
stdout.read()
print("✓ Service arrêté")

# Installer Flask avec pip (pas pip3)
stdin, stdout, stderr = client.exec_command('pip install flask requests')
stdout.read()
print("✓ Flask et requests installés avec pip")

# Vérifier l'installation
stdin, stdout, stderr = client.exec_command('python3 -m pip list | grep -i flask')
result = stdout.read().decode()
print(f"✓ Flask installé: {result}")

# Tester l'import
stdin, stdout, stderr = client.exec_command('python3 -c "import flask; print(flask.__version__)"')
result = stdout.read().decode()
print(f"✓ Flask import test: {result}")

# Redémarrer le service
stdin, stdout, stderr = client.exec_command('systemctl start academia-compress')
stdout.read()
print("✓ Service démarré")

# Attendre un peu et vérifier le statut
import time
time.sleep(3)

stdin, stdout, stderr = client.exec_command('systemctl status academia-compress')
status = stdout.read().decode()
print("\n=== STATUT SERVICE ===")
print(status[:500])

client.close()
print("\n=== INSTALLATION TERMINÉE ===")

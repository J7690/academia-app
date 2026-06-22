#!/usr/bin/env python3
import paramiko

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('185.167.97.144', username='root', password='Nexiomgroup@Academia0', timeout=15)

print("=== INSTALLATION FLASK MANUELLE ===\n")

# Arrêter le service
stdin, stdout, stderr = client.exec_command('systemctl stop academia-compress')
stdout.read()
print("✓ Service arrêté")

# Installer Flask
stdin, stdout, stderr = client.exec_command('pip3 install flask requests')
stdout.read()
print("✓ Flask et requests installés")

# Vérifier l'installation
stdin, stdout, stderr = client.exec_command('pip3 list | grep -i flask')
result = stdout.read().decode()
print(f"✓ Flask installé: {result}")

# Redémarrer le service
stdin, stdout, stderr = client.exec_command('systemctl start academia-compress')
stdout.read()
print("✓ Service démarré")

# Vérifier le statut
stdin, stdout, stderr = client.exec_command('systemctl status academia-compress')
status = stdout.read().decode()
print("\n=== STATUT SERVICE ===")
print(status[:500])

client.close()
print("\n=== INSTALLATION TERMINÉE ===")

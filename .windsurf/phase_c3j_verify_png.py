#!/usr/bin/env python3
"""
Phase C.3J – Verify PNG
Vérifie les PNG générés sur Kamatera
"""

import paramiko

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('185.167.97.144', username='root', password='Nexiomgroup@Academia0', timeout=15)

print("=== PHASE C.3J – VÉRIFICATION PNG ===\n")

# Vérifier les fichiers PNG temporaires
print("1. Vérification fichiers PNG temporaires...")
stdin, stdout, stderr = client.exec_command('ls -la /tmp/tmp*/scene_*.png 2>&1')
result = stdout.read().decode().strip()
print(f"   Fichiers PNG :")
print(f"   {result}")
print()

# Vérifier le nombre de PNG
print("2. Nombre de PNG...")
stdin, stdout, stderr = client.exec_command('ls -la /tmp/tmp*/scene_*.png 2>&1 | wc -l')
count = stdout.read().decode().strip()
print(f"   Nombre de PNG : {count}")
print()

# Vérifier la résolution d'un PNG
print("3. Résolution PNG...")
stdin, stdout, stderr = client.exec_command('identify /tmp/tmp*/scene_001.png 2>&1')
result = stdout.read().decode().strip()
print(f"   Résolution : {result}")
print()

client.close()

#!/usr/bin/env python3
"""
Phase C.3H – Check Renderer Version
Vérifie la version du renderer déployé sur Kamatera
"""

import paramiko

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('185.167.97.144', username='root', password='Nexiomgroup@Academia0', timeout=15)

print("=== PHASE C.3H – CHECK RENDERER VERSION ===\n")

# Vérifier les lignes 165-180 du renderer
print("Vérification lignes 165-180 du renderer...")
stdin, stdout, stderr = client.exec_command('sed -n "165,180p" /opt/whiteboard-worker/whiteboard_png_renderer.py 2>&1')
result = stdout.read().decode().strip()
print(f"   Résultat :")
print(f"   {result}")
print()

client.close()

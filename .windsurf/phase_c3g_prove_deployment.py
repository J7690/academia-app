#!/usr/bin/env python3
"""
Phase C.3G – Prove Deployment
Prouve le déploiement du worker sur Kamatera
"""

import paramiko

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('185.167.97.144', username='root', password='Nexiomgroup@Academia0', timeout=15)

print("=== PHASE C.3G – PREUVE DÉPLOIEMENT ===\n")

# 1. Vérifier les fichiers
print("1. VÉRIFICATION FICHIERS")
fichiers = [
    "/opt/whiteboard-worker/whiteboard_render_worker.py",
    "/opt/whiteboard-worker/whiteboard_png_renderer.py",
    "/opt/whiteboard-worker/whiteboard_ffmpeg_assembler.py",
    "/opt/whiteboard-worker/whiteboard_upload_renderer.py",
    "/opt/whiteboard-worker/.env",
]

for fichier in fichiers:
    stdin, stdout, stderr = client.exec_command(f'ls -la {fichier} 2>&1')
    result = stdout.read().decode().strip()
    print(f"   {fichier} :")
    print(f"   {result}")
    print()

# 2. Calculer les hash
print("2. CALCUL HASH MD5")
for fichier in fichiers:
    stdin, stdout, stderr = client.exec_command(f'md5sum {fichier} 2>&1')
    result = stdout.read().decode().strip()
    print(f"   {fichier} :")
    print(f"   {result}")
    print()

client.close()

#!/usr/bin/env python3
"""
Phase C.3J – Redeploy Renderer
Redéploie whiteboard_png_renderer.py corrigé sur Kamatera
"""

import paramiko

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('185.167.97.144', username='root', password='Nexiomgroup@Academia0', timeout=15)

print("=== PHASE C.3J – REDÉPLOIEMENT RENDERER ===\n")

# Upload du fichier corrigé
print("1. Upload whiteboard_png_renderer.py corrigé...")
sftp = client.open_sftp()
sftp.put(r"c:\Users\fasop\AndroidStudioProjects\academia\academia_bobodo_backend\whiteboard_png_renderer.py", "/opt/whiteboard-worker/whiteboard_png_renderer.py")
sftp.close()
print("   Upload terminé")
print()

# Vérifier le fichier
print("2. Vérification fichier...")
stdin, stdout, stderr = client.exec_command('sed -n "175,178p" /opt/whiteboard-worker/whiteboard_png_renderer.py 2>&1')
check = stdout.read().decode().strip()
print(f"   Lignes 175-178 :")
print(f"   {check}")
print()

client.close()

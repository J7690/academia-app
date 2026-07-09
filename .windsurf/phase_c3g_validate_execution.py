#!/usr/bin/env python3
"""
Phase C.3G – Validate Execution
Valide l'exécution du worker sur Kamatera
"""

import paramiko

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('185.167.97.144', username='root', password='Nexiomgroup@Academia0', timeout=15)

print("=== PHASE C.3G – VALIDATION EXÉCUTION ===\n")

# 1. Test d'import des modules
print("1. TEST IMPORT MODULES")
stdin, stdout, stderr = client.exec_command('cd /opt/whiteboard-worker && python3 -c "import whiteboard_render_worker" 2>&1')
result = stdout.read().decode().strip()
print(f"   Import whiteboard_render_worker : {result}")
print()

# 2. Test d'import des dépendances
print("2. TEST IMPORT DÉPENDANCES")
stdin, stdout, stderr = client.exec_command('cd /opt/whiteboard-worker && python3 -c "from whiteboard_png_renderer import render_storyboard_to_pngs; from whiteboard_ffmpeg_assembler import assemble_pngs_to_mp4; from whiteboard_upload_renderer import upload_mp4_to_storage; print(\'OK\')" 2>&1')
result = stdout.read().decode().strip()
print(f"   Import dépendances : {result}")
print()

# 3. Test d'exécution unique (WORKER_LOOP=0)
print("3. TEST EXÉCUTION UNIQUE")
stdin, stdout, stderr = client.exec_command('cd /opt/whiteboard-worker && WORKER_LOOP=0 python3 whiteboard_render_worker.py 2>&1')
result = stdout.read().decode().strip()
print(f"   Exécution unique :")
print(f"   {result}")
print()

client.close()

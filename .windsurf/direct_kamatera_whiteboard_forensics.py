#!/usr/bin/env python3
"""Direct Kamatera Forensics - Smart Whiteboard Components"""
import paramiko
import sys
from datetime import datetime

HOST = "185.167.97.144"
USER = "root"
PASSWORD = "Nexiomgroup@Academia0"

OUTPUT_FILE = "c:\\Users\\fasop\\AndroidStudioProjects\\academia\\.windsurf\\kamatera_whiteboard_forensics_output.txt"

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

try:
    client.connect(HOST, username=USER, password=PASSWORD, timeout=20, banner_timeout=15, auth_timeout=15)
except Exception as e:
    with open(OUTPUT_FILE, 'w') as f:
        f.write(f"CONNEXION SSH ECHOUEE: {e}\n")
    sys.exit(1)

results = []
results.append("=" * 80)
results.append("DIRECT KAMATERA FORENSICS - SMART WHITEBOARD")
results.append(datetime.now().isoformat())
results.append("=" * 80)
results.append(f"IP: {HOST}")
results.append(f"USER: {USER}")
results.append("")

# 1. Rechercher fichiers contenant whiteboard, storyboard, renderer, render_worker
results.append("1. RECHERCHE FICHIERS WHITEBOARD/STORYBOARD/RENDERER/RENDER_WORKER")
results.append("-" * 80)

search_terms = ["whiteboard", "storyboard", "renderer", "render_worker"]
for term in search_terms:
    results.append(f"\n--- Recherche: {term} ---")
    stdin, stdout, stderr = client.exec_command(f"find / -name '*{term}*' 2>/dev/null | head -20")
    output = stdout.read().decode('utf-8')
    error = stderr.read().decode('utf-8')
    if output:
        results.append(f"Fichiers trouvés:\n{output}")
    else:
        results.append(f"Aucun fichier trouvé pour '{term}'")

# 2. Rechercher fichiers Python spécifiques
results.append("\n\n2. RECHERCHE FICHIERS PYTHON SPÉCIFIQUES")
results.append("-" * 80)

python_files = [
    "whiteboard_render_worker.py",
    "whiteboard_png_renderer.py",
    "whiteboard_ffmpeg_assembler.py",
    "whiteboard_upload_renderer.py"
]

for py_file in python_files:
    results.append(f"\n--- Recherche: {py_file} ---")
    stdin, stdout, stderr = client.exec_command(f"find / -name '{py_file}' 2>/dev/null")
    output = stdout.read().decode('utf-8')
    if output:
        results.append(f"Trouvé: {output.strip()}")
        # Obtenir métadonnées
        stdin, stdout, stderr = client.exec_command(f"ls -la {output.strip()} 2>/dev/null")
        ls_output = stdout.read().decode('utf-8')
        results.append(f"Détails: {ls_output}")
        # Obtenir hash
        stdin, stdout, stderr = client.exec_command(f"md5sum {output.strip()} 2>/dev/null")
        hash_output = stdout.read().decode('utf-8')
        results.append(f"MD5: {hash_output.strip()}")
    else:
        results.append(f"Non trouvé: {py_file}")

# 3. Vérifier processus actifs
results.append("\n\n3. PROCESSUS ACTIFS")
results.append("-" * 80)

for term in search_terms:
    stdin, stdout, stderr = client.exec_command(f"ps aux | grep -i '{term}' | grep -v grep")
    output = stdout.read().decode('utf-8')
    if output:
        results.append(f"Processus '{term}':\n{output}")
    else:
        results.append(f"Aucun processus pour '{term}'")

# 4. Vérifier services systemd
results.append("\n\n4. SERVICES SYSTEMD")
results.append("-" * 80)

for term in search_terms:
    stdin, stdout, stderr = client.exec_command(f"systemctl list-units --type=service --no-pager | grep -i '{term}'")
    output = stdout.read().decode('utf-8')
    if output:
        results.append(f"Services '{term}':\n{output}")
    else:
        results.append(f"Aucun service pour '{term}'")

# 5. Vérifier conteneurs Docker
results.append("\n\n5. CONTENEURS DOCKER")
results.append("-" * 80)

stdin, stdout, stderr = client.exec_command("docker ps 2>/dev/null || echo 'DOCKER_NOT_AVAILABLE'")
output = stdout.read().decode('utf-8')
results.append(f"Conteneurs actifs:\n{output}")

stdin, stdout, stderr = client.exec_command("docker ps -a 2>/dev/null || echo 'DOCKER_NOT_AVAILABLE'")
output = stdout.read().decode('utf-8')
results.append(f"Tous les conteneurs:\n{output}")

# 6. Vérifier répertoires /opt, /root, /home
results.append("\n\n6. RÉPERTOIires /OPT, /ROOT, /HOME")
results.append("-" * 80)

directories = ["/opt", "/root", "/home"]
for directory in directories:
    results.append(f"\n--- {directory} ---")
    stdin, stdout, stderr = client.exec_command(f"ls -la {directory} 2>/dev/null | head -30")
    output = stdout.read().decode('utf-8')
    results.append(output)

# 7. Vérifier répertoires Academia
results.append("\n\n7. RÉPERTOIires ACADEMIA")
results.append("-" * 80)

stdin, stdout, stderr = client.exec_command("find / -type d -name '*academia*' 2>/dev/null")
output = stdout.read().decode('utf-8')
results.append(f"Répertoires Academia:\n{output}")

# 8. Vérifier répertoires whiteboard
results.append("\n\n8. RÉPERTOIires WHITEBOARD")
results.append("-" * 80)

stdin, stdout, stderr = client.exec_command("find / -type d -name '*whiteboard*' 2>/dev/null")
output = stdout.read().decode('utf-8')
results.append(f"Répertoires whiteboard:\n{output}")

# 9. Vérifier fichiers Python dans /root
results.append("\n\n9. FICHIERS PYTHON DANS /ROOT")
results.append("-" * 80)

stdin, stdout, stderr = client.exec_command("find /root -name '*.py' 2>/dev/null")
output = stdout.read().decode('utf-8')
results.append(f"Fichiers Python dans /root:\n{output}")

# 10. Vérifier fichiers Python dans /opt
results.append("\n\n10. FICHIERS PYTHON DANS /OPT")
results.append("-" * 80)

stdin, stdout, stderr = client.exec_command("find /opt -name '*.py' 2>/dev/null")
output = stdout.read().decode('utf-8')
results.append(f"Fichiers Python dans /opt:\n{output}")

client.close()

# Sauvegarder les résultats
with open(OUTPUT_FILE, 'w') as f:
    f.write('\n'.join(results))

print("FORENSICS TERMINÉE")
print(f"Résultats sauvegardés dans: {OUTPUT_FILE}")

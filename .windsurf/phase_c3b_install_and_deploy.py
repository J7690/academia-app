#!/usr/bin/env python3
"""
Phase C.3B – Install Dependencies and Deploy Components
Installe les dépendances manquantes et déploie les composants whiteboard_*.py sur Kamatera
Utilise le mécanisme SSH déjà disponible dans .windsurf
"""

import paramiko
import os

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('185.167.97.144', username='root', password='Nexiomgroup@Academia0', timeout=15)

print("=== PHASE C.3B – INSTALLATION ET DÉPLOIEMENT ===\n")

# 1. Installer Pillow (avec --break-system-packages pour Ubuntu 24.04)
print("1. Installation Pillow")
stdin, stdout, stderr = client.exec_command('pip3 install --break-system-packages Pillow 2>&1')
pillow_install = stdout.read().decode().strip()
print(f"   Résultat : {pillow_install[-500:]}")
print()

# 2. Installer httpx (avec --break-system-packages pour Ubuntu 24.04)
print("2. Installation httpx")
stdin, stdout, stderr = client.exec_command('pip3 install --break-system-packages httpx 2>&1')
httpx_install = stdout.read().decode().strip()
print(f"   Résultat : {httpx_install[-500:]}")
print()

# 3. Installer python-dotenv (avec --break-system-packages pour Ubuntu 24.04)
print("3. Installation python-dotenv")
stdin, stdout, stderr = client.exec_command('pip3 install --break-system-packages python-dotenv 2>&1')
dotenv_install = stdout.read().decode().strip()
print(f"   Résultat : {dotenv_install[-500:]}")
print()

# 4. Vérifier les installations
print("4. Vérification installations")
stdin, stdout, stderr = client.exec_command('python3 -c "import PIL, httpx, dotenv; print(\'OK\')" 2>&1')
check_install = stdout.read().decode().strip()
print(f"   Vérification : {check_install}")
print()

# 5. Créer le répertoire de déploiement
print("5. Création répertoire de déploiement")
stdin, stdout, stderr = client.exec_command('mkdir -p /opt/whiteboard-worker 2>&1')
mkdir_result = stdout.read().decode().strip()
print(f"   Résultat : {mkdir_result}")
print()

# 6. Upload des fichiers locaux
print("6. Upload fichiers locaux")
local_dir = r"c:\Users\fasop\AndroidStudioProjects\academia\academia_bobodo_backend"
files_to_deploy = [
    "whiteboard_render_worker.py",
    "whiteboard_png_renderer.py",
    "whiteboard_ffmpeg_assembler.py",
    "whiteboard_upload_renderer.py",
]

sftp = client.open_sftp()
for filename in files_to_deploy:
    local_path = os.path.join(local_dir, filename)
    if os.path.exists(local_path):
        print(f"   {filename} : TROUVÉ")
        remote_path = f"/opt/whiteboard-worker/{filename}"
        sftp.put(local_path, remote_path)
        print(f"   {filename} : UPLOADÉ")
    else:
        print(f"   {filename} : NON TROUVÉ")
sftp.close()
print()

# 7. Vérifier les fichiers uploadés
print("7. Vérification fichiers uploadés")
stdin, stdout, stderr = client.exec_command('ls -la /opt/whiteboard-worker/ 2>&1')
ls_result = stdout.read().decode().strip()
print(f"   Contenu /opt/whiteboard-worker/ :")
print(f"   {ls_result}")
print()

# 8. Créer le fichier .env
print("8. Création fichier .env")
env_content = """SUPABASE_URL=https://thevdfcwlcqzdoybfvgs.supabase.co
SUPABASE_SERVICE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM
WORKER_LOOP=1
WORKER_INTERVAL_SECONDS=2
WORKER_MAX_JOBS=1
"""

sftp = client.open_sftp()
with sftp.file('/opt/whiteboard-worker/.env', 'w') as f:
    f.write(env_content)
sftp.close()
print(f"   .env : CRÉÉ")
print()

# 9. Vérifier le fichier .env
print("9. Vérification fichier .env")
stdin, stdout, stderr = client.exec_command('cat /opt/whiteboard-worker/.env 2>&1')
cat_result = stdout.read().decode().strip()
print(f"   Contenu .env :")
print(f"   {cat_result}")
print()

print("=== INSTALLATION ET DÉPLOIEMENT TERMINÉS ===")
print()
print("Prochaine étape :")
print("1. Exécuter python .windsurf/phase_c3a_insert_storyboard.py (en local)")
print("2. Noter le Job ID")
print("3. Exécuter via SSH : cd /opt/whiteboard-worker && python whiteboard_render_worker.py")
print("4. Exécuter python .windsurf/phase_c3a_monitor.py {job_id} (en local)")
print()

client.close()

#!/usr/bin/env python3
"""
Phase C.3B – Kamatera Audit via SSH
Vérification des capacités Kamatera pour le déploiement du Renderer V1
Utilise le mécanisme SSH déjà disponible dans .windsurf (check_kamatera.py)
"""

import paramiko

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('185.167.97.144', username='root', password='Nexiomgroup@Academia0', timeout=15)

print("=== PHASE C.3B – KAMATERA AUDIT ===\n")

# 1. Vérifier Python
print("1. Vérification Python")
stdin, stdout, stderr = client.exec_command('python3 --version 2>&1')
python_version = stdout.read().decode().strip()
print(f"   Python version : {python_version}")
print()

# 2. Vérifier pip
print("2. Vérification pip")
stdin, stdout, stderr = client.exec_command('pip3 --version 2>&1')
pip_version = stdout.read().decode().strip()
print(f"   Pip version : {pip_version}")
print()

# 3. Vérifier Pillow
print("3. Vérification Pillow")
stdin, stdout, stderr = client.exec_command('python3 -c "import PIL; print(PIL.__version__)" 2>&1')
pillow_version = stdout.read().decode().strip()
if "ModuleNotFoundError" in pillow_version or "No module" in pillow_version:
    print(f"   Pillow : NON INSTALLÉ")
    pillow_installed = False
else:
    print(f"   Pillow version : {pillow_version}")
    pillow_installed = True
print()

# 4. Vérifier Matplotlib
print("4. Vérification Matplotlib")
stdin, stdout, stderr = client.exec_command('python3 -c "import matplotlib; print(matplotlib.__version__)" 2>&1')
matplotlib_version = stdout.read().decode().strip()
if "ModuleNotFoundError" in matplotlib_version or "No module" in matplotlib_version:
    print(f"   Matplotlib : NON INSTALLÉ")
    matplotlib_installed = False
else:
    print(f"   Matplotlib version : {matplotlib_version}")
    matplotlib_installed = True
print()

# 5. Vérifier httpx
print("5. Vérification httpx")
stdin, stdout, stderr = client.exec_command('python3 -c "import httpx; print(httpx.__version__)" 2>&1')
httpx_version = stdout.read().decode().strip()
if "ModuleNotFoundError" in httpx_version or "No module" in httpx_version:
    print(f"   httpx : NON INSTALLÉ")
    httpx_installed = False
else:
    print(f"   httpx version : {httpx_version}")
    httpx_installed = True
print()

# 6. Vérifier python-dotenv
print("6. Vérification python-dotenv")
stdin, stdout, stderr = client.exec_command('python3 -c "import dotenv; print(dotenv.__version__)" 2>&1')
dotenv_version = stdout.read().decode().strip()
if "ModuleNotFoundError" in dotenv_version or "No module" in dotenv_version:
    print(f"   python-dotenv : NON INSTALLÉ")
    dotenv_installed = False
else:
    print(f"   python-dotenv version : {dotenv_version}")
    dotenv_installed = True
print()

# 7. Vérifier FFmpeg
print("7. Vérification FFmpeg")
stdin, stdout, stderr = client.exec_command('which ffmpeg && ffmpeg -version | head -1 2>&1')
ffmpeg_version = stdout.read().decode().strip()
print(f"   FFmpeg : {ffmpeg_version}")
print()

# 8. Vérifier le chemin de déploiement potentiel
print("8. Vérification chemin de déploiement")
stdin, stdout, stderr = client.exec_command('ls -la /root/ 2>&1')
root_dir = stdout.read().decode().strip()
print(f"   Contenu /root :")
print(f"   {root_dir[:500]}")
print()

# 9. Vérifier les processus Python actifs
print("9. Vérification processus Python actifs")
stdin, stdout, stderr = client.exec_command('ps aux | grep python | grep -v grep 2>&1')
python_processes = stdout.read().decode().strip()
print(f"   Processus Python :")
print(f"   {python_processes[:500]}")
print()

# 10. Résumé
print("=== RÉSUMÉ ===")
print(f"Python : {python_version}")
print(f"Pip : {pip_version}")
print(f"Pillow : {'INSTALLÉ' if pillow_installed else 'NON INSTALLÉ'}")
print(f"Matplotlib : {'INSTALLÉ' if matplotlib_installed else 'NON INSTALLÉ'}")
print(f"httpx : {'INSTALLÉ' if httpx_installed else 'NON INSTALLÉ'}")
print(f"python-dotenv : {'INSTALLÉ' if dotenv_installed else 'NON INSTALLÉ'}")
print(f"FFmpeg : {ffmpeg_version}")
print()

client.close()

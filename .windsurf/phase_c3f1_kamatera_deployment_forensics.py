#!/usr/bin/env python3
"""
Phase C.3F.1 – Kamatera Deployment Forensics
Vérification factuelle de l'existence du worker Whiteboard sur Kamatera
"""

import paramiko

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('185.167.97.144', username='root', password='Nexiomgroup@Academia0', timeout=15)

print("=== PHASE C.3F.1 – KAMATERA DEPLOYMENT FORENSICS ===\n")

# 1. Vérifier les fichiers worker
print("1. VÉRIFICATION FICHIERS WORKER")

fichiers_a_verifier = [
    "/root/whiteboard_render_worker.py",
    "/root/whiteboard_png_renderer.py",
    "/root/whiteboard_ffmpeg_assembler.py",
    "/root/whiteboard_upload_renderer.py",
    "/root/.env",
    "/root/academia_bobodo_backend/whiteboard_render_worker.py",
    "/root/academia_bobodo_backend/whiteboard_png_renderer.py",
    "/root/academia_bobodo_backend/whiteboard_ffmpeg_assembler.py",
    "/root/academia_bobodo_backend/whiteboard_upload_renderer.py",
]

fichiers_trouves = {}
for fichier in fichiers_a_verifier:
    stdin, stdout, stderr = client.exec_command(f'ls -la {fichier} 2>&1')
    result = stdout.read().decode().strip()
    if "No such file" not in result and result:
        fichiers_trouves[fichier] = result
        print(f"   ✅ {fichier} : PRÉSENT")
    else:
        print(f"   ❌ {fichier} : ABSENT")

print()

# 2. Vérifier les processus Python actifs
print("2. VÉRIFICATION PROCESSUS PYTHON ACTIFS")
stdin, stdout, stderr = client.exec_command('ps aux | grep python | grep -v grep 2>&1')
python_processes = stdout.read().decode().strip()
print(f"   Processus Python :")
if python_processes:
    print(f"   {python_processes}")
else:
    print(f"   Aucun processus Python actif")
print()

# 3. Vérifier les services actifs
print("3. VÉRIFICATION SERVICES ACTIFS")
stdin, stdout, stderr = client.exec_command('systemctl list-units --type=service --state=running 2>&1')
services = stdout.read().decode().strip()
print(f"   Services actifs :")
if "whiteboard" in services.lower():
    print(f"   ✅ Service whiteboard détecté")
else:
    print(f"   ❌ Aucun service whiteboard détecté")
print()

# 4. Vérifier les conteneurs Docker actifs
print("4. VÉRIFICATION CONTENEURS DOCKER ACTIFS")
stdin, stdout, stderr = client.exec_command('docker ps 2>&1')
docker_containers = stdout.read().decode().strip()
if "Cannot connect" in docker_containers:
    print(f"   Docker : NON INSTALLÉ ou NON ACTIF")
else:
    print(f"   Conteneurs Docker :")
    if docker_containers:
        print(f"   {docker_containers[:500]}")
    else:
        print(f"   Aucun conteneur actif")
print()

# 5. Vérifier les dépendances
print("5. VÉRIFICATION DÉPENDANCES")

dependances = {
    "Pillow": "import PIL; print(PIL.__version__)",
    "httpx": "import httpx; print(httpx.__version__)",
    "python-dotenv": "import dotenv; print(dotenv.__version__)",
}

dependances_etat = {}
for dep, import_cmd in dependances.items():
    stdin, stdout, stderr = client.exec_command(f'python3 -c "{import_cmd}" 2>&1')
    result = stdout.read().decode().strip()
    if "ModuleNotFoundError" in result or "No module" in result:
        print(f"   ❌ {dep} : NON INSTALLÉ")
        dependances_etat[dep] = False
    else:
        print(f"   ✅ {dep} : {result}")
        dependances_etat[dep] = True

print()

# 6. Vérifier FFmpeg
print("6. VÉRIFICATION FFmpeg")
stdin, stdout, stderr = client.exec_command('which ffmpeg && ffmpeg -version | head -1 2>&1')
ffmpeg_result = stdout.read().decode().strip()
if ffmpeg_result and "not found" not in ffmpeg_result:
    print(f"   ✅ FFmpeg : {ffmpeg_result}")
    ffmpeg_installed = True
else:
    print(f"   ❌ FFmpeg : NON INSTALLÉ")
    ffmpeg_installed = False
print()

# 7. Résumé
print("=== RÉSUMÉ ===")
print(f"Fichiers worker trouvés : {len(fichiers_trouves)}")
print(f"Dépendances installées : {sum(dependances_etat.values())}/{len(dependances_etat)}")
print(f"FFmpeg installé : {'OUI' if ffmpeg_installed else 'NON'}")
print()

# 8. Conclusion
print("=== CONCLUSION ===")
if len(fichiers_trouves) == 0:
    print("A. NON DÉPLOYÉ")
    print("   Aucun fichier worker trouvé sur Kamatera")
elif len(fichiers_trouves) > 0 and "whiteboard" not in python_processes.lower():
    print("B. DÉPLOYÉ MAIS NON LANCÉ")
    print("   Fichiers worker présents mais aucun processus actif")
elif len(fichiers_trouves) > 0 and "whiteboard" in python_processes.lower():
    print("C. DÉPLOYÉ ET LANCÉ")
    print("   Fichiers worker présents et processus actif")
else:
    print("D. DÉPLOYÉ MAIS INCOHÉRENT")
    print("   État indéterminé")
print()

client.close()

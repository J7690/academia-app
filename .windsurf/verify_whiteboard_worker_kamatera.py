import paramiko
import hashlib

# Configuration Kamatera
KAMATERA_HOST = "185.167.97.144"
KAMATERA_USER = "root"
KAMATERA_KEY_PATH = None  # Utiliser l'authentification par clé par défaut

print("=" * 80)
print("VÉRIFICATION WHITEBOARD WORKER SUR KAMATERA")
print("=" * 80)

try:
    # Connexion SSH
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(KAMATERA_HOST, username=KAMATERA_USER, password='Nexiomgroup@Academia0', timeout=30)
    
    print(f"\n✅ Connexion SSH réussie à {KAMATERA_HOST}")
    
    # Vérifier les fichiers whiteboard-worker
    print("\n--- Fichiers whiteboard-worker ---")
    files_to_check = [
        "/opt/whiteboard-worker/whiteboard_render_worker.py",
        "/opt/whiteboard-worker/whiteboard_png_renderer.py",
        "/opt/whiteboard-worker/whiteboard_ffmpeg_assembler.py",
        "/opt/whiteboard-worker/whiteboard_upload_renderer.py"
    ]
    
    for file_path in files_to_check:
        stdin, stdout, stderr = ssh.exec_command(f"ls -lh {file_path}")
        output = stdout.read().decode().strip()
        error = stderr.read().decode().strip()
        
        if output and not error:
            print(f"✅ {file_path} : {output}")
            
            # Calculer le MD5
            stdin, stdout, stderr = ssh.exec_command(f"md5sum {file_path}")
            md5_output = stdout.read().decode().strip()
            if md5_output:
                md5_hash = md5_output.split()[0]
                print(f"   MD5: {md5_hash}")
        else:
            print(f"❌ {file_path} : {error if error else 'Non trouvé'}")
    
    # Vérifier les dépendances Python
    print("\n--- Dépendances Python ---")
    stdin, stdout, stderr = ssh.exec_command("cd /opt/whiteboard-worker && pip3 list 2>/dev/null || echo 'pip3 non disponible'")
    pip_output = stdout.read().decode().strip()
    print(pip_output)
    
    # Vérifier si le worker peut démarrer
    print("\n--- Test de démarrage du worker ---")
    stdin, stdout, stderr = ssh.exec_command("cd /opt/whiteboard-worker && python3 -c 'import whiteboard_render_worker; print(\"Module importé avec succès\")' 2>&1")
    import_output = stdout.read().decode().strip()
    import_error = stderr.read().decode().strip()
    
    if import_output and "Module importé avec succès" in import_output:
        print(f"✅ Module whiteboard_render_worker importé avec succès")
    else:
        print(f"⚠️ Erreur d'import: {import_output if import_output else import_error}")
    
    # Vérifier le processus worker
    print("\n--- Processus worker ---")
    stdin, stdout, stderr = ssh.exec_command("ps aux | grep whiteboard | grep -v grep")
    ps_output = stdout.read().decode().strip()
    
    if ps_output:
        print(f"✅ Processus worker trouvé:\n{ps_output}")
    else:
        print(f"❌ Aucun processus worker en cours d'exécution")
    
    # Vérifier le service systemd
    print("\n--- Service systemd ---")
    stdin, stdout, stderr = ssh.exec_command("systemctl status whiteboard-worker 2>&1 || echo 'Service non trouvé'")
    service_output = stdout.read().decode().strip()
    print(service_output)
    
    ssh.close()
    
except Exception as e:
    print(f"❌ Erreur: {e}")

print("\n" + "=" * 80)
print("VÉRIFICATION TERMINÉE")
print("=" * 80)

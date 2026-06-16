#!/usr/bin/env python3
"""
Déploiement direct de Bobodo Vocal sans Docker
Pour éviter les problèmes de build Docker
"""

import paramiko
from pathlib import Path

# Identifiants serveur
SERVER_IP = "185.167.97.144"
SERVER_USER = "root"
SERVER_PASS = "Nexiomgroup@Academia0"

# Chemins
LOCAL_DIR = Path(".windsurf/bobodo-vocal")
REMOTE_DIR = "/opt/bobodo-vocal"

def deploy_direct():
    """Déploiement direct sans Docker"""
    print("=== DÉPLOIEMENT DIRECT BOBODO VOCAL ===")
    
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    
    try:
        client.connect(
            hostname=SERVER_IP,
            username=SERVER_USER,
            password=SERVER_PASS,
            timeout=10
        )
        
        # Créer le répertoire
        print("[1] Création répertoire...")
        stdin, stdout, stderr = client.exec_command(f"mkdir -p {REMOTE_DIR}")
        print("  ✅ Répertoire créé")
        
        # Transférer les fichiers
        print("\n[2] Transfert fichiers...")
        sftp = client.open_sftp()
        
        files_to_transfer = [
            "main.py",
            "stt_service.py",
            "tts_service.py",
            "websocket_handler.py",
            "bobodo_client.py",
            "requirements.txt"
        ]
        
        for file in files_to_transfer:
            local_path = LOCAL_DIR / file
            if local_path.exists():
                remote_path = f"{REMOTE_DIR}/{file}"
                print(f"  Transfert: {file}")
                sftp.put(str(local_path), remote_path)
        
        sftp.close()
        print("  ✅ Transfert terminé")
        
        # Installer Python3 et pip si nécessaire
        print("\n[3] Installation Python3 et pip...")
        stdin, stdout, stderr = client.exec_command(
            "apt-get update && apt-get install -y python3 python3-pip python3-venv",
            get_pty=True
        )
        exit_status = stdout.channel.recv_exit_status()
        if exit_status == 0:
            print("  ✅ Python3 installé")
        else:
            print("  ⚠️ Python3 peut déjà être installé")
        
        # Créer venv
        print("\n[4] Création environnement virtuel...")
        stdin, stdout, stderr = client.exec_command(
            f"cd {REMOTE_DIR} && python3 -m venv venv",
            get_pty=True
        )
        exit_status = stdout.channel.recv_exit_status()
        if exit_status == 0:
            print("  ✅ Venv créé")
        else:
            print("  ⚠️ Venv peut déjà exister")
        
        # Installer dépendances
        print("\n[5] Installation dépendances...")
        stdin, stdout, stderr = client.exec_command(
            f"cd {REMOTE_DIR} && venv/bin/pip install -r requirements.txt",
            get_pty=True
        )
        
        # Lire la sortie
        while True:
            line = stdout.readline()
            if not line:
                break
            print(line.strip())
        
        exit_status = stdout.channel.recv_exit_status()
        
        if exit_status == 0:
            print("\n  ✅ Dépendances installées")
            
            # Créer service systemd
            print("\n[6] Création service systemd...")
            service_content = f"""[Unit]
Description=Bobodo Vocal Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory={REMOTE_DIR}
ExecStart={REMOTE_DIR}/venv/bin/python main.py
Restart=always

[Install]
WantedBy=multi-user.target
"""
            
            stdin, stdout, stderr = client.exec_command(
                f"echo '{service_content}' > /etc/systemd/system/bobodo-vocal.service",
                get_pty=True
            )
            
            stdin, stdout, stderr = client.exec_command(
                "systemctl daemon-reload",
                get_pty=True
            )
            
            stdin, stdout, stderr = client.exec_command(
                "systemctl enable bobodo-vocal",
                get_pty=True
            )
            
            stdin, stdout, stderr = client.exec_command(
                "systemctl start bobodo-vocal",
                get_pty=True
            )
            
            print("  ✅ Service créé et démarré")
            
            # Vérifier le statut
            print("\n[7] Vérification statut service...")
            stdin, stdout, stderr = client.exec_command("systemctl status bobodo-vocal")
            print(stdout.read().decode('utf-8')[:500])
            
        else:
            print("\n  ❌ Erreur installation dépendances")
        
        client.close()
        
        print("\n=== DÉPLOIEMENT TERMINÉ ===")
        
    except Exception as e:
        print(f"❌ Erreur: {e}")
        client.close()


if __name__ == "__main__":
    deploy_direct()

#!/usr/bin/env python3
"""
Reconstruction Docker après correction Dockerfile
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

def rebuild_docker():
    """Reconstruction Docker"""
    print("=== RECONSTRUCTION DOCKER ===")
    
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    
    try:
        client.connect(
            hostname=SERVER_IP,
            username=SERVER_USER,
            password=SERVER_PASS,
            timeout=10
        )
        
        # Transférer les fichiers corrigés
        print("[1] Transfert fichiers corrigés...")
        sftp = client.open_sftp()
        sftp.put(str(LOCAL_DIR / "Dockerfile"), f"{REMOTE_DIR}/Dockerfile")
        sftp.put(str(LOCAL_DIR / "requirements.txt"), f"{REMOTE_DIR}/requirements.txt")
        sftp.put(str(LOCAL_DIR / "stt_service.py"), f"{REMOTE_DIR}/stt_service.py")
        sftp.close()
        print("  ✅ Fichiers transférés")
        
        # Construire l'image
        print("\n[2] Construction image Docker...")
        stdin, stdout, stderr = client.exec_command(
            f"cd {REMOTE_DIR} && docker compose build --no-cache",
            get_pty=True
        )
        
        # Lire la sortie en temps réel
        while True:
            line = stdout.readline()
            if not line:
                break
            print(line.strip())
        
        exit_status = stdout.channel.recv_exit_status()
        print(f"\nExit status: {exit_status}")
        
        if exit_status == 0:
            print("\n✅ Construction réussie")
            
            # Lancer le conteneur
            print("\n[3] Lancement conteneur...")
            stdin, stdout, stderr = client.exec_command(
                f"cd {REMOTE_DIR} && docker compose up -d",
                get_pty=True
            )
            
            exit_status = stdout.channel.recv_exit_status()
            output = stdout.read().decode('utf-8')
            error = stderr.read().decode('utf-8')
            
            if exit_status == 0:
                print("  ✅ Conteneur lancé")
            else:
                print(f"  ❌ Erreur lancement: {error[:500]}")
        else:
            print("\n❌ Construction échouée")
        
        client.close()
        
    except Exception as e:
        print(f"❌ Erreur: {e}")
        client.close()


if __name__ == "__main__":
    rebuild_docker()

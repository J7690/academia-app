#!/usr/bin/env python3
"""
Script de déploiement Bobodo Voice sur Kamatera
Utilise les credentials fournis pour se connecter et déployer Piper TTS + WebSocket
"""

import paramiko
import time
import sys

# Credentials Kamatera
KAMATERA_IP = "185.167.97.144"
KAMATERA_USER = "root"
KAMATERA_PASSWORD = "Nexiomgroup@Academia0"
ACCESS_KEY = "a91330958142da0f32fdc6b9f7e16476"
SECRET_KEY = "354e008099f0dbb3e667f550965d8e95"
SERVER_ID = "f6d2656b-0f80-4df1-ac62-53b26d6d921b"

def execute_ssh_command(ssh, command):
    """Exécute une commande SSH et retourne la sortie"""
    print(f"Exécution: {command}")
    stdin, stdout, stderr = ssh.exec_command(command)
    exit_status = stdout.channel.recv_exit_status()
    output = stdout.read().decode('utf-8')
    error = stderr.read().decode('utf-8')
    
    if exit_status != 0:
        print(f"ERREUR (code {exit_status}): {error}")
        return None
    print(f"Sortie: {output}")
    return output

def deploy_piper_server():
    """Déploie Piper TTS et le serveur WebSocket sur Kamatera"""
    print("=== Déploiement Bobodo Voice sur Kamatera ===")
    print(f"IP: {KAMATERA_IP}")
    print(f"Serveur ID: {SERVER_ID}")
    print()
    
    # Connexion SSH
    print("1. Connexion SSH...")
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    
    try:
        ssh.connect(KAMATERA_IP, username=KAMATERA_USER, password=KAMATERA_PASSWORD)
        print("✓ Connexion réussie")
    except Exception as e:
        print(f"✗ Erreur de connexion: {e}")
        return False
    
    print()
    
    # Mise à jour système
    print("2. Mise à jour système...")
    execute_ssh_command(ssh, "apt update && apt upgrade -y")
    
    # Installation dépendances Python
    print("3. Installation dépendances Python...")
    execute_ssh_command(ssh, "apt install -y python3-pip python3-venv")
    
    # Installation Piper TTS
    print("4. Installation Piper TTS...")
    execute_ssh_command(ssh, "pip3 install piper-tts")
    
    # Création répertoire voice_server
    print("5. Création répertoire voice_server...")
    execute_ssh_command(ssh, "mkdir -p /opt/voice_server")
    
    # Upload fichiers
    print("6. Upload fichiers serveur...")
    sftp = ssh.open_sftp()
    
    # Upload tts_service.py
    try:
        with open("voice_server/tts_service.py", "r") as f:
            tts_content = f.read()
        with sftp.file("/opt/voice_server/tts_service.py", "w") as f:
            f.write(tts_content)
        print("✓ tts_service.py uploadé")
    except Exception as e:
        print(f"✗ Erreur upload tts_service.py: {e}")
        return False
    
    # Upload voice_server.py
    try:
        with open("voice_server/voice_server.py", "r") as f:
            server_content = f.read()
        with sftp.file("/opt/voice_server/voice_server.py", "w") as f:
            f.write(server_content)
        print("✓ voice_server.py uploadé")
    except Exception as e:
        print(f"✗ Erreur upload voice_server.py: {e}")
        return False
    
    sftp.close()
    
    # Installation dépendances Python supplémentaires
    print("7. Installation dépendances Python supplémentaires...")
    execute_ssh_command(ssh, "pip3 install websockets gtts")
    
    # Téléchargement voix Piper
    print("8. Téléchargement voix fr_FR-siwis-medium...")
    execute_ssh_command(ssh, "piper download --model fr_FR-siwis-medium --download-dir /opt/piper-tts")
    
    # Création service systemd
    print("9. Création service systemd...")
    service_content = """[Unit]
Description=Bobodo Voice Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/voice_server
ExecStart=/usr/bin/python3 /opt/voice_server/voice_server.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
"""
    
    execute_ssh_command(ssh, f"cat << 'EOF' > /etc/systemd/system/voice_server.service\n{service_content}\nEOF")
    
    # Activation et démarrage service
    print("10. Activation et démarrage service...")
    execute_ssh_command(ssh, "systemctl daemon-reload")
    execute_ssh_command(ssh, "systemctl enable voice_server")
    execute_ssh_command(ssh, "systemctl start voice_server")
    
    # Vérification statut
    print("11. Vérification statut service...")
    status = execute_ssh_command(ssh, "systemctl status voice_server")
    print(status)
    
    # Ouverture port firewall
    print("12. Ouverture port 8000...")
    execute_ssh_command(ssh, "ufw allow 8000/tcp")
    
    ssh.close()
    
    print()
    print("=== Déploiement terminé ===")
    print("WebSocket accessible sur: ws://185.167.97.144:8000/ws")
    return True

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--test":
        print("Mode test: vérification connexion uniquement")
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        try:
            ssh.connect(KAMATERA_IP, username=KAMATERA_USER, password=KAMATERA_PASSWORD)
            print("✓ Connexion test réussie")
            ssh.close()
        except Exception as e:
            print(f"✗ Erreur connexion: {e}")
    else:
        deploy_piper_server()

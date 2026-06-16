#!/usr/bin/env python3
"""
Installer Faster Whisper Medium sur le serveur
"""

import paramiko

SERVER_IP = "185.167.97.144"
SERVER_USER = "root"
SERVER_PASS = "Nexiomgroup@Academia0"
REMOTE_DIR = "/opt/bobodo-vocal"

def install_faster_whisper():
    """Installer Faster Whisper Medium"""
    print("=== INSTALLATION FASTER WHISPER MEDIUM ===")
    
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    
    try:
        client.connect(
            hostname=SERVER_IP,
            username=SERVER_USER,
            password=SERVER_PASS,
            timeout=10
        )
        
        # 1. Installer faster-whisper
        print("[1] Installation faster-whisper...")
        stdin, stdout, stderr = client.exec_command(
            f"cd {REMOTE_DIR} && venv/bin/pip install faster-whisper",
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
            print("  ✅ faster-whisper installé")
        else:
            print("  ❌ Erreur installation")
            client.close()
            return
        
        # 2. Installer ffmpeg (déjà installé)
        print("\n[2] Vérification ffmpeg...")
        stdin, stdout, stderr = client.exec_command("ffmpeg -version")
        output = stdout.read().decode('utf-8')
        if "ffmpeg version" in output:
            print("  ✅ ffmpeg déjà installé")
        else:
            print("  ⚠️ ffmpeg non installé")
        
        client.close()
        
        print("\n=== INSTALLATION TERMINÉE ===")
        print("✅ Faster Whisper Medium installé")
        print("\n⚠️ ACTIONS REQUISES :")
        print("  1. Mettre à jour stt_service.py pour utiliser Faster Whisper")
        print("  2. Redémarrer le service")
        
    except Exception as e:
        print(f"❌ Erreur: {e}")
        client.close()


if __name__ == "__main__":
    install_faster_whisper()

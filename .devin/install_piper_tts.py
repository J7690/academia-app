#!/usr/bin/env python3
"""
Installer et évaluer Piper TTS sur le serveur
"""

import paramiko

SERVER_IP = "185.167.97.144"
SERVER_USER = "root"
SERVER_PASS = "Nexiomgroup@Academia0"
REMOTE_DIR = "/opt/bobodo-vocal"

def install_piper():
    """Installer Piper TTS"""
    print("=== INSTALLATION PIPER TTS ===")
    
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    
    try:
        client.connect(
            hostname=SERVER_IP,
            username=SERVER_USER,
            password=SERVER_PASS,
            timeout=10
        )
        
        # 1. Installer piper-tts
        print("[1] Installation piper-tts...")
        stdin, stdout, stderr = client.exec_command(
            f"cd {REMOTE_DIR} && /opt/bobodo-vocal/venv/bin/pip install piper-tts",
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
            print("  ✅ piper-tts installé")
        else:
            print("  ❌ Erreur installation")
            client.close()
            return
        
        # 2. Créer répertoire models
        print("\n[2] Création répertoire models...")
        stdin, stdout, stderr = client.exec_command(
            f"mkdir -p {REMOTE_DIR}/models",
            get_pty=True
        )
        stdout.channel.recv_exit_status()

        # 3. Télécharger le modèle français manuellement
        print("\n[3] Téléchargement modèle français fr_FR-siwis-low...")
        print("  URL: https://huggingface.co/rhasspy/piper-voices/resolve/main/fr/fr_FR-siwis-low/")

        model_url = "https://huggingface.co/rhasspy/piper-voices/resolve/main/fr/fr_FR-siwis-low/"
        files = [
            "model.onnx",
            "model.onnx.json",
            "config.json"
        ]

        for file in files:
            print(f"  Téléchargement {file}...")
            stdin, stdout, stderr = client.exec_command(
                f"cd {REMOTE_DIR}/models && wget -q {model_url}{file}",
                get_pty=True
            )
            exit_status = stdout.channel.recv_exit_status()
            if exit_status == 0:
                print(f"    ✅ {file} téléchargé")
            else:
                print(f"    ⚠️ Erreur téléchargement {file}")

        client.close()

        print("\n=== INSTALLATION TERMINÉE ===")
        print("✅ Piper TTS installé")
        print("✅ Modèle français téléchargé")
        print("\n⚠️ ACTIONS REQUISES :")
        print("  1. Mettre à jour tts_service.py pour utiliser Piper")
        print("  2. Redémarrer le service")
        
    except Exception as e:
        print(f"❌ Erreur: {e}")
        client.close()


if __name__ == "__main__":
    install_piper()

#!/usr/bin/env python3
"""
Télécharger le modèle Piper français avec la bonne URL
"""

import paramiko

SERVER_IP = "185.167.97.144"
SERVER_USER = "root"
SERVER_PASS = "Nexiomgroup@Academia0"
REMOTE_DIR = "/opt/bobodo-vocal"

def download_piper_model():
    """Télécharger le modèle Piper français"""
    print("=== TÉLÉCHARGEMENT MODÈLE PIPER FRANÇAIS ===")
    
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    
    try:
        client.connect(
            hostname=SERVER_IP,
            username=SERVER_USER,
            password=SERVER_PASS,
            timeout=10
        )
        
        # Créer le répertoire models
        print("[1] Création répertoire models...")
        stdin, stdout, stderr = client.exec_command(
            f"mkdir -p {REMOTE_DIR}/models",
            get_pty=True
        )
        
        # Télécharger le modèle avec la bonne URL
        print("\n[2] Téléchargement modèle fr_FR-medium...")
        stdin, stdout, stderr = client.exec_command(
            f"cd {REMOTE_DIR}/models && wget https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/fr/fr_FR-medium/fr_FR-medium.onnx",
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
            print("  ✅ Modèle ONNX téléchargé")
        else:
            print("  ⚠️ Erreur téléchargement ONNX")
        
        # Télécharger le fichier config
        print("\n[3] Téléchargement configuration...")
        stdin, stdout, stderr = client.exec_command(
            f"cd {REMOTE_DIR}/models && wget https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/fr/fr_FR-medium/fr_FR-medium.onnx.json",
            get_pty=True
        )
        
        exit_status = stdout.channel.recv_exit_status()
        
        if exit_status == 0:
            print("  ✅ Configuration téléchargée")
        else:
            print("  ⚠️ Erreur téléchargement configuration")
        
        client.close()
        
        print("\n=== TÉLÉCHARGEMENT TERMINÉ ===")
        print("✅ Modèle Piper français prêt")
        
    except Exception as e:
        print(f"❌ Erreur: {e}")
        client.close()


if __name__ == "__main__":
    download_piper_model()

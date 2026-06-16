#!/usr/bin/env python3
"""
Télécharger le modèle Piper directement sur Kamatera
"""

import paramiko

SERVER_IP = "185.167.97.144"
SERVER_USER = "root"
SERVER_PASS = "Nexiomgroup@Academia0"

def download_piper():
    """Télécharger le modèle Piper"""
    print("=== TÉLÉCHARGEMENT MODÈLE PIPER ===")

    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

    try:
        client.connect(
            hostname=SERVER_IP,
            username=SERVER_USER,
            password=SERVER_PASS,
            timeout=10
        )

        # 1. Créer répertoire
        print("\n[1] Création répertoire models...")
        stdin, stdout, stderr = client.exec_command(
            "mkdir -p /opt/bobodo-vocal/models",
            get_pty=True
        )
        stdout.channel.recv_exit_status()
        print("  ✅ Répertoire créé")

        # 2. Télécharger les fichiers
        print("\n[2] Téléchargement fichiers...")
        base_url = "https://huggingface.co/rhasspy/piper-voices/resolve/main/fr/fr_FR-siwis-low/"
        files = ["model.onnx", "model.onnx.json", "config.json"]

        for file in files:
            print(f"  Téléchargement {file}...")
            stdin, stdout, stderr = client.exec_command(
                f"cd /opt/bobodo-vocal/models && wget -O {file} {base_url}{file}",
                get_pty=True
            )
            exit_status = stdout.channel.recv_exit_status()
            if exit_status == 0:
                print(f"    ✅ {file} téléchargé")
            else:
                print(f"    ❌ Erreur téléchargement {file}")
                print(f"    Sortie: {stderr.read().decode()}")

        # 3. Vérifier les fichiers
        print("\n[3] Vérification fichiers...")
        stdin, stdout, stderr = client.exec_command(
            "ls -lh /opt/bobodo-vocal/models/",
            get_pty=True
        )
        print(stdout.read().decode())

        client.close()

    except Exception as e:
        print(f"❌ Erreur: {e}")
        client.close()


if __name__ == "__main__":
    download_piper()

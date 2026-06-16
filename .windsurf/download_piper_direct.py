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

        # 2. Tester la connexion internet
        print("\n[2] Test connexion internet...")
        stdin, stdout, stderr = client.exec_command(
            "wget --spider https://google.com",
            get_pty=True
        )
        exit_status = stdout.channel.recv_exit_status()
        if exit_status == 0:
            print("  ✅ Internet accessible")
        else:
            print("  ❌ Internet non accessible")
            print(f"  Sortie: {stderr.read().decode()}")

        # 3. Télécharger en utilisant python sur le serveur (modèle glow-tts)
        print("\n[3] Téléchargement avec Python (modèle glow-tts)...")
        python_script = """
import requests
import os

base_url = "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/fr/fr_FR-glow-tts/"
files = ["model.onnx", "model.onnx.json", "config.json"]

for file in files:
    url = base_url + file
    print(f"Téléchargement {file}...")
    try:
        response = requests.get(url, stream=True)
        response.raise_for_status()
        with open(f"/opt/bobodo-vocal/models/{file}", "wb") as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)
        print(f"✅ {file} téléchargé ({len(response.content)} bytes)")
    except Exception as e:
        print(f"❌ Erreur {file}: {e}")
"""

        stdin, stdout, stderr = client.exec_command(
            f"cd /opt/bobodo-vocal/models && python3 -c '{python_script}'",
            get_pty=True
        )
        output = stdout.read().decode()
        print(output)
        exit_status = stdout.channel.recv_exit_status()
        if exit_status != 0:
            print(f"❌ Erreur téléchargement Python")
            print(f"Sortie: {stderr.read().decode()}")

        # 4. Vérifier les fichiers
        print("\n[4] Vérification fichiers...")
        stdin, stdout, stderr = client.exec_command(
            "ls -lh /opt/bobodo-vocal/models/",
            get_pty=True
        )
        print(stdout.read().decode())

        # 5. Vérifier le contenu des fichiers
        print("\n[5] Vérification contenu (premiers caractères)...")
        stdin, stdout, stderr = client.exec_command(
            "head -c 100 /opt/bobodo-vocal/models/model.onnx",
            get_pty=True
        )
        content = stdout.read().decode()
        print(f"model.onnx: {content}")

        stdin, stdout, stderr = client.exec_command(
            "head -c 100 /opt/bobodo-vocal/models/config.json",
            get_pty=True
        )
        content = stdout.read().decode()
        print(f"config.json: {content}")

        client.close()

    except Exception as e:
        print(f"❌ Erreur: {e}")
        client.close()


if __name__ == "__main__":
    download_piper()

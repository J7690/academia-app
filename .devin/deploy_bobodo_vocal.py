#!/usr/bin/env python3
"""
Déploiement de Bobodo Vocal sur le serveur Academia00
Transfert des fichiers et lancement du service
"""

import paramiko
import os
import sys
from pathlib import Path

# Identifiants serveur
SERVER_IP = "185.167.97.144"
SERVER_USER = "root"
SERVER_PASS = "Nexiomgroup@Academia0"

# Chemins
LOCAL_DIR = Path(".windsurf/bobodo-vocal")
REMOTE_DIR = "/opt/bobodo-vocal"

def deploy_bobodo_vocal():
    """Déploiement Bobodo Vocal"""
    print("=== DÉPLOIEMENT BOBODO VOCAL ===")
    print(f"Serveur: {SERVER_IP}")
    print(f"Local: {LOCAL_DIR.absolute()}")
    print(f"Remote: {REMOTE_DIR}")
    print()
    
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    
    try:
        # Connexion SSH
        print("[1] Connexion SSH...")
        client.connect(
            hostname=SERVER_IP,
            username=SERVER_USER,
            password=SERVER_PASS,
            timeout=10
        )
        print("  ✅ Connexion réussie")
        
        # Créer le répertoire distant
        print("\n[2] Création répertoire distant...")
        stdin, stdout, stderr = client.exec_command(f"mkdir -p {REMOTE_DIR}")
        print("  ✅ Répertoire créé")
        
        # Transfert des fichiers via SFTP
        print("\n[3] Transfert des fichiers...")
        sftp = client.open_sftp()
        
        # Lister les fichiers locaux
        files_to_transfer = [
            "main.py",
            "stt_service.py",
            "tts_service.py",
            "requirements.txt",
            "Dockerfile",
            "docker-compose.yml"
        ]
        
        # Transférer tous les fichiers
        for file in files_to_transfer:
            local_path = LOCAL_DIR / file
            if local_path.exists():
                remote_path = f"{REMOTE_DIR}/{file}"
                print(f"  Transfert: {file}")
                sftp.put(str(local_path), remote_path)
            else:
                print(f"  ⚠️ Fichier manquant: {file}")
        
        sftp.close()
        print("  ✅ Transfert terminé")
        
        # Créer le répertoire models
        print("\n[4] Création répertoire models...")
        stdin, stdout, stderr = client.exec_command(f"mkdir -p {REMOTE_DIR}/models")
        print("  ✅ Répertoire models créé")
        
        # Construire l'image Docker
        print("\n[5] Construction image Docker...")
        stdin, stdout, stderr = client.exec_command(
            f"cd {REMOTE_DIR} && docker compose build",
            get_pty=True
        )
        
        # Attendre la fin (peut prendre du temps)
        exit_status = stdout.channel.recv_exit_status()
        output = stdout.read().decode('utf-8')
        error = stderr.read().decode('utf-8')
        
        if exit_status == 0:
            print("  ✅ Image Docker construite")
        else:
            print(f"  ❌ Erreur construction: {error[:500]}")
        
        # Lancer le conteneur
        print("\n[6] Lancement conteneur...")
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
        
        # Vérifier les conteneurs
        print("\n[8] Vérification conteneurs...")
        stdin, stdout, stderr = client.exec_command("docker ps")
        output = stdout.read().decode('utf-8')
        print(output)
        
        client.close()
        
        print("\n=== DÉPLOIEMENT TERMINÉ ===")
        
    except Exception as e:
        print(f"❌ Erreur: {e}")
        client.close()


if __name__ == "__main__":
    deploy_bobodo_vocal()

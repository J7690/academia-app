#!/usr/bin/env python3
"""
Installation de Docker Compose sur le serveur Academia00
"""

import paramiko

# Identifiants serveur
SERVER_IP = "185.167.97.144"
SERVER_USER = "root"
SERVER_PASS = "Nexiomgroup@Academia0"

def install_docker_compose():
    """Installation Docker Compose"""
    print("=== INSTALLATION DOCKER COMPOSE ===")
    print(f"Serveur: {SERVER_IP}")
    print()
    
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    
    try:
        client.connect(
            hostname=SERVER_IP,
            username=SERVER_USER,
            password=SERVER_PASS,
            timeout=10
        )
        
        # Installer Docker Compose plugin
        print("[1] Installation Docker Compose plugin...")
        stdin, stdout, stderr = client.exec_command(
            "curl -fsSL https://get.docker.com | sh",
            get_pty=True
        )
        
        # Attendre la fin de la commande
        exit_status = stdout.channel.recv_exit_status()
        output = stdout.read().decode('utf-8')
        error = stderr.read().decode('utf-8')
        
        if exit_status == 0:
            print("  ✅ Installation réussie")
        else:
            print(f"  ❌ Erreur: {error[:200]}")
        
        # Vérifier l'installation
        print("\n[2] Vérification installation...")
        stdin, stdout, stderr = client.exec_command("docker compose version")
        output = stdout.read().decode('utf-8')
        print(f"  {output.strip()}")
        
        client.close()
        
        print("\n=== INSTALLATION TERMINÉE ===")
        
    except Exception as e:
        print(f"❌ Erreur: {e}")
        client.close()


if __name__ == "__main__":
    install_docker_compose()

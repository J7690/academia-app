#!/usr/bin/env python3
"""
Diagnostic de la construction Docker sur le serveur
"""

import paramiko

# Identifiants serveur
SERVER_IP = "185.167.97.144"
SERVER_USER = "root"
SERVER_PASS = "Nexiomgroup@Academia0"

def diagnose_docker_build():
    """Diagnostic Docker build"""
    print("=== DIAGNOSTIC DOCKER BUILD ===")
    
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    
    try:
        client.connect(
            hostname=SERVER_IP,
            username=SERVER_USER,
            password=SERVER_PASS,
            timeout=10
        )
        
        # Vérifier le contenu du répertoire
        print("[1] Contenu répertoire /opt/bobodo-vocal...")
        stdin, stdout, stderr = client.exec_command("ls -la /opt/bobodo-vocal")
        print(stdout.read().decode('utf-8'))
        
        # Essayer de construire avec plus de détails
        print("\n[2] Construction Docker (verbose)...")
        stdin, stdout, stderr = client.exec_command(
            "cd /opt/bobodo-vocal && docker compose build --no-cache 2>&1",
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
        
        client.close()
        
    except Exception as e:
        print(f"❌ Erreur: {e}")
        client.close()


if __name__ == "__main__":
    diagnose_docker_build()

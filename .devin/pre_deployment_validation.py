#!/usr/bin/env python3
"""
Validation pré-déploiement du serveur Academia00
Vérifie l'état réel du serveur avant déploiement Bobodo Vocal
"""

import paramiko
import sys

# Identifiants serveur
SERVER_IP = "185.167.97.144"
SERVER_USER = "root"
SERVER_PASS = "Nexiomgroup@Academia0"

def pre_deployment_validation():
    """Validation pré-déploiement"""
    print("=== VALIDATION PRÉ-DÉPLOIEMENT ===")
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
        
        # 1. État serveur
        print("[1] État serveur...")
        stdin, stdout, stderr = client.exec_command("uptime")
        print(stdout.read().decode('utf-8').strip())
        
        # 2. Docker
        print("\n[2] Docker...")
        stdin, stdout, stderr = client.exec_command("docker --version")
        print(stdout.read().decode('utf-8').strip())
        
        # 3. Docker Compose
        print("\n[3] Docker Compose...")
        stdin, stdout, stderr = client.exec_command("docker-compose --version")
        print(stdout.read().decode('utf-8').strip())
        
        # 4. LiveKit
        print("\n[4] LiveKit...")
        stdin, stdout, stderr = client.exec_command("docker ps | grep livekit")
        print(stdout.read().decode('utf-8').strip())
        
        # 5. Espace disque
        print("\n[5] Espace disque...")
        stdin, stdout, stderr = client.exec_command("df -h /")
        print(stdout.read().decode('utf-8').strip())
        
        # 6. Utilisation CPU
        print("\n[6] Utilisation CPU...")
        stdin, stdout, stderr = client.exec_command("top -bn1 | grep 'Cpu(s)'")
        print(stdout.read().decode('utf-8').strip())
        
        # 7. Utilisation mémoire
        print("\n[7] Utilisation mémoire...")
        stdin, stdout, stderr = client.exec_command("free -h")
        print(stdout.read().decode('utf-8').strip())
        
        # 8. Ports ouverts
        print("\n[8] Ports ouverts...")
        stdin, stdout, stderr = client.exec_command("netstat -tlnp | grep LISTEN")
        output = stdout.read().decode('utf-8')
        print(output[:500] if len(output) > 500 else output)
        
        client.close()
        
        print("\n=== VALIDATION TERMINÉE ===")
        
    except Exception as e:
        print(f"❌ Erreur: {e}")
        client.close()


if __name__ == "__main__":
    pre_deployment_validation()

#!/usr/bin/env python3
"""
Health checks pour Bobodo Vocal
Vérifie le service, les endpoints, CPU, RAM
"""

import paramiko
import requests

# Identifiants serveur
SERVER_IP = "185.167.97.144"
SERVER_USER = "root"
SERVER_PASS = "Nexiomgroup@Academia0"
SERVICE_URL = f"http://{SERVER_IP}:8000"

def health_checks():
    """Health checks Bobodo Vocal"""
    print("=== HEALTH CHECKS BOBODO VOCAL ===")
    
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    
    try:
        client.connect(
            hostname=SERVER_IP,
            username=SERVER_USER,
            password=SERVER_PASS,
            timeout=10
        )
        
        # 1. Vérifier le service systemd
        print("[1] Statut service systemd...")
        stdin, stdout, stderr = client.exec_command("systemctl status bobodo-vocal")
        output = stdout.read().decode('utf-8')
        print(output[:500])
        
        # 2. Vérifier les logs
        print("\n[2] Logs service...")
        stdin, stdout, stderr = client.exec_command("journalctl -u bobodo-vocal -n 20 --no-pager")
        output = stdout.read().decode('utf-8')
        print(output[:800])
        
        # 3. Vérifier CPU et RAM
        print("\n[3] Utilisation CPU/RAM...")
        stdin, stdout, stderr = client.exec_command("ps aux | grep 'python main.py' | grep -v grep")
        output = stdout.read().decode('utf-8')
        print(output)
        
        # 4. Vérifier le port
        print("\n[4] Port 8000...")
        stdin, stdout, stderr = client.exec_command("netstat -tlnp | grep 8000")
        output = stdout.read().decode('utf-8')
        print(output)
        
        client.close()
        
        # 5. Test HTTP endpoint (depuis local)
        print("\n[5] Test HTTP endpoint...")
        try:
            response = requests.get(f"{SERVICE_URL}/health", timeout=5)
            print(f"  Status: {response.status_code}")
            print(f"  Response: {response.text}")
        except Exception as e:
            print(f"  ❌ Erreur: {e}")
        
        # 6. Test WebSocket endpoint
        print("\n[6] Test WebSocket endpoint...")
        try:
            response = requests.get(f"{SERVICE_URL}/", timeout=5)
            print(f"  Status: {response.status_code}")
            print(f"  Response: {response.text[:200]}")
        except Exception as e:
            print(f"  ❌ Erreur: {e}")
        
        print("\n=== HEALTH CHECKS TERMINÉS ===")
        
    except Exception as e:
        print(f"❌ Erreur: {e}")
        client.close()


if __name__ == "__main__":
    health_checks()

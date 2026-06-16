#!/usr/bin/env python3
"""
Vérifier le statut du service bobodo-vocal sur le serveur
"""

import paramiko

SERVER_IP = "185.167.97.144"
SERVER_USER = "root"
SERVER_PASS = "Nexiomgroup@Academia0"

def check_service():
    """Vérifier le statut du service"""
    print("=== VÉRIFICATION STATUT SERVICE ===")
    
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    
    try:
        client.connect(
            hostname=SERVER_IP,
            username=SERVER_USER,
            password=SERVER_PASS,
            timeout=10
        )
        
        # Vérifier le statut systemd
        print("[1] Statut systemd...")
        stdin, stdout, stderr = client.exec_command("systemctl status bobodo-vocal")
        output = stdout.read().decode('utf-8')
        print(output[:800])
        
        # Vérifier les logs récents
        print("\n[2] Logs récents...")
        stdin, stdout, stderr = client.exec_command("journalctl -u bobodo-vocal -n 30 --no-pager")
        output = stdout.read().decode('utf-8')
        print(output[:1000])
        
        # Vérifier le port
        print("\n[3] Port 8000...")
        stdin, stdout, stderr = client.exec_command("ss -tlnp | grep 8000")
        output = stdout.read().decode('utf-8')
        print(output)
        
        # Test local sur le serveur
        print("\n[4] Test local sur le serveur...")
        stdin, stdout, stderr = client.exec_command("curl -s http://localhost:8000/health")
        output = stdout.read().decode('utf-8')
        print(output)
        
        client.close()
        
    except Exception as e:
        print(f"❌ Erreur: {e}")
        client.close()


if __name__ == "__main__":
    check_service()

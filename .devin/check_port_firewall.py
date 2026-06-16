#!/usr/bin/env python3
"""
Vérifier le port 8000 et le firewall sur le serveur
"""

import paramiko

# Identifiants serveur
SERVER_IP = "185.167.97.144"
SERVER_USER = "root"
SERVER_PASS = "Nexiomgroup@Academia0"

def check_port_firewall():
    """Vérifier port et firewall"""
    print("=== VÉRIFICATION PORT 8000 ET FIREWALL ===")
    
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    
    try:
        client.connect(
            hostname=SERVER_IP,
            username=SERVER_USER,
            password=SERVER_PASS,
            timeout=10
        )
        
        # 1. Vérifier si le port 8000 est en écoute
        print("[1] Vérification port 8000 en écoute...")
        stdin, stdout, stderr = client.exec_command("netstat -tlnp | grep 8000")
        output = stdout.read().decode('utf-8')
        print(output)
        
        # 2. Vérifier avec ss
        print("\n[2] Vérification avec ss...")
        stdin, stdout, stderr = client.exec_command("ss -tlnp | grep 8000")
        output = stdout.read().decode('utf-8')
        print(output)
        
        # 3. Vérifier les règles firewall (ufw)
        print("\n[3] Vérification règles firewall (ufw)...")
        stdin, stdout, stderr = client.exec_command("ufw status")
        output = stdout.read().decode('utf-8')
        print(output)
        
        # 4. Vérifier iptables
        print("\n[4] Vérification iptables...")
        stdin, stdout, stderr = client.exec_command("iptables -L -n | grep 8000")
        output = stdout.read().decode('utf-8')
        print(output)
        
        # 5. Tester localement sur le serveur
        print("\n[5] Test local sur le serveur...")
        stdin, stdout, stderr = client.exec_command("curl -s http://localhost:8000/health")
        output = stdout.read().decode('utf-8')
        print(output)
        
        # 6. Ouvrir le port 8000 si nécessaire
        print("\n[6] Ouverture port 8000...")
        stdin, stdout, stderr = client.exec_command("ufw allow 8000/tcp", get_pty=True)
        output = stdout.read().decode('utf-8')
        print(output)
        
        client.close()
        
        print("\n=== VÉRIFICATION TERMINÉE ===")
        
    except Exception as e:
        print(f"❌ Erreur: {e}")
        client.close()


if __name__ == "__main__":
    check_port_firewall()

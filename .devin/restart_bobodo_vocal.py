#!/usr/bin/env python3
"""
Redémarrer le service bobodo-vocal sur le serveur
"""

import paramiko

SERVER_IP = "185.167.97.144"
SERVER_USER = "root"
SERVER_PASS = "Nexiomgroup@Academia0"

def restart_service():
    """Redémarrer le service"""
    print("=== REDÉMARRAGE SERVICE BOBODO-VOCAL ===")
    
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    
    try:
        client.connect(
            hostname=SERVER_IP,
            username=SERVER_USER,
            password=SERVER_PASS,
            timeout=10
        )
        
        # Redémarrer le service
        print("[1] Redémarrage service...")
        stdin, stdout, stderr = client.exec_command(
            "systemctl restart bobodo-vocal",
            get_pty=True
        )
        
        print("  ✅ Service redémarré")
        
        # Attendre quelques secondes
        import time
        time.sleep(3)
        
        # Vérifier le statut
        print("\n[2] Vérification statut...")
        stdin, stdout, stderr = client.exec_command("systemctl status bobodo-vocal")
        output = stdout.read().decode('utf-8')
        print(output[:800])
        
        # Vérifier les logs
        print("\n[3] Logs récents...")
        stdin, stdout, stderr = client.exec_command("journalctl -u bobodo-vocal -n 20 --no-pager")
        output = stdout.read().decode('utf-8')
        print(output[:1000])
        
        client.close()
        
        print("\n=== REDÉMARRAGE TERMINÉ ===")
        
    except Exception as e:
        print(f"❌ Erreur: {e}")
        client.close()


if __name__ == "__main__":
    restart_service()

#!/usr/bin/env python3
"""
Vérifier la configuration et les logs du service bobodo-vocal
"""

import paramiko

SERVER_IP = "185.167.97.144"
SERVER_USER = "root"
SERVER_PASS = "Nexiomgroup@Academia0"

def check_service():
    """Vérifier le service"""
    print("=== VÉRIFICATION SERVICE BOBODO-VOCAL ===")

    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

    try:
        client.connect(
            hostname=SERVER_IP,
            username=SERVER_USER,
            password=SERVER_PASS,
            timeout=10
        )

        # 1. Vérifier le statut du service
        print("\n[1] Statut du service...")
        stdin, stdout, stderr = client.exec_command(
            "systemctl status bobodo-vocal",
            get_pty=True
        )
        print(stdout.read().decode())

        # 2. Vérifier le fichier de service
        print("\n[2] Fichier de service...")
        stdin, stdout, stderr = client.exec_command(
            "cat /etc/systemd/system/bobodo-vocal.service",
            get_pty=True
        )
        print(stdout.read().decode())

        # 3. Vérifier les logs avec plus de détails
        print("\n[3] Logs détaillés...")
        stdin, stdout, stderr = client.exec_command(
            "journalctl -u bobodo-vocal -n 100 --no-pager -f",
            get_pty=True
        )
        print(stdout.read().decode())

        client.close()

    except Exception as e:
        print(f"❌ Erreur: {e}")
        client.close()


if __name__ == "__main__":
    check_service()

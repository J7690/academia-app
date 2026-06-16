#!/usr/bin/env python3
"""
Récupérer les logs du service bobodo-vocal sur Kamatera
"""

import paramiko

SERVER_IP = "185.167.97.144"
SERVER_USER = "root"
SERVER_PASS = "Nexiomgroup@Academia0"
SERVICE_NAME = "bobodo-vocal"

def get_logs():
    """Récupérer les logs du service"""
    print(f"=== LOGS SERVICE {SERVICE_NAME.upper()} ===")

    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

    try:
        client.connect(
            hostname=SERVER_IP,
            username=SERVER_USER,
            password=SERVER_PASS,
            timeout=10
        )

        # Récupérer les logs récents
        print("\n[1] Récupération logs récents...")
        stdin, stdout, stderr = client.exec_command(
            f"journalctl -u {SERVICE_NAME} -n 50 --no-pager",
            get_pty=True
        )

        # Lire la sortie
        print("\n--- LOGS ---")
        while True:
            line = stdout.readline()
            if not line:
                break
            print(line.strip())

        client.close()

    except Exception as e:
        print(f"❌ Erreur: {e}")
        client.close()


if __name__ == "__main__":
    get_logs()

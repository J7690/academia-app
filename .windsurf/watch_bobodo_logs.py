#!/usr/bin/env python3
"""
Observer les logs du service bobodo-vocal en temps réel
"""

import paramiko
import time

SERVER_IP = "185.167.97.144"
SERVER_USER = "root"
SERVER_PASS = "Nexiomgroup@Academia0"

def watch_logs():
    """Observer les logs en temps réel"""
    print("=== OBSERVATION LOGS BOBODO-VOCAL ===")
    print("Appuyez sur Ctrl+C pour arrêter\n")

    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

    try:
        client.connect(
            hostname=SERVER_IP,
            username=SERVER_USER,
            password=SERVER_PASS,
            timeout=10
        )

        # Observer les logs en temps réel
        stdin, stdout, stderr = client.exec_command(
            "journalctl -u bobodo-vocal -f",
            get_pty=True
        )

        print("Logs en cours d'observation...\n")

        while True:
            line = stdout.readline()
            if not line:
                break
            print(line.strip())

    except KeyboardInterrupt:
        print("\n\nObservation arrêtée")
    except Exception as e:
        print(f"❌ Erreur: {e}")
    finally:
        client.close()


if __name__ == "__main__":
    watch_logs()

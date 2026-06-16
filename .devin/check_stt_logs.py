#!/usr/bin/env python3
"""
Check STT logs on Kamatera
"""
import paramiko

# Credentials
HOST = "185.167.97.144"
USER = "root"
PASSWORD = "Nexiomgroup@Academia0"

def check_logs():
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    
    try:
        print(f"Connecting to {HOST}...")
        ssh.connect(HOST, username=USER, password=PASSWORD)
        print("Connected!")
        
        # Check service status
        print("\n=== Service Status ===")
        stdin, stdout, stderr = ssh.exec_command("systemctl status bobodo-vocal")
        print(stdout.read().decode())
        
        # Check recent logs
        print("\n=== Recent Logs (last 50 lines) ===")
        stdin, stdout, stderr = ssh.exec_command("journalctl -u bobodo-vocal -n 50 --no-pager")
        print(stdout.read().decode())
        
    except Exception as e:
        print(f"Error: {e}")
    finally:
        ssh.close()

if __name__ == "__main__":
    check_logs()

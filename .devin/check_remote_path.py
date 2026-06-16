#!/usr/bin/env python3
"""
Check correct remote path
"""
import paramiko

# Credentials
HOST = "185.167.97.144"
USER = "root"
PASSWORD = "Nexiomgroup@Academia0"

def check_path():
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    
    try:
        print(f"Connecting to {HOST}...")
        ssh.connect(HOST, username=USER, password=PASSWORD)
        print("Connected!")
        
        # Find bobodo-vocal directory
        print("\n=== Finding bobodo-vocal directory ===")
        stdin, stdout, stderr = ssh.exec_command("find /opt -name 'stt_service.py' 2>/dev/null")
        result = stdout.read().decode()
        print(result)
        
        if not result:
            stdin, stdout, stderr = ssh.exec_command("find /root -name 'stt_service.py' 2>/dev/null")
            result = stdout.read().decode()
            print(result)
        
    except Exception as e:
        print(f"Error: {e}")
    finally:
        ssh.close()

if __name__ == "__main__":
    check_path()

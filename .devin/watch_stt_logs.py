#!/usr/bin/env python3
"""
Watch STT logs in real-time on Kamatera
"""
import paramiko
import time

# Credentials
HOST = "185.167.97.144"
USER = "root"
PASSWORD = "Nexiomgroup@Academia0"

def watch_logs():
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    
    try:
        print(f"Connecting to {HOST}...")
        ssh.connect(HOST, username=USER, password=PASSWORD)
        print("Connected! Watching logs in real-time...")
        print("Press Ctrl+C to stop\n")
        
        # Follow logs in real-time
        stdin, stdout, stderr = ssh.exec_command("journalctl -u bobodo-vocal -f --no-pager")
        
        while True:
            line = stdout.readline()
            if line:
                print(line.strip())
            else:
                time.sleep(0.1)
        
    except KeyboardInterrupt:
        print("\nStopped watching logs")
    except Exception as e:
        print(f"Error: {e}")
    finally:
        ssh.close()

if __name__ == "__main__":
    watch_logs()

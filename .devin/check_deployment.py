#!/usr/bin/env python3
"""
Check if instrumentation files are deployed correctly
"""
import paramiko

# Credentials
HOST = "185.167.97.144"
USER = "root"
PASSWORD = "Nexiomgroup@Academia0"

def check_deployment():
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    
    try:
        print(f"Connecting to {HOST}...")
        ssh.connect(HOST, username=USER, password=PASSWORD)
        print("Connected!")
        
        # Check stt_service.py
        print("\n=== Checking stt_service.py ===")
        stdin, stdout, stderr = ssh.exec_command("grep -n 'STT_AUDIO_RECEIVED' /opt/bobodo-vocal/stt_service.py")
        result = stdout.read().decode()
        if result:
            print(f"✅ Instrumentation found: {result.strip()}")
        else:
            print("❌ Instrumentation NOT found")
        
        # Check websocket_handler.py
        print("\n=== Checking websocket_handler.py ===")
        stdin, stdout, stderr = ssh.exec_command("grep -n 'WS_AUDIO_RECEIVED' /opt/bobodo-vocal/websocket_handler.py")
        result = stdout.read().decode()
        if result:
            print(f"✅ Instrumentation found: {result.strip()}")
        else:
            print("❌ Instrumentation NOT found")
        
    except Exception as e:
        print(f"Error: {e}")
    finally:
        ssh.close()

if __name__ == "__main__":
    check_deployment()

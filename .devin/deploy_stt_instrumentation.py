#!/usr/bin/env python3
"""
Deploy STT instrumentation to Kamatera
"""
import paramiko
import os

# Credentials
HOST = "185.167.97.144"
USER = "root"
PASSWORD = "Nexiomgroup@Academia0"
REMOTE_DIR = "/opt/bobodo-vocal"

# Files to deploy
FILES = [
    ("stt_service.py", "stt_service.py"),
    ("websocket_handler.py", "websocket_handler.py"),
]

def deploy():
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    
    try:
        print(f"Connecting to {HOST}...")
        ssh.connect(HOST, username=USER, password=PASSWORD)
        print("Connected!")
        
        sftp = ssh.open_sftp()
        
        for local_file, remote_file in FILES:
            local_path = os.path.join(r"c:\Users\fasop\AndroidStudioProjects\academia\.windsurf\bobodo-vocal", local_file)
            remote_path = f"{REMOTE_DIR}/{remote_file}"
            
            print(f"Uploading {local_file} from {local_path} to {remote_path}...")
            print(f"File exists locally: {os.path.exists(local_path)}")
            
            with open(local_path, 'rb') as f:
                content = f.read()
            
            with sftp.file(remote_path, 'w') as f:
                f.write(content)
            
            print(f"Uploaded {local_file}")
        
        sftp.close()
        
        # Restart service
        print("Restarting bobodo-vocal service...")
        stdin, stdout, stderr = ssh.exec_command("systemctl restart bobodo-vocal")
        print(stdout.read().decode())
        print("Service restarted!")
        
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
    finally:
        ssh.close()

if __name__ == "__main__":
    deploy()

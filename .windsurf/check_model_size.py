import paramiko

HOST = "185.167.97.144"
USER = "root"
PASS = "Nexiomgroup@Academia0"

def main():
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(HOST, username=USER, password=PASS)
    
    print("=== Model dir size ===")
    stdin, stdout, stderr = ssh.exec_command("du -sh /root/.cache/huggingface/hub/models--Systran--faster-whisper-medium")
    print(stdout.read().decode('utf-8').strip())
    
    print("\n=== Model files ===")
    stdin, stdout, stderr = ssh.exec_command("find /root/.cache/huggingface/hub/models--Systran--faster-whisper-medium -type f -exec ls -lh {} \;")
    print(stdout.read().decode('utf-8'))
    
    print("\n=== Model load events ===")
    stdin, stdout, stderr = ssh.exec_command("journalctl -u bobodo-vocal --no-pager | grep -E 'MODEL|START|load' | head -10")
    print(stdout.read().decode('utf-8'))
    
    ssh.close()

if __name__ == "__main__":
    main()

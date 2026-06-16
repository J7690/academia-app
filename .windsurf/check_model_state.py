import paramiko

HOST = "185.167.97.144"
USER = "root"
PASS = "Nexiomgroup@Academia0"

def main():
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(HOST, username=USER, password=PASS)
    
    print("=== Model files ===")
    stdin, stdout, stderr = ssh.exec_command("find /root/.cache/huggingface/hub -type f \( -name '*.bin' -o -name '*.pt' -o -name '*.safetensors' \) 2>/dev/null | head -10")
    print(stdout.read().decode('utf-8'))
    
    print("=== Process memory ===")
    stdin, stdout, stderr = ssh.exec_command("ps aux | grep python | grep -v grep")
    print(stdout.read().decode('utf-8'))
    
    print("=== Journal model events ===")
    stdin, stdout, stderr = ssh.exec_command("journalctl -u bobodo-vocal --no-pager | grep -E 'MODEL|model|whisper|load' | head -30")
    print(stdout.read().decode('utf-8'))
    
    ssh.close()

if __name__ == "__main__":
    main()

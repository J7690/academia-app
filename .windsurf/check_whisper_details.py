import paramiko

HOST = "185.167.97.144"
USER = "root"
PASS = "Nexiomgroup@Academia0"

def main():
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(HOST, username=USER, password=PASS)
    
    print("=== Faster Whisper model cache ===")
    stdin, stdout, stderr = ssh.exec_command("find /root/.cache -type d -name 'whisper' 2>/dev/null; find /root/.cache -type f -name '*.bin' -o -name '*.pt' -o -name '*.safetensors' -o -name '*.onnx' 2>/dev/null | head -20")
    print(stdout.read().decode('utf-8'))
    
    print("=== HuggingFace cache ===")
    stdin, stdout, stderr = ssh.exec_command("ls -la /root/.cache/huggingface/hub/ 2>/dev/null | head -20")
    print(stdout.read().decode('utf-8'))
    
    print("=== CPU info ===")
    stdin, stdout, stderr = ssh.exec_command("lscpu | grep -E 'Model name|CPU\(s\)|Thread' | head -5")
    print(stdout.read().decode('utf-8'))
    
    print("=== Memory info ===")
    stdin, stdout, stderr = ssh.exec_command("free -m | head -3")
    print(stdout.read().decode('utf-8'))
    
    print("=== Disk I/O check ===")
    stdin, stdout, stderr = ssh.exec_command("dd if=/dev/zero of=/tmp/test_write bs=1M count=10 2>&1 | tail -1")
    print(stdout.read().decode('utf-8'))
    
    ssh.close()

if __name__ == "__main__":
    main()

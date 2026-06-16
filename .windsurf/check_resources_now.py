import paramiko

HOST = "185.167.97.144"
USER = "root"
PASS = "Nexiomgroup@Academia0"

def main():
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(HOST, username=USER, password=PASS)
    
    print("=== TOP snapshot ===")
    stdin, stdout, stderr = ssh.exec_command("top -b -n 1 -p 148819 | tail -3")
    print(stdout.read().decode('utf-8'))
    
    print("=== Process memory ===")
    stdin, stdout, stderr = ssh.exec_command("cat /proc/148819/status | grep -E 'VmRSS|VmSize|Threads'")
    print(stdout.read().decode('utf-8'))
    
    print("=== System load ===")
    stdin, stdout, stderr = ssh.exec_command("cat /proc/loadavg")
    print(stdout.read().decode('utf-8'))
    
    print("=== CPU count ===")
    stdin, stdout, stderr = ssh.exec_command("nproc")
    print(stdout.read().decode('utf-8'))
    
    ssh.close()

if __name__ == "__main__":
    main()

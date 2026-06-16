import paramiko

HOST = "185.167.97.144"
USER = "root"
PASS = "Nexiomgroup@Academia0"

def main():
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(HOST, username=USER, password=PASS)
    
    stdin, stdout, stderr = ssh.exec_command("journalctl -u bobodo-vocal --no-pager -n 200")
    out = stdout.read().decode('utf-8')
    
    # Filter lines around 07:09:10 to 07:09:20 (Trial 4)
    for line in out.split('\n'):
        if '07:09:1' in line or '07:09:2' in line:
            if 'stt_service' in line or 'faster_whisper' in line or 'websocket' in line or 'bobodo_client' in line:
                print(line)
    
    ssh.close()

if __name__ == "__main__":
    main()

import paramiko

HOST = "185.167.97.144"
USER = "root"
PASS = "Nexiomgroup@Academia0"

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(HOST, username=USER, password=PASS)

stdin, stdout, stderr = ssh.exec_command("journalctl -u bobodo-vocal --since='3 minutes ago' | tail -100")
out = stdout.read().decode()
print(out[:20000])

ssh.close()

import paramiko

HOST = "185.167.97.144"
USER = "root"
PASS = "Nexiomgroup@Academia0"

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(HOST, username=USER, password=PASS)

stdin, stdout, stderr = ssh.exec_command("journalctl -u bobodo-vocal --since='10 minutes ago' | tail -80")
out = stdout.read().decode()
print(out[:8000])

ssh.close()

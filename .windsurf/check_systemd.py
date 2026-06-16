import paramiko

HOST = "185.167.97.144"
USER = "root"
PASS = "Nexiomgroup@Academia0"

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(HOST, username=USER, password=PASS)

stdin, stdout, stderr = ssh.exec_command("cat /etc/systemd/system/bobodo-vocal.service")
print("=== SYSTEMD UNIT ===")
print(stdout.read().decode())

stdin, stdout, stderr = ssh.exec_command("cat /opt/bobodo-vocal/tts_service.py")
print("\n=== TTS SERVICE ===")
print(stdout.read().decode()[:2000])

ssh.close()

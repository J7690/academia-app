import paramiko

HOST = "185.167.97.144"
USER = "root"
PASS = "Nexiomgroup@Academia0"

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(HOST, username=USER, password=PASS, timeout=15)

# Read websocket handler
stdin, stdout, stderr = ssh.exec_command("cat /opt/bobodo-vocal/websocket_handler.py")
handler = stdout.read().decode()
print("=== WEBSOCKET HANDLER ===")
print(handler)

# Read main.py
stdin, stdout, stderr = ssh.exec_command("cat /opt/bobodo-vocal/main.py")
main = stdout.read().decode()
print("\n=== MAIN.PY ===")
print(main)

# Read stt_service.py header
stdin, stdout, stderr = ssh.exec_command("head -80 /opt/bobodo-vocal/stt_service.py")
stt = stdout.read().decode()
print("\n=== STT SERVICE (head) ===")
print(stt)

ssh.close()

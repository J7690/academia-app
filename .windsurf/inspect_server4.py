import paramiko

HOST = "185.167.97.144"
USER = "root"
PASS = "Nexiomgroup@Academia0"

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(HOST, username=USER, password=PASS, timeout=15)

# Read websocket handler in chunks
stdin, stdout, stderr = ssh.exec_command("wc -l /opt/bobodo-vocal/websocket_handler.py")
lines = stdout.read().decode().strip()
print(f"websocket_handler.py: {lines} lines")

stdin, stdout, stderr = ssh.exec_command("sed -n '1,60p' /opt/bobodo-vocal/websocket_handler.py")
print("\n=== WEBSOCKET HANDLER lines 1-60 ===")
print(stdout.read().decode())

stdin, stdout, stderr = ssh.exec_command("sed -n '61,120p' /opt/bobodo-vocal/websocket_handler.py")
print("\n=== WEBSOCKET HANDLER lines 61-120 ===")
print(stdout.read().decode())

stdin, stdout, stderr = ssh.exec_command("sed -n '121,180p' /opt/bobodo-vocal/websocket_handler.py")
print("\n=== WEBSOCKET HANDLER lines 121-180 ===")
print(stdout.read().decode())

# Check current model loaded
stdin, stdout, stderr = ssh.exec_command("grep -n 'model_size' /opt/bobodo-vocal/stt_service.py | head -5")
print("\n=== MODEL SIZE CONFIG ===")
print(stdout.read().decode())

# Check main.py for how STTService is instantiated
stdin, stdout, stderr = ssh.exec_command("cat /opt/bobodo-vocal/main.py")
print("\n=== MAIN.PY ===")
print(stdout.read().decode())

ssh.close()

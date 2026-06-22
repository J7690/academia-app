import paramiko

HOST = "185.167.97.144"
USER = "root"
PASS = "Nexiomgroup@Academia0"

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(HOST, username=USER, password=PASS, timeout=15)

# Check running processes
stdin, stdout, stderr = ssh.exec_command("ps aux | grep -E 'python|voice|stt|websocket|fastapi|uvicorn' | grep -v grep")
print("=== PROCESSES ===")
print(stdout.read().decode())

# Check ports
stdin, stdout, stderr = ssh.exec_command("ss -tlnp | grep -E ':8000|:8080|:8765|:5000'")
print("\n=== PORTS ===")
print(stdout.read().decode())

# List files
stdin, stdout, stderr = ssh.exec_command("ls -la /opt/bobodo-vocal/")
print("\n=== FILES ===")
print(stdout.read().decode())

# Check .env
stdin, stdout, stderr = ssh.exec_command("cat /opt/bobodo-vocal/.env 2>/dev/null | grep -E 'PORT|MODEL|HOST'")
print("\n=== ENV ===")
print(stdout.read().decode())

# Check systemd service
stdin, stdout, stderr = ssh.exec_command("systemctl status bobodo-vocal 2>/dev/null | head -20 || echo 'no systemd'")
print("\n=== SYSTEMD ===")
print(stdout.read().decode())

# Read websocket handler fully
stdin, stdout, stderr = ssh.exec_command("wc -l /opt/bobodo-vocal/voice_server/websocket_handler.py 2>/dev/null")
print("\n=== WEBSOCKET HANDLER LINES ===")
print(stdout.read().decode())

# Read first 100 lines
stdin, stdout, stderr = ssh.exec_command("head -100 /opt/bobodo-vocal/voice_server/websocket_handler.py")
print("\n=== WEBSOCKET HANDLER (first 100) ===")
print(stdout.read().decode())

ssh.close()

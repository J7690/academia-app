import paramiko

HOST = "185.167.97.144"
USER = "root"
PASS = "Nexiomgroup@Academia0"

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(HOST, username=USER, password=PASS, timeout=15)

# Find all Python files related to voice/websocket
stdin, stdout, stderr = ssh.exec_command("find /opt/bobodo-vocal -name '*.py' -type f 2>/dev/null | head -20")
files = stdout.read().decode()
print("=== FILES ===")
print(files)

# Check running processes
stdin, stdout, stderr = ssh.exec_command("ps aux | grep -E 'python|voice|stt|websocket' | grep -v grep")
procs = stdout.read().decode()
print("\n=== PROCESSES ===")
print(procs)

# Check ports
stdin, stdout, stderr = ssh.exec_command("ss -tlnp | grep -E '8000|8080|8765' || netstat -tlnp | grep -E '8000|8080|8765'")
ports = stdout.read().decode()
print("\n=== PORTS ===")
print(ports)

# Read websocket handler
stdin, stdout, stderr = ssh.exec_command("cat /opt/bobodo-vocal/voice_server/websocket_handler.py 2>/dev/null || cat /opt/bobodo-vocal/websocket_handler.py 2>/dev/null || find /opt -name 'websocket_handler.py' -exec cat {} \\;")
handler = stdout.read().decode()
print("\n=== WEBSOCKET HANDLER ===")
print(handler[:5000])

# Read stt service
stdin, stdout, stderr = ssh.exec_command("cat /opt/bobodo-vocal/voice_server/stt_service.py 2>/dev/null || find /opt -name 'stt_service.py' -exec cat {} \\;")
stt = stdout.read().decode()
print("\n=== STT SERVICE ===")
print(stt[:5000])

ssh.close()
print("\n=== DONE ===")

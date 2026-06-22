import paramiko
import time

HOST = "185.167.97.144"
USER = "root"
PASS = "Nexiomgroup@Academia0"

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(HOST, username=USER, password=PASS)

scripts = {
    "test_multi_session.py": r"c:\Users\fasop\AndroidStudioProjects\academia\.windsurf\test_multi_session.py",
    "test_small_load.py": r"c:\Users\fasop\AndroidStudioProjects\academia\.windsurf\test_small_load.py",
    "test_conversation.py": r"c:\Users\fasop\AndroidStudioProjects\academia\.windsurf\test_conversation.py",
    "test_resilience.py": r"c:\Users\fasop\AndroidStudioProjects\academia\.windsurf\test_resilience.py",
}

# Upload scripts
sftp = ssh.open_sftp()
for remote_name, local_path in scripts.items():
    sftp.put(local_path, f"/tmp/{remote_name}")
    print(f"Uploaded {remote_name}")
sftp.close()

# Run M1: Multi-session test
print("\n" + "="*60)
print("RUNNING M1 — Multi-session test")
print("="*60)
stdin, stdout, stderr = ssh.exec_command(
    "cd /opt/bobodo-vocal && source venv/bin/activate && pip install websockets 2>/dev/null && python /tmp/test_multi_session.py",
    timeout=120
)
while not stdout.channel.exit_status_ready():
    if stdout.channel.recv_ready():
        data = stdout.channel.recv(4096).decode('utf-8', errors='replace')
        if data:
            print(data, end='')
print(stdout.read().decode('utf-8', errors='replace'))
print("STDERR:", stderr.read().decode('utf-8', errors='replace')[:500])

# Run M2: Small load test (standalone, ~20-30 min)
print("\n" + "="*60)
print("RUNNING M2 — Small load test (~20 min)")
print("="*60)
stdin, stdout, stderr = ssh.exec_command(
    "cd /opt/bobodo-vocal && source venv/bin/activate && python /tmp/test_small_load.py",
    timeout=2400
)
while not stdout.channel.exit_status_ready():
    if stdout.channel.recv_ready():
        data = stdout.channel.recv(4096).decode('utf-8', errors='replace')
        if data:
            print(data, end='')
    time.sleep(1)
print(stdout.read().decode('utf-8', errors='replace'))
print("STDERR:", stderr.read().decode('utf-8', errors='replace')[:500])

# Run M3: Conversation test
print("\n" + "="*60)
print("RUNNING M3 — 5-minute conversation test")
print("="*60)
stdin, stdout, stderr = ssh.exec_command(
    "cd /opt/bobodo-vocal && source venv/bin/activate && python /tmp/test_conversation.py",
    timeout=600
)
while not stdout.channel.exit_status_ready():
    if stdout.channel.recv_ready():
        data = stdout.channel.recv(4096).decode('utf-8', errors='replace')
        if data:
            print(data, end='')
    time.sleep(1)
print(stdout.read().decode('utf-8', errors='replace'))
print("STDERR:", stderr.read().decode('utf-8', errors='replace')[:500])

# Run M4: Resilience test
print("\n" + "="*60)
print("RUNNING M4 — Network resilience test")
print("="*60)
stdin, stdout, stderr = ssh.exec_command(
    "cd /opt/bobodo-vocal && source venv/bin/activate && python /tmp/test_resilience.py",
    timeout=120
)
while not stdout.channel.exit_status_ready():
    if stdout.channel.recv_ready():
        data = stdout.channel.recv(4096).decode('utf-8', errors='replace')
        if data:
            print(data, end='')
    time.sleep(1)
print(stdout.read().decode('utf-8', errors='replace'))
print("STDERR:", stderr.read().decode('utf-8', errors='replace')[:500])

# Download results
print("\n" + "="*60)
print("DOWNLOADING RESULTS")
print("="*60)
sftp = ssh.open_sftp()
for remote, local in [
    ("/tmp/multi_session_test.json", r"c:\Users\fasop\AndroidStudioProjects\academia\.windsurf\multi_session_test.json"),
    ("/tmp/small_load_test.json", r"c:\Users\fasop\AndroidStudioProjects\academia\.windsurf\small_load_test.json"),
    ("/tmp/conversation_test.json", r"c:\Users\fasop\AndroidStudioProjects\academia\.windsurf\conversation_test.json"),
    ("/tmp/resilience_test.json", r"c:\Users\fasop\AndroidStudioProjects\academia\.windsurf\resilience_test.json"),
]:
    try:
        sftp.get(remote, local)
        print(f"Downloaded {remote}")
    except Exception as e:
        print(f"Failed {remote}: {e}")
sftp.close()
ssh.close()
print("\nAll tests completed.")

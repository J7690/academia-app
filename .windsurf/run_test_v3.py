import paramiko
import time

HOST = "185.167.97.144"
USER = "root"
PASS = "Nexiomgroup@Academia0"

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(HOST, username=USER, password=PASS)

# Wait for model to be fully loaded
print("Waiting for model load...")
time.sleep(10)

# Upload test
with open(r"c:\Users\fasop\AndroidStudioProjects\academia\.windsurf\test_multi_session_v3.py", "r", encoding="utf-8") as f:
    script = f.read()

stdin, stdout, stderr = ssh.exec_command("cat > /tmp/test_multi_session_v3.py << 'PYEOF'\n" + script + "\nPYEOF")
stdout.channel.recv_exit_status()

print("Running multi-session v3 test (~3 min)...")
stdin, stdout, stderr = ssh.exec_command(
    "cd /opt/bobodo-vocal && source venv/bin/activate && python /tmp/test_multi_session_v3.py",
    timeout=300
)

while not stdout.channel.exit_status_ready():
    if stdout.channel.recv_ready():
        data = stdout.channel.recv(4096).decode('utf-8', errors='replace')
        if data:
            print(data, end='')
    time.sleep(0.5)

print(stdout.read().decode('utf-8', errors='replace'))
print("STDERR:", stderr.read().decode('utf-8', errors='replace')[:500])

# Download results
sftp = ssh.open_sftp()
try:
    sftp.get("/tmp/multi_session_v3_test.json", r"c:\Users\fasop\AndroidStudioProjects\academia\.windsurf\multi_session_v3_test.json")
    print("Downloaded results.")
except Exception as e:
    print(f"Failed to download: {e}")

sftp.close()
ssh.close()
print("Done.")

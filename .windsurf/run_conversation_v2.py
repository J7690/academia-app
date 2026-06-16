import paramiko
import time

HOST = "185.167.97.144"
USER = "root"
PASS = "Nexiomgroup@Academia0"

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(HOST, username=USER, password=PASS)

with open(r"c:\Users\fasop\AndroidStudioProjects\academia\.windsurf\test_conversation_v2.py", "r", encoding="utf-8") as f:
    script = f.read()

stdin, stdout, stderr = ssh.exec_command("cat > /tmp/test_conversation_v2.py << 'PYEOF'\n" + script + "\nPYEOF")
stdout.channel.recv_exit_status()

print("Running 5-minute conversation test (~6 min)...")
stdin, stdout, stderr = ssh.exec_command(
    "cd /opt/bobodo-vocal && source venv/bin/activate && python /tmp/test_conversation_v2.py",
    timeout=600
)

while not stdout.channel.exit_status_ready():
    if stdout.channel.recv_ready():
        data = stdout.channel.recv(4096).decode('utf-8', errors='replace')
        if data:
            print(data, end='')
    time.sleep(0.5)

print(stdout.read().decode('utf-8', errors='replace'))
print("STDERR:", stderr.read().decode('utf-8', errors='replace')[:500])

# Get system stats
stdin2, stdout2, stderr2 = ssh.exec_command("systemctl status bobodo-vocal --no-pager | grep -E 'Memory|CPU|Active'")
stats = stdout2.read().decode()
print("\n--- SERVICE STATS ---")
print(stats)

sftp = ssh.open_sftp()
sftp.get("/tmp/conversation_v2_test.json", r"c:\Users\fasop\AndroidStudioProjects\academia\.windsurf\conversation_v2_test.json")
sftp.close()
ssh.close()
print("Done.")

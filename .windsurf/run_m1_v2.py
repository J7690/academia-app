import paramiko

HOST = "185.167.97.144"
USER = "root"
PASS = "Nexiomgroup@Academia0"

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(HOST, username=USER, password=PASS)

with open(r"c:\Users\fasop\AndroidStudioProjects\academia\.windsurf\test_multi_session_v2.py", "r", encoding="utf-8") as f:
    script = f.read()

stdin, stdout, stderr = ssh.exec_command("cat > /tmp/test_multi_session_v2.py << 'PYEOF'\n" + script + "\nPYEOF")
stdout.channel.recv_exit_status()

print("Running M1 v2 (~2 min)...")
stdin, stdout, stderr = ssh.exec_command(
    "cd /opt/bobodo-vocal && source venv/bin/activate && python /tmp/test_multi_session_v2.py",
    timeout=300
)

while not stdout.channel.exit_status_ready():
    if stdout.channel.recv_ready():
        data = stdout.channel.recv(4096).decode('utf-8', errors='replace')
        if data:
            print(data, end='')

print(stdout.read().decode('utf-8', errors='replace'))
print("STDERR:", stderr.read().decode('utf-8', errors='replace')[:500])

sftp = ssh.open_sftp()
sftp.get("/tmp/multi_session_test_v2.json", r"c:\Users\fasop\AndroidStudioProjects\academia\.windsurf\multi_session_test_v2.json")
sftp.close()
ssh.close()
print("Done.")

import paramiko

HOST = "185.167.97.144"
USER = "root"
PASS = "Nexiomgroup@Academia0"

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(HOST, username=USER, password=PASS)

with open(r"c:\Users\fasop\AndroidStudioProjects\academia\.windsurf\test_conv_short.py", "r", encoding="utf-8") as f:
    script = f.read()

stdin, stdout, stderr = ssh.exec_command("cat > /tmp/test_conv_short.py << 'PYEOF'\n" + script + "\nPYEOF")
stdout.channel.recv_exit_status()

print("Running conversation test (3 exchanges)...")
stdin, stdout, stderr = ssh.exec_command(
    "cd /opt/bobodo-vocal && source venv/bin/activate && python /tmp/test_conv_short.py",
    timeout=120
)

while not stdout.channel.exit_status_ready():
    if stdout.channel.recv_ready():
        data = stdout.channel.recv(4096).decode('utf-8', errors='replace')
        if data:
            print(data, end='')

print(stdout.read().decode('utf-8', errors='replace'))
err = stderr.read().decode('utf-8', errors='replace')
if err:
    print("STDERR:", err[:300])

# Service stats
stdin, stdout, stderr = ssh.exec_command("systemctl status bobodo-vocal --no-pager | grep -E 'Memory|Active'")
print("\n" + stdout.read().decode().strip())

ssh.close()
print("\nDone.")

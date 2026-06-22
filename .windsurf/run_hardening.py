import paramiko
import time

HOST = "185.167.97.144"
USER = "root"
PASS = "Nexiomgroup@Academia0"

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(HOST, username=USER, password=PASS)

with open(r"c:\Users\fasop\AndroidStudioProjects\academia\.windsurf\hardening_stress.py", "r", encoding="utf-8") as f:
    script = f.read()

stdin, stdout, stderr = ssh.exec_command("cat > /tmp/hardening_stress.py << 'PYEOF'\n" + script + "\nPYEOF")
stdout.channel.recv_exit_status()

print("Running hardening tests (~5 min)...")
stdin, stdout, stderr = ssh.exec_command(
    "cd /opt/bobodo-vocal && source venv/bin/activate && python /tmp/hardening_stress.py",
    timeout=600
)

while not stdout.channel.exit_status_ready():
    if stdout.channel.recv_ready():
        data = stdout.channel.recv(4096).decode('utf-8', errors='replace')
        if data:
            print(data, end='')
    time.sleep(0.5)

print(stdout.read().decode('utf-8', errors='replace'))
err = stderr.read().decode('utf-8', errors='replace')
if err.strip():
    print("STDERR:", err[:500])

sftp = ssh.open_sftp()
try:
    sftp.get("/tmp/hardening_report.json", r"c:\Users\fasop\AndroidStudioProjects\academia\.windsurf\hardening_report.json")
    print("Downloaded report.")
except:
    print("No report file.")
sftp.close()
ssh.close()
print("Done.")

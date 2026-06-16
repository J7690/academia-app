import paramiko

HOST = "185.167.97.144"
USER = "root"
PASS = "Nexiomgroup@Academia0"

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(HOST, username=USER, password=PASS)

# Upload script
with open(r"c:\Users\fasop\AndroidStudioProjects\academia\.windsurf\benchmark_tiny_isolated.py", "r", encoding="utf-8") as f:
    script_content = f.read()

stdin, stdout, stderr = ssh.exec_command("cat > /tmp/benchmark_tiny_isolated.py << 'PYEOF'\n" + script_content + "\nPYEOF")
stdout.channel.recv_exit_status()

# Run in venv
print("Running benchmark on server (this may take 10-15 minutes)...")
stdin, stdout, stderr = ssh.exec_command(
    "cd /opt/bobodo-vocal && source venv/bin/activate && python /tmp/benchmark_tiny_isolated.py",
    timeout=1200
)

# Stream output
while not stdout.channel.exit_status_ready():
    if stdout.channel.recv_ready():
        data = stdout.channel.recv(4096).decode('utf-8', errors='replace')
        if data:
            print(data, end='')
    if stderr.channel.recv_stderr_ready():
        data = stderr.channel.recv_stderr(4096).decode('utf-8', errors='replace')
        if data:
            print("STDERR:", data, end='')

# Get remaining
remaining_out = stdout.read().decode('utf-8', errors='replace')
remaining_err = stderr.read().decode('utf-8', errors='replace')
if remaining_out:
    print(remaining_out)
if remaining_err:
    print("STDERR:", remaining_err)

# Download report
print("\nDownloading report...")
sftp = ssh.open_sftp()
try:
    sftp.get("/tmp/tiny_benchmark/benchmark_report.json", r"c:\Users\fasop\AndroidStudioProjects\academia\.windsurf\benchmark_report.json")
    print("Report downloaded to benchmark_report.json")
except Exception as e:
    print(f"Could not download report: {e}")

sftp.close()
ssh.close()
print("Done.")

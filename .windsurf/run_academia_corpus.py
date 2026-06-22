import paramiko

HOST = "185.167.97.144"
USER = "root"
PASS = "Nexiomgroup@Academia0"

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(HOST, username=USER, password=PASS)

with open(r"c:\Users\fasop\AndroidStudioProjects\academia\.windsurf\benchmark_tiny_academia_corpus.py", "r", encoding="utf-8") as f:
    script = f.read()

stdin, stdout, stderr = ssh.exec_command("cat > /tmp/benchmark_tiny_academia_corpus.py << 'PYEOF'\n" + script + "\nPYEOF")
stdout.channel.recv_exit_status()

print("Running Academia corpus benchmark (100 expressions, ~15-20 min)...")
stdin, stdout, stderr = ssh.exec_command(
    "cd /opt/bobodo-vocal && source venv/bin/activate && python /tmp/benchmark_tiny_academia_corpus.py",
    timeout=1800
)

while not stdout.channel.exit_status_ready():
    if stdout.channel.recv_ready():
        data = stdout.channel.recv(4096).decode('utf-8', errors='replace')
        if data:
            print(data, end='')
    if stderr.channel.recv_stderr_ready():
        data = stderr.channel.recv_stderr(4096).decode('utf-8', errors='replace')
        if data:
            print("STDERR:", data, end='')

remaining = stdout.read().decode('utf-8', errors='replace')
if remaining:
    print(remaining)
err = stderr.read().decode('utf-8', errors='replace')
if err.strip():
    print("STDERR:", err)

# Download
sftp = ssh.open_sftp()
try:
    sftp.get("/tmp/tiny_academia_benchmark/academia_corpus_report.json", r"c:\Users\fasop\AndroidStudioProjects\academia\.windsurf\academia_corpus_report.json")
    print("\nReport downloaded to academia_corpus_report.json")
except Exception as e:
    print(f"Could not download: {e}")

sftp.close()
ssh.close()
print("Done.")

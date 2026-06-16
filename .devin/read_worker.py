import paramiko
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect("185.167.96.214", username='root', password='Wenden@Koote2026', timeout=15)

# Read the full worker script
_, stdout, _ = ssh.exec_command("cat /opt/academia-worker/video_worker.py", timeout=10)
print(stdout.read().decode())

# Also get columns of video_processing_jobs
print("\n\n=== TABLE SCHEMA ===")
_, stdout, _ = ssh.exec_command("echo 'done'", timeout=10)
print(stdout.read().decode())

ssh.close()

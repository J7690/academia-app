import paramiko
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('185.167.97.144', username='root', password='Nexiomgroup@Academia0', timeout=20)
_, out, _ = ssh.exec_command('journalctl -u whiteboard-worker --since "2026-06-28 11:15:00" --no-pager 2>&1 | tail -30', timeout=25)
print(out.read().decode('utf-8', errors='replace'))
ssh.close()

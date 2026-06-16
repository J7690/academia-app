import paramiko
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('185.167.96.214', username='root', password='Wenden@Koote2026', timeout=15)
_, stdout, _ = ssh.exec_command('journalctl -u academia-video-worker --no-pager -n 10')
print(stdout.read().decode())
_, stdout2, _ = ssh.exec_command('systemctl is-active academia-video-worker')
print("Status:", stdout2.read().decode().strip())
ssh.close()

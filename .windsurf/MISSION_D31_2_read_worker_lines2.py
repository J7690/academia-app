import paramiko
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('185.167.97.144', username='root', password='Nexiomgroup@Academia0', timeout=20)
stdin, stdout, stderr = ssh.exec_command('sed -n "145,155p" /opt/whiteboard-worker/whiteboard_render_worker.py')
print(stdout.read().decode('utf-8'))
print('ERR:', stderr.read().decode('utf-8'))
ssh.close()

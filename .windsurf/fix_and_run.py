import paramiko

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('185.167.97.144', username='root', password='Nexiomgroup@Academia0')

# Fix indentation
stdin, stdout, stderr = ssh.exec_command("sed -i 's/ t.join/t.join/' /tmp/load_test.py")
stdout.channel.recv_exit_status()

# Run
stdin, stdout, stderr = ssh.exec_command("cd /opt/bobodo-vocal && source venv/bin/activate && python /tmp/load_test.py")
out = stdout.read().decode('utf-8')
err = stderr.read().decode('utf-8')
print(out)
if err.strip():
    print("STDERR:")
    print(err)

ssh.close()

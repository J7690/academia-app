import paramiko
import time

HOST = "185.167.97.144"
USER = "root"
PASS = "Nexiomgroup@Academia0"
REMOTE_PATH = "/opt/bobodo-vocal"

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(HOST, username=USER, password=PASS)

sftp = ssh.open_sftp()
sftp.put(r"c:\Users\fasop\AndroidStudioProjects\academia\.windsurf\stt_service_v2.py", f"{REMOTE_PATH}/stt_service.py")
sftp.close()

stdin, stdout, stderr = ssh.exec_command(f"cd {REMOTE_PATH} && source venv/bin/activate && python -m py_compile stt_service.py && echo 'SYNTAX_OK'")
out = stdout.read().decode()
if "SYNTAX_OK" in out:
    print("Syntax OK.")
else:
    print("SYNTAX ERROR:", out, stderr.read().decode())
    ssh.close()
    exit(1)

print("Restarting service...")
ssh.exec_command("systemctl restart bobodo-vocal")
time.sleep(10)

stdin, stdout, stderr = ssh.exec_command("systemctl is-active bobodo-vocal")
print("Status:", stdout.read().decode().strip())

ssh.close()
print("Done.")

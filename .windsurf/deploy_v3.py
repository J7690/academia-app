import paramiko
import time

HOST = "185.167.97.144"
USER = "root"
PASS = "Nexiomgroup@Academia0"
REMOTE_PATH = "/opt/bobodo-vocal"

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(HOST, username=USER, password=PASS)

# Backup
ssh.exec_command(f"cp {REMOTE_PATH}/bobodo_client.py {REMOTE_PATH}/bobodo_client.py.backup")

sftp = ssh.open_sftp()
print("Uploading bobodo_client_v2.py...")
sftp.put(r"c:\Users\fasop\AndroidStudioProjects\academia\.windsurf\bobodo_client_v2.py", f"{REMOTE_PATH}/bobodo_client.py")
print("Uploading websocket_handler_v2.py...")
sftp.put(r"c:\Users\fasop\AndroidStudioProjects\academia\.windsurf\websocket_handler_v2.py", f"{REMOTE_PATH}/websocket_handler.py")
sftp.close()

# Syntax check
print("Checking syntax...")
stdin, stdout, stderr = ssh.exec_command(f"cd {REMOTE_PATH} && source venv/bin/activate && python -m py_compile bobodo_client.py && echo 'OK_BC' && python -m py_compile websocket_handler.py && echo 'OK_WS'")
out = stdout.read().decode()
if "OK_BC" in out and "OK_WS" in out:
    print("Syntax OK.")
else:
    print("SYNTAX ERROR:", out, stderr.read().decode())
    ssh.close()
    exit(1)

print("Restarting service...")
ssh.exec_command("systemctl restart bobodo-vocal")
time.sleep(10)

stdin, stdout, stderr = ssh.exec_command("systemctl is-active bobodo-vocal")
status = stdout.read().decode().strip()
print(f"Status: {status}")

if status != "active":
    stdin, stdout, stderr = ssh.exec_command("journalctl -u bobodo-vocal --since='30 seconds ago' --no-pager")
    print("LOGS:", stdout.read().decode()[:3000])

ssh.close()
print("Done.")

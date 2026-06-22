import paramiko
import time

HOST = "185.167.97.144"
USER = "root"
PASS = "Nexiomgroup@Academia0"
REMOTE_PATH = "/opt/bobodo-vocal"

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(HOST, username=USER, password=PASS)

# Backup current files
print("Creating backups...")
ssh.exec_command(f"cp {REMOTE_PATH}/stt_service.py {REMOTE_PATH}/stt_service.py.backup")
ssh.exec_command(f"cp {REMOTE_PATH}/websocket_handler.py {REMOTE_PATH}/websocket_handler.py.backup")

# Upload new files
sftp = ssh.open_sftp()
print("Uploading stt_service_v2.py...")
sftp.put(r"c:\Users\fasop\AndroidStudioProjects\academia\.windsurf\stt_service_v2.py", f"{REMOTE_PATH}/stt_service.py")
print("Uploading websocket_handler_v2.py...")
sftp.put(r"c:\Users\fasop\AndroidStudioProjects\academia\.windsurf\websocket_handler_v2.py", f"{REMOTE_PATH}/websocket_handler.py")
sftp.close()

# Check syntax before restart
print("Checking Python syntax...")
stdin, stdout, stderr = ssh.exec_command(f"cd {REMOTE_PATH} && source venv/bin/activate && python -m py_compile stt_service.py && echo 'SYNTAX_OK_STT' && python -m py_compile websocket_handler.py && echo 'SYNTAX_OK_WS'")
out = stdout.read().decode()
err = stderr.read().decode()
if "SYNTAX_OK_STT" in out and "SYNTAX_OK_WS" in out:
    print("Syntax OK for both files.")
else:
    print("SYNTAX ERROR:")
    print(out)
    print(err)
    ssh.close()
    exit(1)

# Restart service
print("Restarting bobodo-vocal service...")
ssh.exec_command("systemctl restart bobodo-vocal")
time.sleep(3)

# Check status
stdin, stdout, stderr = ssh.exec_command("systemctl is-active bobodo-vocal && systemctl status bobodo-vocal --no-pager | head -20")
status = stdout.read().decode()
print("Service status:")
print(status)

ssh.close()
print("Deployment complete.")

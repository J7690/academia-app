import paramiko

HOST = "185.167.97.144"
USER = "root"
PASS = "Nexiomgroup@Academia0"

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(HOST, username=USER, password=PASS, timeout=15)

sftp = ssh.open_sftp()
sftp.get("/opt/bobodo-vocal/websocket_handler.py", r"c:\Users\fasop\AndroidStudioProjects\academia\.windsurf\websocket_handler_server.py")
sftp.get("/opt/bobodo-vocal/stt_service.py", r"c:\Users\fasop\AndroidStudioProjects\academia\.windsurf\stt_service_server.py")
sftp.close()
ssh.close()
print("Files downloaded.")

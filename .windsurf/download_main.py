import paramiko

HOST = "185.167.97.144"
USER = "root"
PASS = "Nexiomgroup@Academia0"

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(HOST, username=USER, password=PASS)

sftp = ssh.open_sftp()
sftp.get("/opt/bobodo-vocal/main.py", r"c:\Users\fasop\AndroidStudioProjects\academia\.windsurf\main_server.py")
sftp.get("/opt/bobodo-vocal/bobodo_client.py", r"c:\Users\fasop\AndroidStudioProjects\academia\.windsurf\bobodo_client_server.py")
sftp.close()
ssh.close()
print("Done.")

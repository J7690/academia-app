import paramiko

HOST = "185.167.97.144"
USER = "root"
PASS = "Nexiomgroup@Academia0"

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(HOST, username=USER, password=PASS)

# Check RAM via systemctl (reliable)
stdin, stdout, stderr = ssh.exec_command("systemctl status bobodo-vocal --no-pager | grep -E 'Memory|Active|Tasks'")
print("Service status:")
print(stdout.read().decode())

# Check sessions count in logs
stdin, stdout, stderr = ssh.exec_command("journalctl -u bobodo-vocal --since='10 minutes ago' | grep -c 'Active:'")
print(f"Session log entries: {stdout.read().decode().strip()}")

# Check for any errors
stdin, stdout, stderr = ssh.exec_command("journalctl -u bobodo-vocal --since='10 minutes ago' | grep -ciE 'error|exception|traceback'")
print(f"Errors in last 10 min: {stdout.read().decode().strip()}")

# Uptime
stdin, stdout, stderr = ssh.exec_command("journalctl -u bobodo-vocal --since='10 minutes ago' | grep 'Removed session' | wc -l")
print(f"Sessions cleanly destroyed (last 10 min): {stdout.read().decode().strip()}")

stdin, stdout, stderr = ssh.exec_command("journalctl -u bobodo-vocal --since='10 minutes ago' | grep 'Registered session' | wc -l")
print(f"Sessions created (last 10 min): {stdout.read().decode().strip()}")

ssh.close()

import paramiko
import time

HOST = "185.167.97.144"
USER = "root"
PASS = "Nexiomgroup@Academia0"
REMOTE_PATH = "/opt/bobodo-vocal"

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(HOST, username=USER, password=PASS)

# ─── MISSION 1: Backups ───
print("Creating backups...")
for cmd in [
    f"cp {REMOTE_PATH}/.env {REMOTE_PATH}/.env.backup_medium",
    f"cp {REMOTE_PATH}/main.py {REMOTE_PATH}/main.py.backup",
    f"cp {REMOTE_PATH}/stt_service.py {REMOTE_PATH}/stt_service.py.backup_v2",
]:
    ssh.exec_command(cmd)
time.sleep(1)

# ─── MISSION 1: Upload stt_service_v3 ───
sftp = ssh.open_sftp()
print("Uploading stt_service_v3.py (Small + dictionnaire + logs)...")
sftp.put(r"c:\Users\fasop\AndroidStudioProjects\academia\.windsurf\stt_service_v3.py", f"{REMOTE_PATH}/stt_service.py")
sftp.close()

# ─── MISSION 1: Patch main.py to pass settings.whisper_model ───
print("Patching main.py (STTService(model_size=settings.whisper_model))...")
stdin, stdout, stderr = ssh.exec_command(
    f"sed -i 's/stt_service = STTService()/stt_service = STTService(model_size=settings.whisper_model)/' {REMOTE_PATH}/main.py"
)
stdout.channel.recv_exit_status()

# ─── MISSION 1: Update .env to small ───
print("Updating .env: WHISPER_MODEL=small...")
stdin, stdout, stderr = ssh.exec_command(
    f"sed -i 's/WHISPER_MODEL=.*/WHISPER_MODEL=small/' {REMOTE_PATH}/.env"
)
stdout.channel.recv_exit_status()

# Verify changes
print("\nVerifying...")
stdin, stdout, stderr = ssh.exec_command(f"grep WHISPER_MODEL {REMOTE_PATH}/.env")
print(f"  .env: {stdout.read().decode().strip()}")

stdin, stdout, stderr = ssh.exec_command(f"grep 'stt_service = ' {REMOTE_PATH}/main.py")
print(f"  main.py: {stdout.read().decode().strip()}")

# Syntax check
print("\nSyntax check...")
stdin, stdout, stderr = ssh.exec_command(
    f"cd {REMOTE_PATH} && source venv/bin/activate && python -m py_compile stt_service.py && echo 'OK_STT' && python -m py_compile main.py && echo 'OK_MAIN'"
)
out = stdout.read().decode()
if "OK_STT" in out and "OK_MAIN" in out:
    print("  Syntax OK.")
else:
    print("  SYNTAX ERROR:", out, stderr.read().decode())
    ssh.close()
    exit(1)

# ─── MISSION 4: Deploy ───
print("\nRestarting bobodo-vocal service...")
ssh.exec_command("systemctl restart bobodo-vocal")
time.sleep(12)

stdin, stdout, stderr = ssh.exec_command("systemctl is-active bobodo-vocal")
status = stdout.read().decode().strip()
print(f"  Service: {status}")

if status != "active":
    print("SERVICE FAILED! Checking logs...")
    stdin, stdout, stderr = ssh.exec_command("journalctl -u bobodo-vocal --since='30 seconds ago' --no-pager | tail -20")
    print(stdout.read().decode()[:3000])
    ssh.close()
    exit(1)

# Verify model loaded
stdin, stdout, stderr = ssh.exec_command("journalctl -u bobodo-vocal --since='30 seconds ago' | grep -E 'MODEL_READY|MODEL_LOADING'")
logs = stdout.read().decode()
print(f"  Model logs: {logs.strip()[-200:]}")

# Check RAM
stdin, stdout, stderr = ssh.exec_command("systemctl status bobodo-vocal --no-pager | grep Memory")
mem = stdout.read().decode().strip()
print(f"  {mem}")

ssh.close()
print("\n✅ Migration Small déployée.")

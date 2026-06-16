import paramiko
import time

HOST = "185.167.97.144"
USER = "root"
PASS = "Nexiomgroup@Academia0"

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(HOST, username=USER, password=PASS)

# ÉTAPE 1: Show current systemd file
print("=== AVANT ===")
stdin, stdout, stderr = ssh.exec_command("cat /etc/systemd/system/bobodo-vocal.service")
before = stdout.read().decode()
print(before)

# New systemd file
new_unit = """[Unit]
Description=Bobodo Vocal Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/bobodo-vocal
ExecStart=/opt/bobodo-vocal/venv/bin/python main.py
Restart=always
RestartSec=5
LimitNOFILE=65536
StandardOutput=journal
StandardError=journal
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
"""

# Write new unit file
stdin, stdout, stderr = ssh.exec_command(f"cat > /etc/systemd/system/bobodo-vocal.service << 'EOF'\n{new_unit}EOF")
stdout.channel.recv_exit_status()

# Reload systemd
stdin, stdout, stderr = ssh.exec_command("systemctl daemon-reload")
stdout.channel.recv_exit_status()

# Restart service
print("\nRestarting service...")
ssh.exec_command("systemctl restart bobodo-vocal")
time.sleep(8)

# Verify
print("\n=== APRÈS ===")
stdin, stdout, stderr = ssh.exec_command("cat /etc/systemd/system/bobodo-vocal.service")
print(stdout.read().decode())

stdin, stdout, stderr = ssh.exec_command("systemctl is-active bobodo-vocal")
status = stdout.read().decode().strip()
print(f"Service: {status}")

stdin, stdout, stderr = ssh.exec_command("systemctl status bobodo-vocal --no-pager | head -12")
print(stdout.read().decode())

ssh.close()
print("ÉTAPE 1 TERMINÉE." if status == "active" else "ÉTAPE 1 ÉCHEC!")

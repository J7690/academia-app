import paramiko
import time

HOST = "185.167.97.144"
USER = "root"
PASS = "Nexiomgroup@Academia0"

print("=" * 80)
print("DÉPLOIEMENT whiteboard-worker.service SUR KAMATERA")
print("=" * 80)

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(HOST, username=USER, password=PASS)

print(f"\n✅ Connexion SSH réussie à {HOST}")

# ÉTAPE 1: Vérifier si le service existe déjà
print("\n--- Vérification service existant ---")
stdin, stdout, stderr = ssh.exec_command("cat /etc/systemd/system/whiteboard-worker.service 2>/dev/null || echo 'SERVICE_NOT_FOUND'")
before = stdout.read().decode().strip()
if "SERVICE_NOT_FOUND" in before:
    print("✅ Service whiteboard-worker.service n'existe pas encore")
else:
    print("⚠️ Service whiteboard-worker.service existe déjà:")
    print(before)

# New systemd file for whiteboard-worker
new_unit = """[Unit]
Description=Whiteboard Render Worker Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/whiteboard-worker
ExecStart=/usr/bin/python3 /opt/whiteboard-worker/whiteboard_render_worker.py
Restart=always
RestartSec=5
LimitNOFILE=65536
StandardOutput=journal
StandardError=journal
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
"""

# ÉTAPE 2: Write new unit file
print("\n--- Création fichier service ---")
stdin, stdout, stderr = ssh.exec_command(f"cat > /etc/systemd/system/whiteboard-worker.service << 'EOF'\n{new_unit}EOF")
stdout.channel.recv_exit_status()
error = stderr.read().decode().strip()
if error:
    print(f"❌ Erreur: {error}")
else:
    print("✅ Fichier whiteboard-worker.service créé")

# ÉTAPE 3: Reload systemd
print("\n--- Reload systemd ---")
stdin, stdout, stderr = ssh.exec_command("systemctl daemon-reload")
stdout.channel.recv_exit_status()
error = stderr.read().decode().strip()
if error:
    print(f"❌ Erreur: {error}")
else:
    print("✅ systemd daemon-reload réussi")

# ÉTAPE 4: Enable service
print("\n--- Enable service ---")
stdin, stdout, stderr = ssh.exec_command("systemctl enable whiteboard-worker")
stdout.channel.recv_exit_status()
error = stderr.read().decode().strip()
if error:
    print(f"❌ Erreur: {error}")
else:
    print("✅ Service whiteboard-worker enabled")

# ÉTAPE 5: Start service
print("\n--- Start service ---")
stdin, stdout, stderr = ssh.exec_command("systemctl start whiteboard-worker")
stdout.channel.recv_exit_status()
error = stderr.read().decode().strip()
if error:
    print(f"❌ Erreur: {error}")
else:
    print("✅ Service whiteboard-worker démarré")

time.sleep(3)

# ÉTAPE 6: Verify service status
print("\n--- Vérification statut service ---")
stdin, stdout, stderr = ssh.exec_command("systemctl is-active whiteboard-worker")
status = stdout.read().decode().strip()
print(f"Statut: {status}")

stdin, stdout, stderr = ssh.exec_command("systemctl status whiteboard-worker --no-pager | head -15")
status_output = stdout.read().decode()
print(status_output)

# ÉTAPE 7: Verify process
print("\n--- Vérification processus ---")
stdin, stdout, stderr = ssh.exec_command("ps aux | grep whiteboard_render_worker | grep -v grep")
ps_output = stdout.read().decode().strip()
if ps_output:
    print("✅ Processus worker actif:")
    print(ps_output)
else:
    print("❌ Aucun processus worker trouvé")

# ÉTAPE 8: Check logs
print("\n--- Logs (journalctl) ---")
stdin, stdout, stderr = ssh.exec_command("journalctl -u whiteboard-worker -n 20 --no-pager")
logs = stdout.read().decode()
print(logs)

ssh.close()

print("\n" + "=" * 80)
if status == "active" and ps_output:
    print("✅ DÉPLOIEMENT SERVICE RÉUSSI")
else:
    print("❌ DÉPLOIEMENT SERVICE ÉCHEC")
print("=" * 80)

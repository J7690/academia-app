#!/usr/bin/env python3
"""Audit complet Kamatera - Toutes les preuves demandées"""
import paramiko
import sys
from datetime import datetime

HOST = "185.167.97.144"
USER = "root"
PASSWORD = "Nexiomgroup@Academia0"

OUTPUT_FILE = "c:\\Users\\fasop\\AndroidStudioProjects\\academia\\.windsurf\\kamatera_audit_output.txt"

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

try:
    client.connect(HOST, username=USER, password=PASSWORD, timeout=20, banner_timeout=15, auth_timeout=15)
except Exception as e:
    with open(OUTPUT_FILE, 'w') as f:
        f.write(f"CONNEXION SSH ECHOUEE: {e}\n")
    sys.exit(1)

results = []
results.append("=" * 70)
results.append("AUDIT KAMATERA - " + datetime.now().isoformat())
results.append("=" * 70)
results.append(f"IP: {HOST}")
results.append(f"USER: {USER}")
results.append("")

commands = [
    ("1. IDENTIFICATION", "hostname"),
    ("1. IDENTIFICATION", "whoami"),
    ("1. IDENTIFICATION", "pwd"),
    ("1. IDENTIFICATION", "uname -a"),
    ("2. SERVICES", "systemctl status voice_server --no-pager 2>&1 || echo 'SERVICE_NOT_FOUND'"),
    ("2. SERVICES", "systemctl status bobodo-vocal --no-pager 2>&1 || echo 'SERVICE_NOT_FOUND'"),
    ("2. SERVICES", "systemctl list-units --type=service --no-pager | head -20"),
    ("3. DOCKER", "docker ps 2>&1 || echo 'DOCKER_NOT_AVAILABLE'"),
    ("3. DOCKER", "docker images 2>&1 | head -10 || echo 'DOCKER_NOT_AVAILABLE'"),
    ("4. RESEAU", "ss -tulpn | head -20"),
    ("5. PIPER", "ls -la /root/piper_voices/ 2>&1 || echo 'PIPER_DIR_NOT_FOUND'"),
    ("5. PIPER", "find /root -name '*.onnx' 2>/dev/null | head -5"),
    ("5. PIPER", "which piper 2>&1 || which piper-tts 2>&1 || echo 'PIPER_NOT_IN_PATH'"),
    ("6. PYTHON", "python3 --version"),
    ("6. PYTHON", "pip3 list 2>/dev/null | grep -i 'piper\|websockets\|gtts'"),
    ("7. FICHIERS SERVEUR", "ls -la /root/voice_server/ 2>&1 || echo 'VOICE_SERVER_DIR_NOT_FOUND'"),
    ("7. FICHIERS SERVEUR", "ls -la /opt/voice_server/ 2>&1 || echo 'OPT_VOICE_SERVER_NOT_FOUND'"),
    ("8. SYSTEMD", "ls -la /etc/systemd/system/voice* 2>&1 || echo 'NO_SYSTEMD_SERVICE'"),
]

for section, cmd in commands:
    results.append("")
    results.append(f"--- {section}: {cmd} ---")
    try:
        stdin, stdout, stderr = client.exec_command(cmd, timeout=30)
        exit_code = stdout.channel.recv_exit_status()
        out = stdout.read().decode('utf-8', errors='replace').strip()
        err = stderr.read().decode('utf-8', errors='replace').strip()
        if out:
            results.append(out)
        if err and exit_code != 0:
            results.append(f"STDERR: {err}")
        results.append(f"EXIT_CODE: {exit_code}")
    except Exception as e:
        results.append(f"ERROR: {e}")

client.close()

results.append("")
results.append("=" * 70)
results.append("FIN AUDIT")
results.append("=" * 70)

output = "\n".join(results)
with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
    f.write(output)

print(output)

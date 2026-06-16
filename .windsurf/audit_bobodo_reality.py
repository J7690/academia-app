#!/usr/bin/env python3
"""Audit de réalité Bobodo Voice — preuves d'exécution uniquement."""
import paramiko
import sys
from datetime import datetime, timezone

HOST = "185.167.97.144"
USER = "root"
PASSWORD = "Nexiomgroup@Academia0"
TIMESTAMP = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")

OUTPUT = []

def log(label, cmd, stdout, stderr, exit_code):
    OUTPUT.append(f"\n{'='*70}")
    OUTPUT.append(f"[{label}]")
    OUTPUT.append(f"COMMAND: {cmd}")
    OUTPUT.append(f"TIMESTAMP: {TIMESTAMP}")
    OUTPUT.append(f"EXIT_CODE: {exit_code}")
    if stdout.strip():
        OUTPUT.append("STDOUT:")
        OUTPUT.append(stdout)
    if stderr.strip() and exit_code != 0:
        OUTPUT.append("STDERR:")
        OUTPUT.append(stderr)
    OUTPUT.append("-"*70)

def run(client, label, cmd):
    try:
        stdin, stdout, stderr = client.exec_command(cmd, timeout=60, get_pty=False)
        exit_code = stdout.channel.recv_exit_status()
        out = stdout.read().decode('utf-8', errors='replace').strip()
        err = stderr.read().decode('utf-8', errors='replace').strip()
        log(label, cmd, out, err, exit_code)
        return out, err, exit_code
    except Exception as e:
        log(label, cmd, "", str(e), -1)
        return "", str(e), -1

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

try:
    client.connect(HOST, username=USER, password=PASSWORD, timeout=30, banner_timeout=20, auth_timeout=20)
except Exception as e:
    print(f"SSH CONNECTION FAILED: {e}")
    sys.exit(1)

OUTPUT.append("="*70)
OUTPUT.append("BOBODO VOICE REALITY AUDIT")
OUTPUT.append(f"TIMESTAMP: {TIMESTAMP}")
OUTPUT.append(f"TARGET: {HOST} as {USER}")
OUTPUT.append("="*70)

# MISSION 1 — Services
OUTPUT.append("\n### MISSION 1 — Services réels installés ###")
run(client, "SERVICES_ALL", "systemctl list-units --type=service --no-pager")
run(client, "SERVICES_VOICE", "systemctl list-unit-files --type=service | grep -i voice || echo 'NO_VOICE_SERVICE_FOUND'")
run(client, "SERVICES_BOBODO", "systemctl list-unit-files --type=service | grep -i bobodo || echo 'NO_BOBODO_SERVICE_FOUND'")
run(client, "SERVICES_WHISPER", "systemctl list-unit-files --type=service | grep -i whisper || echo 'NO_WHISPER_SERVICE_FOUND'")
run(client, "SERVICES_PIPER", "systemctl list-unit-files --type=service | grep -i piper || echo 'NO_PIPER_SERVICE_FOUND'")

# MISSION 2 — Ports
OUTPUT.append("\n### MISSION 2 — Ports réellement ouverts ###")
run(client, "PORTS_SS", "ss -tulpn || echo 'SS_FAILED'")
run(client, "PORTS_NETSTAT", "netstat -tulpn 2>/dev/null || echo 'NETSTAT_NOT_AVAILABLE'")

# MISSION 3 — Fichiers
OUTPUT.append("\n### MISSION 3 — Emplacements réels ###")
run(client, "FIND_VOICE", "find / -iname '*voice*' -not -path '/proc/*' -not -path '/sys/*' 2>/dev/null | head -30 || echo 'FIND_VOICE_EMPTY'")
run(client, "FIND_WHISPER", "find / -iname '*whisper*' -not -path '/proc/*' -not -path '/sys/*' 2>/dev/null | head -30 || echo 'FIND_WHISPER_EMPTY'")
run(client, "FIND_PIPER", "find / -iname '*piper*' -not -path '/proc/*' -not -path '/sys/*' 2>/dev/null | head -30 || echo 'FIND_PIPER_EMPTY'")
run(client, "FIND_BOBODO", "find / -iname '*bobodo*' -not -path '/proc/*' -not -path '/sys/*' 2>/dev/null | head -30 || echo 'FIND_BOBODO_EMPTY'")

# MISSION 4 — Existence fichiers serveur
OUTPUT.append("\n### MISSION 4 — Fichiers serveur vocal ###")
run(client, "FILE_MAIN_PY", "ls -la /root/voice_server/main.py 2>&1 || echo 'ABSENT'")
run(client, "FILE_WEBSOCKET", "ls -la /root/voice_server/websocket_handler.py 2>&1 || echo 'ABSENT'")
run(client, "FILE_STT", "ls -la /root/voice_server/stt_service.py 2>&1 || echo 'ABSENT'")
run(client, "FILE_TTS", "ls -la /root/voice_server/tts_service.py 2>&1 || echo 'ABSENT'")
run(client, "FILE_SERVER", "ls -la /root/voice_server/voice_server.py 2>&1 || echo 'ABSENT'")

# MISSION 5 — Modèles
OUTPUT.append("\n### MISSION 5 — Modèles réels ###")
run(client, "MODELS_PIPER", "find /root /opt /usr/share -name '*.onnx' 2>/dev/null | head -10 || echo 'NO_ONNX_FOUND'")
run(client, "MODELS_WHISPER", "find /root /opt /usr/share -iname '*whisper*' -type f 2>/dev/null | head -10 || echo 'NO_WHISPER_MODEL_FOUND'")
run(client, "MODELS_SIZE", "find /root /opt /usr/share \( -name '*.onnx' -o -name '*.bin' -o -name '*.pt' -o -name '*.ckpt' \) -exec ls -lh {} + 2>/dev/null | head -20 || echo 'NO_MODEL_FILES'")

# MISSION 6 — Endpoints
OUTPUT.append("\n### MISSION 6 — Test endpoints ###")
run(client, "CURL_LOCALHOST", "curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 http://localhost:8000/ 2>&1 || echo 'CURL_FAILED_LOCALHOST_8000'")
run(client, "CURL_127", "curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 http://127.0.0.1:8000/ 2>&1 || echo 'CURL_FAILED_127_8000'")
run(client, "CURL_LOCAL_WS", "curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 http://localhost:8000/ws 2>&1 || echo 'CURL_WS_FAILED'")
run(client, "CURL_PUBLIC", "curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 http://185.167.97.144:8000/ 2>&1 || echo 'CURL_PUBLIC_FAILED'")

client.close()

OUTPUT.append("\n" + "="*70)
OUTPUT.append("FIN AUDIT")
OUTPUT.append("="*70)

report = "\n".join(OUTPUT)
with open("c:\\Users\\fasop\\AndroidStudioProjects\\academia\\.windsurf\\BOBODO_VOICE_REALITY_AUDIT_RAW.txt", "w", encoding="utf-8") as f:
    f.write(report)

print(report)

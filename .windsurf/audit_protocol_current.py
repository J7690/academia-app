#!/usr/bin/env python3
"""Mission 1 — Cartographier le protocole actuel complet"""
import paramiko
import os

HOST = "185.167.97.144"
USER = "root"
PASSWORD = "Nexiomgroup@Academia0"

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect(HOST, username=USER, password=PASSWORD, timeout=20, banner_timeout=15, auth_timeout=15)

results = []
results.append("# BOBODO_PROTOCOL_CURRENT\n")
results.append("## Mission 1 — Cartographie complète du protocole\n")

# Lire les 4 fichiers serveur
files = [
    "/opt/bobodo-vocal/main.py",
    "/opt/bobodo-vocal/websocket_handler.py",
    "/opt/bobodo-vocal/stt_service.py",
    "/opt/bobodo-vocal/tts_service.py",
    "/opt/bobodo-vocal/bobodo_client.py",
]

for f in files:
    name = os.path.basename(f)
    results.append(f"\n### {name}\n")
    stdin, stdout, stderr = client.exec_command(f"cat {f}", timeout=15)
    out = stdout.read().decode('utf-8', errors='replace')
    results.append("```python")
    results.append(out)
    results.append("```")

client.close()

# Lire les fichiers Flutter
flutter_files = [
    r"c:\Users\fasop\AndroidStudioProjects\academia\academia_app\lib\services\bobodo_vocal_service.dart",
    r"c:\Users\fasop\AndroidStudioProjects\academia\academia_app\lib\features\student\tabs\student_bobodo_tab.dart",
]

for f in flutter_files:
    if os.path.exists(f):
        name = os.path.basename(f)
        results.append(f"\n### Flutter: {name}\n")
        with open(f, "r", encoding="utf-8") as fh:
            results.append("```dart")
            results.append(fh.read())
            results.append("```")

output = "\n".join(results)
with open(r"c:\Users\fasop\AndroidStudioProjects\academia\.windsurf\BOBODO_PROTOCOL_CURRENT.md", "w", encoding="utf-8") as f:
    f.write(output)
print(f"Written {len(output)} chars")

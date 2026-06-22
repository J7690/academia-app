#!/usr/bin/env python3
"""Mission 2 — Lire les fichiers main.py et websocket_handler.py"""
import paramiko

HOST = "185.167.97.144"
USER = "root"
PASSWORD = "Nexiomgroup@Academia0"

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect(HOST, username=USER, password=PASSWORD, timeout=20, banner_timeout=15, auth_timeout=15)

results = []

for path in ["/opt/bobodo-vocal/main.py", "/opt/bobodo-vocal/websocket_handler.py"]:
    name = path.split("/")[-1]
    results.append(f"\n=== {name} ===\n")
    stdin, stdout, stderr = client.exec_command(f"cat {path}", timeout=15)
    out = stdout.read().decode('utf-8', errors='replace')
    results.append("```python")
    results.append(out)
    results.append("```")

client.close()

output = "\n".join(results)
with open("c:\\Users\\fasop\\AndroidStudioProjects\\academia\\.windsurf\\BOBODO_WS_REGISTRATION.md", "w", encoding="utf-8") as f:
    f.write(output)
print(output)

#!/usr/bin/env python3
"""Audit vérité WebSocket Bobodo — Mission 1-2"""
import paramiko

HOST = "185.167.97.144"
USER = "root"
PASSWORD = "Nexiomgroup@Academia0"

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect(HOST, username=USER, password=PASSWORD, timeout=20, banner_timeout=15, auth_timeout=15)

results = []
results.append("# BOBODO_WS_ROUTE_DISCOVERY\n")
results.append("## Mission 1 — grep routes websocket\n")

commands = [
    ("grep -R '@app.websocket' /opt/bobodo-vocal/", "app_websocket"),
    ("grep -R '@router.websocket' /opt/bobodo-vocal/", "router_websocket"),
    ("grep -R 'websocket' /opt/bobodo-vocal/*.py", "websocket_all_py"),
    ("grep -R 'WebSocket' /opt/bobodo-vocal/*.py", "WebSocket_class"),
    ("grep -R 'add_api_websocket_route' /opt/bobodo-vocal/", "add_api_ws"),
    ("grep -R 'include_router' /opt/bobodo-vocal/", "include_router"),
    ("grep -R 'FastAPI' /opt/bobodo-vocal/*.py", "fastapi_decl"),
]

for cmd, name in commands:
    results.append(f"\n### {name}")
    results.append(f"```bash")
    results.append(f"{cmd}")
    results.append(f"```")
    stdin, stdout, stderr = client.exec_command(cmd, timeout=15)
    exit_code = stdout.channel.recv_exit_status()
    out = stdout.read().decode('utf-8', errors='replace').strip()
    err = stderr.read().decode('utf-8', errors='replace').strip()
    results.append(f"\n**Exit:** {exit_code}")
    if out:
        results.append(f"```")
        results.append(out)
        results.append(f"```")
    if err:
        results.append(f"**STDERR:** {err}")

results.append("\n---\n")
results.append("# BOBODO_WS_REGISTRATION\n")
results.append("## Mission 2 — Contenu exact fichiers\n")

file_commands = [
    ("cat /opt/bobodo-vocal/main.py", "main_py_full"),
    ("cat /opt/bobodo-vocal/websocket_handler.py", "websocket_handler_full"),
]

for cmd, name in file_commands:
    results.append(f"\n### {name}")
    results.append(f"```bash")
    results.append(f"{cmd}")
    results.append(f"```")
    stdin, stdout, stderr = client.exec_command(cmd, timeout=15)
    exit_code = stdout.channel.recv_exit_status()
    out = stdout.read().decode('utf-8', errors='replace').strip()
    results.append(f"\n**Exit:** {exit_code}")
    results.append(f"```python")
    results.append(out)
    results.append(f"```")

client.close()

output = "\n".join(results)
with open("c:\\Users\\fasop\\AndroidStudioProjects\\academia\\.windsurf\\BOBODO_WS_ROUTE_DISCOVERY.md", "w", encoding="utf-8") as f:
    f.write(output)
print(output[:3000])
print("\n[... output truncated, full file written to .windsurf/BOBODO_WS_ROUTE_DISCOVERY.md ...]")

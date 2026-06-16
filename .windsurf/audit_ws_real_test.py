#!/usr/bin/env python3
"""Mission 3 — Test WebSocket réel avec client python websocket"""
import paramiko

HOST = "185.167.97.144"
USER = "root"
PASSWORD = "Nexiomgroup@Academia0"

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect(HOST, username=USER, password=PASSWORD, timeout=20, banner_timeout=15, auth_timeout=15)

results = []
results.append("# BOBODO_WS_REAL_TEST\n")
results.append("## Mission 3 — Test avec vrai client WebSocket\n")

# Installer websocat ou tester avec python websockets
py_test = """
import asyncio
import websockets
import json

async def test_ws(url, label):
    print(f"\\n--- Testing {label}: {url} ---")
    try:
        async with websockets.connect(url, timeout=10) as ws:
            print(f"CONNECTED to {url}")
            # Send session_id first
            await ws.send(json.dumps({"type": "session_id", "session_id": "test-session-123"}))
            print("Sent session_id")
            # Send ping
            await ws.send(json.dumps({"type": "ping"}))
            print("Sent ping")
            # Wait for response
            response = await asyncio.wait_for(ws.recv(), timeout=5)
            print(f"Received: {response}")
            return True
    except Exception as e:
        print(f"ERROR: {type(e).__name__}: {e}")
        return False

urls = [
    ("ws://localhost:8000/ws", "localhost_ws"),
    ("ws://localhost:8000/ws?session_id=test", "localhost_ws_query"),
    ("ws://127.0.0.1:8000/ws", "127_ws"),
    ("ws://185.167.97.144:8000/ws", "public_ws"),
]

for url, label in urls:
    result = asyncio.run(test_ws(url, label))
    print(f"Result {label}: {'SUCCESS' if result else 'FAILED'}")
"""

# Écrire le script sur le serveur
stdin, stdout, stderr = client.exec_command("cat > /tmp/test_ws.py << 'EOF'\n" + py_test + "\nEOF", timeout=10)
stdout.channel.recv_exit_status()

results.append("\n### Script de test écrit sur /tmp/test_ws.py")

# Exécuter le test
stdin, stdout, stderr = client.exec_command("cd /opt/bobodo-vocal && source venv/bin/activate && python /tmp/test_ws.py 2>&1", timeout=60, get_pty=True)
exit_code = stdout.channel.recv_exit_status()
out = stdout.read().decode('utf-8', errors='replace')
err = stderr.read().decode('utf-8', errors='replace')

results.append(f"\n**Exit code:** {exit_code}")
results.append("**STDOUT:**")
results.append("```")
results.append(out)
results.append("```")
if err.strip():
    results.append("**STDERR:**")
    results.append("```")
    results.append(err)
    results.append("```")

client.close()

output = "\n".join(results)
with open("c:\\Users\\fasop\\AndroidStudioProjects\\academia\\.windsurf\\BOBODO_WS_REAL_TEST.md", "w", encoding="utf-8") as f:
    f.write(output)
print(output)

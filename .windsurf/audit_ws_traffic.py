#!/usr/bin/env python3
"""Mission 4 — Test trafic réel WebSocket + journalctl logs"""
import paramiko

HOST = "185.167.97.144"
USER = "root"
PASSWORD = "Nexiomgroup@Academia0"

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect(HOST, username=USER, password=PASSWORD, timeout=20, banner_timeout=15, auth_timeout=15)

results = []
results.append("# BOBODO_WS_TRAFFIC_PROOF\n")
results.append("## Mission 4 — Test audio + capture logs\n")

# Script qui envoie du faux audio et lit les logs
py_script = '''
import asyncio
import websockets
import json
import base64

async def test_audio():
    uri = "ws://localhost:8000/ws"
    print(f"Connecting to {uri}")
    try:
        async with websockets.connect(uri, timeout=10) as ws:
            print("CONNECTED")
            # Send session_id first
            await ws.send(json.dumps({"type": "session_id", "session_id": "audit-test-12345"}))
            print("Sent session_id")
            
            # Send fake audio (empty base64)
            fake_audio = base64.b64encode(b"\\x00" * 3200).decode("utf-8")  # 200ms of silence
            await ws.send(json.dumps({"type": "audio", "audio": fake_audio}))
            print("Sent fake audio (3200 bytes)")
            
            # Wait for possible responses
            for i in range(5):
                try:
                    msg = await asyncio.wait_for(ws.recv(), timeout=3)
                    print(f"Received: {msg[:200]}")
                except asyncio.TimeoutError:
                    print(f"Timeout waiting for msg {i}")
                    break
            
            print("Closing...")
    except Exception as e:
        print(f"ERROR: {type(e).__name__}: {e}")

asyncio.run(test_audio())
'''

stdin, stdout, stderr = client.exec_command("cat > /tmp/test_audio_ws.py << 'EOF'\n" + py_script + "\nEOF", timeout=10)
stdout.channel.recv_exit_status()

# Lancer le test
results.append("\n### Test d'envoi audio exécuté")
stdin, stdout, stderr = client.exec_command("cd /opt/bobodo-vocal && source venv/bin/activate && python /tmp/test_audio_ws.py 2>&1", timeout=60, get_pty=True)
exit_code = stdout.channel.recv_exit_status()
out = stdout.read().decode('utf-8', errors='replace')
results.append(f"**Exit code:** {exit_code}")
results.append("**STDOUT:**")
results.append("```")
results.append(out)
results.append("```")

# Lire les logs du service
results.append("\n### Logs journalctl du service (30 dernières lignes)")
stdin, stdout, stderr = client.exec_command("journalctl -u bobodo-vocal --no-pager -n 30 2>&1", timeout=15)
exit_code = stdout.channel.recv_exit_status()
out = stdout.read().decode('utf-8', errors='replace')
results.append("**STDOUT:**")
results.append("```")
results.append(out)
results.append("```")

# Lire les logs avec grep sur la session
results.append("\n### Logs filtrés sur 'audit-test-12345'")
stdin, stdout, stderr = client.exec_command("journalctl -u bobodo-vocal --no-pager -n 50 | grep -i 'audit-test-12345' 2>&1 || echo 'NO_LOGS_FOR_SESSION'", timeout=15)
exit_code = stdout.channel.recv_exit_status()
out = stdout.read().decode('utf-8', errors='replace')
results.append("**STDOUT:**")
results.append("```")
results.append(out)
results.append("```")

client.close()

output = "\n".join(results)
with open("c:\\Users\\fasop\\AndroidStudioProjects\\academia\\.windsurf\\BOBODO_WS_TRAFFIC_PROOF.md", "w", encoding="utf-8") as f:
    f.write(output)
print(output)

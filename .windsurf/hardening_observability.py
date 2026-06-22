import paramiko

HOST = "185.167.97.144"
USER = "root"
PASS = "Nexiomgroup@Academia0"

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(HOST, username=USER, password=PASS)

# Mission 1: Check what's currently logged
print("=== MISSION 1 — OBSERVABILITÉ ===\n")

# Check for key log patterns
patterns = {
    "session_id": "STT_SESSION:",
    "durée STT": "STT_LATENCY",
    "durée Bobodo": "BOBODO_CLIENT",
    "durée TTS": "TTS_START|Synthesis completed",
    "durée totale": "audio_response",
    "erreurs websocket": "WebSocket error",
    "déconnexions": "connection closed",
    "reconnexions": "connection established",
    "sessions simultanées": "Active:",
}

stdin, stdout, stderr = ssh.exec_command(
    "journalctl -u bobodo-vocal --since='3 hours ago' | tail -200"
)
logs = stdout.read().decode()

print("Dernières 200 lignes de logs analysées:\n")
for metric, pattern in patterns.items():
    count = sum(1 for line in logs.split('\n') if any(p in line for p in pattern.split('|')))
    present = "✅" if count > 0 else "❌"
    print(f"  {present} {metric}: {count} occurrences (pattern: '{pattern}')")

# Check specific log format
print("\n--- Exemple logs STT_LATENCY ---")
stdin, stdout, stderr = ssh.exec_command(
    "journalctl -u bobodo-vocal --since='3 hours ago' | grep STT_LATENCY | tail -5"
)
print(stdout.read().decode()[:1000])

print("--- Exemple logs BOBODO_CLIENT ---")
stdin, stdout, stderr = ssh.exec_command(
    "journalctl -u bobodo-vocal --since='3 hours ago' | grep 'BOBODO_CLIENT.*Response\\|BOBODO_CLIENT.*Sending' | tail -5"
)
print(stdout.read().decode()[:1000])

print("--- Exemple logs TTS ---")
stdin, stdout, stderr = ssh.exec_command(
    "journalctl -u bobodo-vocal --since='3 hours ago' | grep -E 'TTS_START|Synthesis completed' | tail -5"
)
print(stdout.read().decode()[:1000])

print("--- Sessions actives actuelles ---")
stdin, stdout, stderr = ssh.exec_command(
    "journalctl -u bobodo-vocal --since='3 hours ago' | grep 'Active:' | tail -5"
)
print(stdout.read().decode()[:500])

# Service status
stdin, stdout, stderr = ssh.exec_command("systemctl status bobodo-vocal --no-pager | head -15")
print("--- Service status ---")
print(stdout.read().decode()[:1000])

ssh.close()
print("Done.")

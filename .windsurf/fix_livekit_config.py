#!/usr/bin/env python3
"""Fix LiveKit config: disable TURN (no domain available) and restart."""
import paramiko
import time
import json
from pathlib import Path

SERVER_IP = "185.220.204.214"
SERVER_USER = "root"
SERVER_PASS = "Ouedraogogilbert@Wendenkoote0"

# Load credentials from previous install
creds_path = Path(__file__).parent / "livekit_credentials.json"
creds = json.loads(creds_path.read_text())
LIVEKIT_API_KEY = creds["livekit_api_key"]
LIVEKIT_API_SECRET = creds["livekit_api_secret"]

def ssh_exec(client, cmd, timeout=120):
    print(f"$ {cmd[:150]}")
    stdin, stdout, stderr = client.exec_command(cmd, timeout=timeout)
    exit_code = stdout.channel.recv_exit_status()
    out = stdout.read().decode('utf-8', errors='replace')
    err = stderr.read().decode('utf-8', errors='replace')
    if out.strip():
        print(out.strip()[-500:])
    if err.strip() and exit_code != 0:
        print(f"STDERR: {err.strip()[-300:]}")
    return exit_code, out, err

def main():
    print("=== FIX LIVEKIT CONFIG ===")
    
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(SERVER_IP, username=SERVER_USER, password=SERVER_PASS, timeout=30)
    print("SSH OK")

    # Fix config: disable TURN (requires domain which we don't have)
    livekit_yaml = f"""port: 7880
bind_addresses:
  - ""
rtc:
  port_range_start: 50000
  port_range_end: 60000
  tcp_port: 7881
  use_external_ip: true
keys:
  {LIVEKIT_API_KEY}: {LIVEKIT_API_SECRET}
logging:
  level: info
room:
  auto_create: true
  empty_timeout: 300
  max_participants: 100
"""

    ssh_exec(client, f"cat > /opt/livekit/livekit.yaml << 'LKEOF'\n{livekit_yaml}LKEOF")
    print("Config corrigee (TURN desactive)")

    # Restart
    ssh_exec(client, "cd /opt/livekit && docker compose down")
    ssh_exec(client, "cd /opt/livekit && docker compose up -d")
    
    print("Attente 8s...")
    time.sleep(8)

    # Verify
    ssh_exec(client, "docker ps --format 'table {{.Names}}\t{{.Status}}'")
    rc, out, _ = ssh_exec(client, f"curl -s -o /dev/null -w '%{{http_code}}' http://localhost:7880")
    
    if "200" in out or "404" in out or "405" in out:
        print("\n*** LiveKit Server est EN LIGNE! ***")
    else:
        print(f"\nCode reponse: {out}")
        ssh_exec(client, "docker logs livekit-server --tail 30")

    # Check logs
    print("\n--- Logs LiveKit ---")
    ssh_exec(client, "docker logs livekit-server --tail 10")

    client.close()
    print("\nDone!")

if __name__ == "__main__":
    main()

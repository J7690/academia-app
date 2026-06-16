"""
Fix SSH access by rebooting the server via Kamatera API
Then reconnect and fix the firewall + verify LiveKit
"""
import requests
import json
import time

API_URL = "https://console.kamatera.com/service"
CLIENT_ID = "54ae6bec54550d349e6181c51e2b925c"
SECRET = "cdf8f98e556dfe28243aa243104801a7"
HEADERS = {"AuthClientId": CLIENT_ID, "AuthSecret": SECRET, "Content-Type": "application/json"}

SERVER_ID = "fe69db0e-8367-4da3-9126-cde effa10fc8"
SERVER_NAME = "academia-livekit"

# Step 1: Try to execute command via Kamatera API (some providers allow this)
print("=" * 50)
print("Attempting server power cycle via API...")
print("=" * 50)

# Try cloudcli API
API2 = "https://cloudcli.cloudwm.com"
HEADERS2 = {"AuthClientId": CLIENT_ID, "AuthSecret": SECRET, "Content-Type": "application/json"}

# First, get server info
r = requests.post(f"{API2}/service/server/info", headers=HEADERS2, json={"name": SERVER_NAME})
print(f"  Server info: HTTP {r.status_code}")
if r.status_code == 200:
    info = r.json()
    if isinstance(info, list) and info:
        server = info[0]
        server_id = server.get("id", "")
        print(f"  ID: {server_id}")
        print(f"  Power: {server.get('power', '?')}")
        print(f"  IP: {server.get('networks', [{}])[0].get('ips', ['?'])[0] if server.get('networks') else '?'}")

# Step 2: Power off then power on (hard reset)
print("\n  Powering OFF...")
r2 = requests.post(f"{API2}/service/server/poweroff", headers=HEADERS2, json={"name": SERVER_NAME, "force": True})
print(f"  Power OFF: HTTP {r2.status_code} — {r2.text[:200]}")

# Wait for power off
print("  Waiting 15 seconds...")
time.sleep(15)

print("  Powering ON...")
r3 = requests.post(f"{API2}/service/server/poweron", headers=HEADERS2, json={"name": SERVER_NAME})
print(f"  Power ON: HTTP {r3.status_code} — {r3.text[:200]}")

# Wait for boot
print("  Waiting 30 seconds for boot...")
time.sleep(30)

# Step 3: Try SSH again
print("\n" + "=" * 50)
print("Trying SSH connection...")
print("=" * 50)

import paramiko
import sys

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

for attempt in range(5):
    try:
        print(f"  Attempt {attempt + 1}/5...")
        client.connect("185.181.8.55", username="root", password="Wenden@Koote2026", timeout=15)
        print("  ✅ SSH connected!")
        
        # Immediately fix the firewall
        def ssh_exec(cmd, timeout=60):
            print(f"\n  $ {cmd}")
            stdin, stdout, stderr = client.exec_command(cmd, timeout=timeout)
            out = stdout.read().decode('utf-8', errors='replace')
            err = stderr.read().decode('utf-8', errors='replace')
            if out.strip():
                print(f"  → {out.strip()[:400]}")
            if err.strip():
                print(f"  ERR: {err.strip()[:200]}")
            return out.strip()

        # Fix firewall - allow SSH first!
        ssh_exec("ufw allow 22/tcp")
        ssh_exec("ufw allow 7880/tcp")
        ssh_exec("ufw allow 7881/tcp")
        ssh_exec("ufw allow 50000:60000/udp")
        ssh_exec("ufw allow 3478/udp")
        ssh_exec("ufw allow 5349/tcp")
        ssh_exec("ufw status")
        
        # Check LiveKit binary
        ssh_exec("which livekit-server || echo 'NOT FOUND'")
        ssh_exec("livekit-server --version 2>&1 || echo 'version check failed'")
        
        # Check if LiveKit config exists
        ssh_exec("cat /etc/livekit.yaml")
        
        # Check LiveKit service status
        ssh_exec("systemctl status livekit --no-pager 2>&1 || echo 'service not found'")
        
        # Check logs
        ssh_exec("journalctl -u livekit --no-pager -n 20 2>&1")
        
        # Try to start it
        ssh_exec("systemctl restart livekit 2>&1")
        time.sleep(3)
        ssh_exec("systemctl status livekit --no-pager -l 2>&1")
        
        # Check ports
        ssh_exec("ss -tlnp | grep -E '7880|7881'")
        
        # Test curl
        out = ssh_exec("curl -s -o /dev/null -w '%{http_code}' http://localhost:7880 2>&1")
        
        if "200" in out or "404" in out:
            print("\n  ✅ LiveKit is running on port 7880!")
        else:
            print(f"\n  ⚠️ Port 7880 response: {out}")
            # Maybe we need to download binary properly
            ssh_exec("ls -la /usr/local/bin/livekit-server 2>&1")
            ssh_exec("file /usr/local/bin/livekit-server 2>&1")
        
        client.close()
        break
    except Exception as e:
        print(f"  ❌ Attempt {attempt+1} failed: {e}")
        if attempt < 4:
            print(f"  Waiting 15 seconds before retry...")
            time.sleep(15)
        else:
            print("  ❌ All attempts failed. Server may still be booting.")

print("\n🏁 Done.")

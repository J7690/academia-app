"""
Recreate Kamatera server: delete old (SSH locked) + create new
Then install LiveKit properly (with SSH port allowed BEFORE enabling ufw)
"""
import requests
import json
import time
import paramiko
import secrets
import sys

API = "https://cloudcli.cloudwm.com"
CLIENT_ID = "54ae6bec54550d349e6181c51e2b925c"
SECRET_KEY = "cdf8f98e556dfe28243aa243104801a7"
HEADERS = {"AuthClientId": CLIENT_ID, "AuthSecret": SECRET_KEY, "Content-Type": "application/json"}

SERVER_NAME = "academia-livekit"
PASSWORD = "Wenden@Koote2026"

# ═══════════════════════════════════════════════════════════════
# STEP 1: Delete old server
# ═══════════════════════════════════════════════════════════════
print("=" * 60)
print("STEP 1: Delete old server")
print("=" * 60)

r = requests.post(f"{API}/service/server/terminate", headers=HEADERS, json={
    "name": SERVER_NAME,
    "force": True,
})
print(f"  Terminate: HTTP {r.status_code} — {r.text[:200]}")

if r.status_code == 200:
    task_ids = r.json()
    print(f"  Task IDs: {task_ids}")
    # Wait for termination
    print("  Waiting 30s for termination...")
    time.sleep(30)
else:
    print("  Trying poweroff + terminate...")
    r2 = requests.post(f"{API}/service/server/poweroff", headers=HEADERS, json={"name": SERVER_NAME, "force": True})
    print(f"  Poweroff: HTTP {r2.status_code}")
    time.sleep(15)
    r3 = requests.post(f"{API}/service/server/terminate", headers=HEADERS, json={"name": SERVER_NAME, "force": True})
    print(f"  Terminate: HTTP {r3.status_code} — {r3.text[:200]}")
    time.sleep(30)

# ═══════════════════════════════════════════════════════════════
# STEP 2: Create new server
# ═══════════════════════════════════════════════════════════════
print("\n" + "=" * 60)
print("STEP 2: Create new server")
print("=" * 60)

create_payload = {
    "name": SERVER_NAME,
    "password": PASSWORD,
    "datacenter": "EU",
    "image": "ubuntu_server_22.04_64-bit",
    "cpu": "2B",
    "ram": 4096,
    "disk": "size=40",
    "dailybackup": False,
    "managed": False,
    "network": "name=wan,ip=auto",
    "quantity": 1,
    "billingcycle": "monthly",
    "monthlypackage": "",
    "poweronaftercreate": True,
}

r = requests.post(f"{API}/service/server", headers=HEADERS, json=create_payload)
print(f"  Create: HTTP {r.status_code}")
print(f"  Response: {r.text[:300]}")

if r.status_code != 200:
    # Try alternative format
    print("  Trying alternative format...")
    create_payload2 = {
        "name": SERVER_NAME,
        "password": PASSWORD,
        "datacenter": "EU",
        "image": "ubuntu_server_22.04_64-bit",
        "cpu": "2B",
        "ram": 4096,
        "disk": [{"size": 40}],
        "dailybackup": "no",
        "managed": "no",
        "networks": [{"name": "wan", "ip": "auto"}],
        "quantity": 1,
        "billingcycle": "monthly",
    }
    r = requests.post(f"{API}/service/server", headers=HEADERS, json=create_payload2)
    print(f"  Create v2: HTTP {r.status_code}")
    print(f"  Response: {r.text[:300]}")

# Wait for creation
if r.status_code == 200:
    task_ids = r.json()
    print(f"  Creation task: {task_ids}")
    
    # Poll until complete
    for i in range(30):
        time.sleep(15)
        # Check server info
        r_info = requests.post(f"{API}/service/server/info", headers=HEADERS, json={"name": SERVER_NAME})
        if r_info.status_code == 200:
            servers = r_info.json()
            if isinstance(servers, list) and servers:
                server = servers[0]
                power = server.get("power", "?")
                networks = server.get("networks", [])
                ip = networks[0].get("ips", ["?"])[0] if networks else "?"
                print(f"  [{i*15}s] Power: {power}, IP: {ip}")
                if power == "on" and ip != "?" and ip != "auto":
                    print(f"\n  ✅ Server ready! IP: {ip}")
                    NEW_IP = ip
                    break
        else:
            print(f"  [{i*15}s] Waiting... (HTTP {r_info.status_code})")
    else:
        print("  ❌ Timeout waiting for server creation")
        sys.exit(1)
else:
    print("  ❌ Server creation failed")
    sys.exit(1)

# ═══════════════════════════════════════════════════════════════
# STEP 3: Wait for SSH to be ready, then install LiveKit
# ═══════════════════════════════════════════════════════════════
print("\n" + "=" * 60)
print(f"STEP 3: Connect SSH to {NEW_IP} and install LiveKit")
print("=" * 60)

# Wait a bit more for SSH to come up
print("  Waiting 30s for SSH to come up...")
time.sleep(30)

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

connected = False
for attempt in range(8):
    try:
        print(f"  SSH attempt {attempt+1}/8...")
        client.connect(NEW_IP, username="root", password=PASSWORD, timeout=15)
        print("  ✅ SSH connected!")
        connected = True
        break
    except Exception as e:
        print(f"  ❌ {e}")
        if attempt < 7:
            time.sleep(15)

if not connected:
    print("  ❌ Could not connect via SSH after all attempts")
    sys.exit(1)

def ssh_exec(cmd, timeout=120):
    print(f"\n  $ {cmd}")
    stdin, stdout, stderr = client.exec_command(cmd, timeout=timeout)
    out = stdout.read().decode('utf-8', errors='replace')
    err = stderr.read().decode('utf-8', errors='replace')
    code = stdout.channel.recv_exit_status()
    if out.strip():
        print(f"  → {out.strip()[:500]}")
    if err.strip() and code != 0:
        print(f"  ERR: {err.strip()[:300]}")
    return out.strip(), code

# System info
ssh_exec("uname -a")
ssh_exec("cat /etc/os-release | head -3")

# Update
print("\n  Updating system...")
ssh_exec("apt-get update -qq", timeout=120)
ssh_exec("DEBIAN_FRONTEND=noninteractive apt-get install -y -qq curl wget", timeout=120)

# Download LiveKit binary
print("\n  Downloading LiveKit server...")
ssh_exec("""
ARCH=$(dpkg --print-architecture)
VERSION=$(curl -s https://api.github.com/repos/livekit/livekit/releases/latest | grep -oP '"tag_name":\\s*"v\\K[^"]+' || echo "1.8.3")
echo "Installing LiveKit v$VERSION for $ARCH"
if [ "$ARCH" = "amd64" ]; then
    curl -sL "https://github.com/livekit/livekit/releases/download/v${VERSION}/livekit-server_${VERSION}_linux_amd64.tar.gz" -o /tmp/lk.tar.gz
elif [ "$ARCH" = "arm64" ]; then
    curl -sL "https://github.com/livekit/livekit/releases/download/v${VERSION}/livekit-server_${VERSION}_linux_arm64.tar.gz" -o /tmp/lk.tar.gz
fi
cd /tmp && tar -xzf lk.tar.gz
cp /tmp/livekit-server /usr/local/bin/livekit-server
chmod +x /usr/local/bin/livekit-server
echo "Done"
""", timeout=120)

out_ver, _ = ssh_exec("livekit-server --version 2>&1")
print(f"\n  LiveKit version: {out_ver}")

# Generate keys
api_key = "API" + secrets.token_hex(8)
api_secret = secrets.token_hex(24)
print(f"\n  API Key:    {api_key}")
print(f"  API Secret: {api_secret}")

# Create config
config = f"""port: 7880
rtc:
  tcp_port: 7881
  port_range_start: 50000
  port_range_end: 60000
  use_external_ip: true
keys:
  {api_key}: {api_secret}
logging:
  level: info
"""
ssh_exec(f"cat > /etc/livekit.yaml << 'EOF'\n{config}\nEOF")

# Create systemd service
service = """[Unit]
Description=LiveKit Server
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/livekit-server --config /etc/livekit.yaml
Restart=always
RestartSec=5
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
"""
ssh_exec(f"cat > /etc/systemd/system/livekit.service << 'EOF'\n{service}\nEOF")
ssh_exec("systemctl daemon-reload")
ssh_exec("systemctl enable livekit")
ssh_exec("systemctl start livekit")
time.sleep(3)

# Firewall — SSH FIRST this time!
print("\n  Configuring firewall (SSH first!)...")
ssh_exec("ufw allow 22/tcp")        # SSH — CRITICAL
ssh_exec("ufw allow 7880/tcp")      # LiveKit HTTP/WS
ssh_exec("ufw allow 7881/tcp")      # LiveKit RTC TCP
ssh_exec("ufw allow 50000:60000/udp")  # WebRTC UDP
ssh_exec("ufw allow 3478/udp")      # TURN
ssh_exec("ufw allow 5349/tcp")      # TURN TLS
ssh_exec("ufw --force enable")
ssh_exec("ufw status")

# Verify
time.sleep(2)
ssh_exec("systemctl status livekit --no-pager -l")
ssh_exec("ss -tlnp | grep -E '7880|7881'")
out_curl, _ = ssh_exec("curl -s -o /dev/null -w '%{http_code}' http://localhost:7880")

client.close()

# ═══════════════════════════════════════════════════════════════
# SUMMARY
# ═══════════════════════════════════════════════════════════════
print("\n\n" + "=" * 60)
print("🏁 RÉSUMÉ")
print("=" * 60)
print(f"""
  Serveur:          {NEW_IP}
  LiveKit URL:      ws://{NEW_IP}:7880
  LIVEKIT_API_KEY:    {api_key}
  LIVEKIT_API_SECRET: {api_secret}
  Port 7880 curl:   {out_curl}
""")

# Save credentials
creds = {
    "server_ip": NEW_IP,
    "api_key": api_key,
    "api_secret": api_secret,
    "url": f"ws://{NEW_IP}:7880",
    "http_url": f"http://{NEW_IP}:7880",
}
with open("livekit_credentials.json", "w") as f:
    json.dump(creds, f, indent=2)
print("  ✅ Credentials saved to livekit_credentials.json")

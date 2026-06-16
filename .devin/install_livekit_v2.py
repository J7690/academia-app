"""
Install LiveKit on new Kamatera server 185.167.96.214
Steps:
1. SSH in
2. Update system
3. Install LiveKit
4. Generate API keys
5. Configure firewall (SSH first!)
6. Start LiveKit service
"""
import paramiko
import time
import secrets
import string
import json

SERVER_IP = "185.167.96.214"
ROOT_PASS = "Wenden@Koote2026"

def ssh_exec(ssh, cmd, timeout=120):
    print(f"  $ {cmd}")
    stdin, stdout, stderr = ssh.exec_command(cmd, timeout=timeout)
    out = stdout.read().decode('utf-8', errors='replace')
    err = stderr.read().decode('utf-8', errors='replace')
    exit_code = stdout.channel.recv_exit_status()
    if out.strip():
        print(f"    → {out.strip()[:500]}")
    if err.strip() and exit_code != 0:
        print(f"    ⚠ {err.strip()[:300]}")
    return out.strip(), err.strip(), exit_code

def generate_key(length=32):
    chars = string.ascii_letters + string.digits
    return ''.join(secrets.choice(chars) for _ in range(length))

# Generate LiveKit keys
LIVEKIT_API_KEY = "API" + generate_key(12)
LIVEKIT_API_SECRET = generate_key(36)
LIVEKIT_URL = f"ws://{SERVER_IP}:7880"

print(f"LiveKit API Key:    {LIVEKIT_API_KEY}")
print(f"LiveKit API Secret: {LIVEKIT_API_SECRET}")
print(f"LiveKit URL:        {LIVEKIT_URL}")

# Connect via SSH
print(f"\n{'='*50}")
print(f"Connecting to {SERVER_IP}...")
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

for attempt in range(5):
    try:
        ssh.connect(SERVER_IP, port=22, username='root', password=ROOT_PASS, timeout=30)
        print("  ✅ SSH connected!")
        break
    except Exception as e:
        print(f"  Attempt {attempt+1}/5 failed: {e}")
        time.sleep(10)
else:
    print("  ❌ Cannot connect via SSH!")
    exit(1)

# Step 1: Update system
print(f"\n{'='*50}")
print("Step 1: Update system...")
ssh_exec(ssh, "apt-get update -y", timeout=180)
ssh_exec(ssh, "DEBIAN_FRONTEND=noninteractive apt-get upgrade -y", timeout=300)

# Step 2: Install dependencies
print(f"\n{'='*50}")
print("Step 2: Install dependencies...")
ssh_exec(ssh, "DEBIAN_FRONTEND=noninteractive apt-get install -y curl wget unzip ffmpeg", timeout=180)

# Step 3: Install LiveKit server
print(f"\n{'='*50}")
print("Step 3: Install LiveKit server...")
ssh_exec(ssh, "curl -sSL https://get.livekit.io | bash", timeout=180)

# Verify installation
out, _, _ = ssh_exec(ssh, "which livekit-server || find / -name 'livekit-server' -type f 2>/dev/null | head -5")
if not out:
    print("  LiveKit binary not found, trying alternative install...")
    ssh_exec(ssh, "curl -sSL https://get.livekit.io/cli | bash", timeout=120)
    # Try direct binary download
    ssh_exec(ssh, """
cd /tmp && \
curl -sSL https://github.com/livekit/livekit/releases/latest/download/livekit-server_linux_amd64.tar.gz -o livekit.tar.gz && \
tar xzf livekit.tar.gz && \
mv livekit-server /usr/local/bin/ && \
chmod +x /usr/local/bin/livekit-server
""", timeout=120)

out, _, _ = ssh_exec(ssh, "livekit-server --version 2>&1 || /usr/local/bin/livekit-server --version 2>&1")
print(f"  LiveKit version: {out}")

# Step 4: Create config
print(f"\n{'='*50}")
print("Step 4: Create LiveKit config...")
config_yaml = f"""port: 7880
rtc:
  port_range_start: 50000
  port_range_end: 60000
  use_external_ip: true
  tcp_port: 7881
keys:
  {LIVEKIT_API_KEY}: {LIVEKIT_API_SECRET}
logging:
  level: info
"""

ssh_exec(ssh, "mkdir -p /etc/livekit")
ssh_exec(ssh, f"cat > /etc/livekit/livekit.yaml << 'ENDCONFIG'\n{config_yaml}\nENDCONFIG")

# Verify config
ssh_exec(ssh, "cat /etc/livekit/livekit.yaml")

# Step 5: Create systemd service
print(f"\n{'='*50}")
print("Step 5: Create systemd service...")
service_unit = """[Unit]
Description=LiveKit Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/livekit-server --config /etc/livekit/livekit.yaml
Restart=always
RestartSec=5
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
"""
ssh_exec(ssh, f"cat > /etc/systemd/system/livekit.service << 'ENDSERVICE'\n{service_unit}\nENDSERVICE")
ssh_exec(ssh, "systemctl daemon-reload")
ssh_exec(ssh, "systemctl enable livekit")

# Step 6: Configure firewall CAREFULLY (SSH first!)
print(f"\n{'='*50}")
print("Step 6: Configure firewall...")
ssh_exec(ssh, "ufw default deny incoming")
ssh_exec(ssh, "ufw default allow outgoing")
ssh_exec(ssh, "ufw allow 22/tcp")        # SSH - MUST be first!
ssh_exec(ssh, "ufw allow 7880/tcp")      # LiveKit WebSocket
ssh_exec(ssh, "ufw allow 7881/tcp")      # LiveKit TCP
ssh_exec(ssh, "ufw allow 50000:60000/udp") # WebRTC UDP
ssh_exec(ssh, "echo 'y' | ufw enable")
ssh_exec(ssh, "ufw status")

# Step 7: Start LiveKit
print(f"\n{'='*50}")
print("Step 7: Start LiveKit server...")
ssh_exec(ssh, "systemctl start livekit")
time.sleep(3)
out, _, _ = ssh_exec(ssh, "systemctl status livekit")
print(f"  Service status: {out[:300]}")

# Step 8: Verify
print(f"\n{'='*50}")
print("Step 8: Verify LiveKit is running...")
out, _, _ = ssh_exec(ssh, "curl -s http://localhost:7880")
print(f"  Local test: {out[:200]}")

out, _, _ = ssh_exec(ssh, "ss -tlnp | grep 7880")
print(f"  Port 7880 listening: {out}")

ssh.close()

# Save results
print(f"\n{'='*50}")
print("✅ INSTALLATION COMPLETE!")
print(f"\nServer IP:          {SERVER_IP}")
print(f"LiveKit API Key:    {LIVEKIT_API_KEY}")
print(f"LiveKit API Secret: {LIVEKIT_API_SECRET}")
print(f"LiveKit URL:        {LIVEKIT_URL}")
print(f"LiveKit WS URL:     ws://{SERVER_IP}:7880")

# Save to config file
results = {
    "server_ip": SERVER_IP,
    "livekit_api_key": LIVEKIT_API_KEY,
    "livekit_api_secret": LIVEKIT_API_SECRET,
    "livekit_url": LIVEKIT_URL,
    "livekit_ws_url": f"ws://{SERVER_IP}:7880",
    "server_id": "691c8e25-7b2d-44b6-8158-34bdef44477a",
    "server_name": "academia-livekit2"
}
with open("livekit_credentials.json", "w") as f:
    json.dump(results, f, indent=2)
print(f"\nCredentials saved to livekit_credentials.json")

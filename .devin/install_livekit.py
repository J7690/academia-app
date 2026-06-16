"""
Install LiveKit Server on Kamatera VPS via SSH (paramiko)
"""
import paramiko
import time
import sys

HOST = "185.181.8.55"
USER = "root"
PASSWORD = "Wenden@Koote2026"

def ssh_exec(client, cmd, timeout=120):
    """Execute a command and return stdout"""
    print(f"\n  $ {cmd}")
    stdin, stdout, stderr = client.exec_command(cmd, timeout=timeout)
    out = stdout.read().decode('utf-8', errors='replace')
    err = stderr.read().decode('utf-8', errors='replace')
    exit_code = stdout.channel.recv_exit_status()
    if out.strip():
        # Truncate long output
        display = out.strip()[:500]
        print(f"  → {display}")
    if err.strip() and exit_code != 0:
        print(f"  ⚠️ STDERR: {err.strip()[:300]}")
    return out.strip(), exit_code

# Connect
print("=" * 50)
print(f"Connecting to {HOST}...")
print("=" * 50)

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

try:
    client.connect(HOST, username=USER, password=PASSWORD, timeout=15)
    print("  ✅ SSH connected!")
except Exception as e:
    print(f"  ❌ SSH connection failed: {e}")
    sys.exit(1)

# Step 1: Basic info
print("\n" + "=" * 50)
print("STEP 1: System info")
print("=" * 50)
ssh_exec(client, "uname -a")
ssh_exec(client, "cat /etc/os-release | head -3")
ssh_exec(client, "free -h | head -3")
ssh_exec(client, "df -h / | tail -1")

# Step 2: Update system
print("\n" + "=" * 50)
print("STEP 2: Update system packages")
print("=" * 50)
ssh_exec(client, "apt-get update -qq", timeout=120)
ssh_exec(client, "DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq", timeout=300)

# Step 3: Install LiveKit
print("\n" + "=" * 50)
print("STEP 3: Install LiveKit Server")
print("=" * 50)

# Download and install LiveKit binary
ssh_exec(client, "curl -sSL https://get.livekit.io -o /tmp/install_livekit.sh", timeout=30)
ssh_exec(client, "bash /tmp/install_livekit.sh", timeout=120)
ssh_exec(client, "livekit-server --version", timeout=10)

# Step 4: Generate LiveKit API keys
print("\n" + "=" * 50)
print("STEP 4: Generate LiveKit API keys")
print("=" * 50)

# Install livekit-cli for key generation
ssh_exec(client, "curl -sSL https://get.livekit.io/cli -o /tmp/install_cli.sh", timeout=30)
ssh_exec(client, "bash /tmp/install_cli.sh", timeout=60)

# Generate API key pair
out, _ = ssh_exec(client, "livekit-cli create-token --create --api-key devkey --api-secret secret --grant '{\"roomCreate\":true}' 2>&1 || echo 'cli_method_failed'")

# Alternative: generate keys manually
import secrets
api_key = "API" + secrets.token_hex(8)
api_secret = secrets.token_hex(24)
print(f"\n  Generated API Key:    {api_key}")
print(f"  Generated API Secret: {api_secret}")

# Step 5: Create LiveKit config
print("\n" + "=" * 50)
print("STEP 5: Create LiveKit config")
print("=" * 50)

livekit_config = f"""port: 7880
rtc:
  tcp_port: 7881
  port_range_start: 50000
  port_range_end: 60000
  use_external_ip: true
keys:
  {api_key}: {api_secret}
logging:
  level: info
turn:
  enabled: true
  domain: 185.181.8.55
  tls_port: 5349
  udp_port: 3478
"""

ssh_exec(client, f"cat > /etc/livekit.yaml << 'LKEOF'\n{livekit_config}\nLKEOF")
ssh_exec(client, "cat /etc/livekit.yaml")

# Step 6: Create systemd service
print("\n" + "=" * 50)
print("STEP 6: Create systemd service")
print("=" * 50)

service_content = """[Unit]
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

ssh_exec(client, f"cat > /etc/systemd/system/livekit.service << 'SVCEOF'\n{service_content}\nSVCEOF")
ssh_exec(client, "systemctl daemon-reload")
ssh_exec(client, "systemctl enable livekit")
ssh_exec(client, "systemctl start livekit")
time.sleep(3)
ssh_exec(client, "systemctl status livekit --no-pager -l")

# Step 7: Open firewall ports
print("\n" + "=" * 50)
print("STEP 7: Open firewall ports")
print("=" * 50)

ssh_exec(client, "ufw allow 7880/tcp")   # HTTP API + WebSocket
ssh_exec(client, "ufw allow 7881/tcp")   # RTC over TCP
ssh_exec(client, "ufw allow 50000:60000/udp")  # WebRTC UDP
ssh_exec(client, "ufw allow 3478/udp")   # TURN UDP
ssh_exec(client, "ufw allow 5349/tcp")   # TURN TLS
ssh_exec(client, "ufw --force enable 2>/dev/null || true")

# Step 8: Verify
print("\n" + "=" * 50)
print("STEP 8: Verify LiveKit is running")
print("=" * 50)

ssh_exec(client, "curl -s http://localhost:7880 || echo 'port 7880 not responding yet'")
ssh_exec(client, "ss -tlnp | grep 7880")
ssh_exec(client, "ss -tlnp | grep 7881")

client.close()

# Print summary
print("\n" + "=" * 50)
print("🏁 INSTALLATION TERMINÉE")
print("=" * 50)
print(f"""
  LiveKit Server: http://185.181.8.55:7880
  WebSocket URL:  ws://185.181.8.55:7880
  
  LIVEKIT_API_KEY:    {api_key}
  LIVEKIT_API_SECRET: {api_secret}
  LIVEKIT_URL:        ws://185.181.8.55:7880
  
  → Ces clés doivent être configurées dans Supabase Secrets
""")

# Save to file for later use
import json
with open("livekit_credentials.json", "w") as f:
    json.dump({
        "api_key": api_key,
        "api_secret": api_secret,
        "url": "ws://185.181.8.55:7880",
        "server_ip": "185.181.8.55",
    }, f, indent=2)
print("  ✅ Credentials saved to livekit_credentials.json")

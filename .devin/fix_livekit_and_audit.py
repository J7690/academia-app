"""
1. Fix LiveKit server startup
2. Configure Supabase secrets
3. Audit all references to old Kamatera/LiveKit in codebase
"""
import paramiko
import time
import json
import requests

HOST = "185.181.8.55"
USER = "root"
PASSWORD = "Wenden@Koote2026"

# LiveKit credentials generated during install
API_KEY = "APIfc30ce483af6b480"
API_SECRET = "c1d917f3bf7066d5423012ed19e0aaebfdaa4c24dfcafef5"
LIVEKIT_URL = f"ws://{HOST}:7880"

def ssh_exec(client, cmd, timeout=120):
    """Execute a command and return stdout"""
    print(f"\n  $ {cmd}")
    stdin, stdout, stderr = client.exec_command(cmd, timeout=timeout)
    out = stdout.read().decode('utf-8', errors='replace')
    err = stderr.read().decode('utf-8', errors='replace')
    exit_code = stdout.channel.recv_exit_status()
    if out.strip():
        display = out.strip()[:600]
        print(f"  → {display}")
    if err.strip():
        print(f"  STDERR: {err.strip()[:300]}")
    return out.strip(), exit_code

# ═══════════════════════════════════════════════════════════════
# PART 1: Fix LiveKit Server
# ═══════════════════════════════════════════════════════════════
print("=" * 60)
print("PART 1: Fix LiveKit Server")
print("=" * 60)

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect(HOST, username=USER, password=PASSWORD, timeout=15)
print("  ✅ SSH connected")

# Check if livekit-server binary exists and its location
ssh_exec(client, "which livekit-server || find / -name 'livekit-server' -type f 2>/dev/null | head -5")
ssh_exec(client, "livekit-server --version 2>&1 || echo 'binary not found'")

# Check logs
ssh_exec(client, "journalctl -u livekit --no-pager -n 30")

# Check if port is in use
ssh_exec(client, "ss -tlnp | grep -E '7880|7881'")
ssh_exec(client, "netstat -tlnp 2>/dev/null | grep -E '7880|7881' || true")

# Try running livekit-server directly to see the error
ssh_exec(client, "timeout 5 livekit-server --config /etc/livekit.yaml 2>&1 || true", timeout=15)

# Maybe it needs to be downloaded properly - check if binary is there
out, code = ssh_exec(client, "file /usr/local/bin/livekit-server 2>/dev/null || echo 'not found'")

if "not found" in out or "No such" in out:
    print("\n  ⚠️ LiveKit binary not found. Downloading manually...")
    # Download the latest LiveKit server binary directly
    ssh_exec(client, "apt-get install -y -qq wget", timeout=60)
    ssh_exec(client, """
ARCH=$(dpkg --print-architecture)
if [ "$ARCH" = "amd64" ]; then
    URL="https://github.com/livekit/livekit/releases/latest/download/livekit-server_linux_amd64.tar.gz"
elif [ "$ARCH" = "arm64" ]; then
    URL="https://github.com/livekit/livekit/releases/latest/download/livekit-server_linux_arm64.tar.gz"
fi
echo "Downloading $URL"
wget -q "$URL" -O /tmp/livekit-server.tar.gz
tar -xzf /tmp/livekit-server.tar.gz -C /usr/local/bin/ livekit-server
chmod +x /usr/local/bin/livekit-server
livekit-server --version
""", timeout=120)

# Restart service
ssh_exec(client, "systemctl restart livekit")
time.sleep(4)
ssh_exec(client, "systemctl status livekit --no-pager -l")
ssh_exec(client, "journalctl -u livekit --no-pager -n 15")

# Check port
time.sleep(2)
ssh_exec(client, "ss -tlnp | grep 7880")
out_curl, _ = ssh_exec(client, "curl -s -o /dev/null -w '%{http_code}' http://localhost:7880 || echo 'fail'")

if "200" in out_curl or "404" in out_curl or "403" in out_curl:
    print("\n  ✅ LiveKit is responding on port 7880!")
else:
    print(f"\n  ⚠️ LiveKit might not be running yet. curl returned: {out_curl}")
    # Check if there's a config issue
    ssh_exec(client, "livekit-server --config /etc/livekit.yaml --help 2>&1 | head -20 || true")

client.close()

# ═══════════════════════════════════════════════════════════════
# PART 2: Configure Supabase Secrets
# ═══════════════════════════════════════════════════════════════
print("\n\n" + "=" * 60)
print("PART 2: Configure Supabase Secrets")
print("=" * 60)

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

# Test the current livekit-token edge function to see what secrets it sees
print("  Testing livekit-token Edge Function with current secrets...")
r = requests.post(
    f"{SUPABASE_URL}/functions/v1/livekit-token",
    headers={
        "apikey": SERVICE_KEY,
        "Authorization": f"Bearer {SERVICE_KEY}",
        "Content-Type": "application/json",
    },
    json={"session_id": "test-check-config"},
)
print(f"  HTTP {r.status_code}: {r.text[:300]}")

# Note: Supabase secrets can only be set via CLI or dashboard
# We'll need to use the Supabase Management API
SUPABASE_ACCESS_TOKEN = None  # Would need this for management API

print(f"""
  ╔═══════════════════════════════════════════════════╗
  ║ SECRETS À CONFIGURER DANS SUPABASE DASHBOARD     ║
  ║                                                   ║
  ║ Dashboard → Settings → Edge Functions → Secrets   ║
  ║                                                   ║
  ║ LIVEKIT_API_KEY    = {API_KEY}  ║
  ║ LIVEKIT_API_SECRET = {API_SECRET[:20]}... ║
  ║ LIVEKIT_URL        = ws://{HOST}:7880    ║
  ╚═══════════════════════════════════════════════════╝
""")

print("🏁 Part 1 & 2 done. See summary above.")

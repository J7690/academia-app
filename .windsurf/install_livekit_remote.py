#!/usr/bin/env python3
"""
Script d'installation automatique de LiveKit Server sur le VPS Kamatera.
Se connecte en SSH et installe Docker + LiveKit.
"""
import paramiko
import time
import secrets
import string
import json
from pathlib import Path

# --- Configuration ---
SERVER_IP = "185.220.204.214"
SERVER_USER = "root"
SERVER_PASS = "Ouedraogogilbert@Wendenkoote0"

def generate_secret(length=32):
    alphabet = string.ascii_letters + string.digits
    return ''.join(secrets.choice(alphabet) for _ in range(length))

LIVEKIT_API_KEY = "APIKey" + generate_secret(12)
LIVEKIT_API_SECRET = generate_secret(40)

def ssh_exec(client, cmd, timeout=300):
    """Execute a command via SSH and return output."""
    print(f"\n$ {cmd[:120]}{'...' if len(cmd) > 120 else ''}")
    stdin, stdout, stderr = client.exec_command(cmd, timeout=timeout)
    exit_code = stdout.channel.recv_exit_status()
    out = stdout.read().decode('utf-8', errors='replace')
    err = stderr.read().decode('utf-8', errors='replace')
    if out.strip():
        # Print only last 500 chars to avoid flooding
        display = out.strip()[-500:]
        print(display)
    if err.strip() and exit_code != 0:
        print(f"STDERR: {err.strip()[-300:]}")
    if exit_code != 0:
        print(f"[Exit code: {exit_code}]")
    return exit_code, out, err

def main():
    print("=" * 60)
    print(" INSTALLATION LIVEKIT SERVER - ACADEMIA")
    print(f" Serveur: {SERVER_IP}")
    print(f" API Key: {LIVEKIT_API_KEY}")
    print(f" API Secret: {LIVEKIT_API_SECRET[:8]}...")
    print("=" * 60)

    # --- Connexion SSH ---
    print("\n--- Connexion SSH ---")
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        client.connect(SERVER_IP, username=SERVER_USER, password=SERVER_PASS, timeout=30)
        print("Connexion SSH OK!")
    except Exception as e:
        print(f"ERREUR connexion SSH: {e}")
        return

    # --- Etape 1: Verifier le systeme ---
    print("\n--- Etape 1: Verification systeme ---")
    ssh_exec(client, "cat /etc/os-release | head -5")
    ssh_exec(client, "free -m | head -3")
    ssh_exec(client, "df -h / | tail -1")

    # --- Etape 2: Mise a jour systeme ---
    print("\n--- Etape 2: Mise a jour systeme ---")
    ssh_exec(client, "apt-get update -y -qq", timeout=180)
    ssh_exec(client, "DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq", timeout=300)

    # --- Etape 3: Installer Docker ---
    print("\n--- Etape 3: Installation Docker ---")
    rc, out, _ = ssh_exec(client, "docker --version 2>/dev/null")
    if rc != 0:
        ssh_exec(client, "apt-get install -y -qq ca-certificates curl gnupg lsb-release", timeout=120)
        ssh_exec(client, "install -m 0755 -d /etc/apt/keyrings", timeout=30)
        ssh_exec(client, "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes", timeout=60)
        ssh_exec(client, "chmod a+r /etc/apt/keyrings/docker.gpg", timeout=10)
        ssh_exec(client, 'echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null', timeout=30)
        ssh_exec(client, "apt-get update -y -qq", timeout=120)
        ssh_exec(client, "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin", timeout=300)
        ssh_exec(client, "systemctl enable docker && systemctl start docker", timeout=30)
        print("Docker installe!")
    else:
        print(f"Docker deja installe: {out.strip()}")

    ssh_exec(client, "docker --version")

    # --- Etape 4: Configurer firewall ---
    print("\n--- Etape 4: Firewall ---")
    ssh_exec(client, "apt-get install -y -qq ufw", timeout=60)
    firewall_cmds = [
        "ufw allow 22/tcp",
        "ufw allow 80/tcp",
        "ufw allow 443/tcp",
        "ufw allow 443/udp",
        "ufw allow 7880/tcp",
        "ufw allow 7881/tcp",
        "ufw allow 50000:60000/udp",
        "ufw --force enable",
    ]
    for cmd in firewall_cmds:
        ssh_exec(client, cmd, timeout=15)
    print("Firewall configure!")

    # --- Etape 5: Creer la config LiveKit ---
    print("\n--- Etape 5: Configuration LiveKit ---")
    ssh_exec(client, "mkdir -p /opt/livekit", timeout=10)

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
turn:
  enabled: true
  domain: ""
  tls_port: 443
  udp_port: 443
  external_tls: false
webhook: {{}}
"""
    # Escape for shell
    escaped_yaml = livekit_yaml.replace("'", "'\\''")
    ssh_exec(client, f"cat > /opt/livekit/livekit.yaml << 'LKEOF'\n{livekit_yaml}LKEOF", timeout=15)
    print("Config LiveKit ecrite!")

    # --- Etape 6: Docker Compose ---
    print("\n--- Etape 6: Docker Compose ---")
    compose_yaml = f"""version: '3.8'

services:
  livekit:
    image: livekit/livekit-server:latest
    container_name: livekit-server
    restart: unless-stopped
    network_mode: host
    volumes:
      - /opt/livekit/livekit.yaml:/etc/livekit.yaml
    command: --config /etc/livekit.yaml --node-ip {SERVER_IP}
"""
    ssh_exec(client, f"cat > /opt/livekit/docker-compose.yaml << 'DCEOF'\n{compose_yaml}DCEOF", timeout=15)
    print("Docker Compose ecrit!")

    # --- Etape 7: Pull et lancer LiveKit ---
    print("\n--- Etape 7: Demarrage LiveKit ---")
    ssh_exec(client, "cd /opt/livekit && docker compose pull", timeout=300)
    ssh_exec(client, "cd /opt/livekit && docker compose up -d", timeout=60)

    # Attendre le demarrage
    print("Attente du demarrage (10s)...")
    time.sleep(10)

    # --- Etape 8: Verifier ---
    print("\n--- Etape 8: Verification ---")
    ssh_exec(client, "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'")
    rc, out, _ = ssh_exec(client, f"curl -s -o /dev/null -w '%{{http_code}}' http://localhost:7880")
    
    if "200" in out or "404" in out or "405" in out:
        print("\n*** LiveKit Server est EN LIGNE! ***")
        success = True
    else:
        print(f"\nATTENTION: LiveKit repond avec code: {out}")
        ssh_exec(client, "docker logs livekit-server --tail 20")
        success = False

    # --- Etape 9: Sauvegarder les credentials ---
    print("\n--- Etape 9: Sauvegarde credentials ---")
    creds = {
        "server_ip": SERVER_IP,
        "livekit_api_key": LIVEKIT_API_KEY,
        "livekit_api_secret": LIVEKIT_API_SECRET,
        "livekit_url": f"ws://{SERVER_IP}:7880",
        "livekit_http": f"http://{SERVER_IP}:7880",
    }

    # Sauvegarder localement
    creds_path = Path(__file__).parent / "livekit_credentials.json"
    creds_path.write_text(json.dumps(creds, indent=2))
    print(f"Credentials sauvegardees: {creds_path}")

    # Fermer SSH
    client.close()

    # --- Resume final ---
    print("\n" + "=" * 60)
    if success:
        print(" INSTALLATION TERMINEE AVEC SUCCES!")
    else:
        print(" INSTALLATION TERMINEE (verification necessaire)")
    print("=" * 60)
    print(f"""
Serveur: {SERVER_IP}
LiveKit HTTP:    http://{SERVER_IP}:7880
LiveKit WS:      ws://{SERVER_IP}:7880

LIVEKIT_API_KEY:    {LIVEKIT_API_KEY}
LIVEKIT_API_SECRET: {LIVEKIT_API_SECRET}
LIVEKIT_URL:        ws://{SERVER_IP}:7880

Commandes Supabase:
  supabase secrets set LIVEKIT_API_KEY={LIVEKIT_API_KEY}
  supabase secrets set LIVEKIT_API_SECRET={LIVEKIT_API_SECRET}
  supabase secrets set LIVEKIT_URL=ws://{SERVER_IP}:7880

Deployer l'Edge Function:
  supabase functions deploy livekit-token --no-verify-jwt
""")

if __name__ == "__main__":
    main()

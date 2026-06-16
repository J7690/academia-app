#!/usr/bin/env python3
"""
Installation complète LiveKit + Redis + Nginx sur le nouveau serveur Kamatera.
Serveur: 185.167.97.144 - Ubuntu 24.04 - 4 vCPU / 10GB RAM / 30GB SSD
"""
import paramiko
import time
import secrets
import string
import json
from pathlib import Path

# --- Configuration nouveau serveur ---
SERVER_IP = "185.167.97.144"
SERVER_USER = "root"
SERVER_PASS = "Nexiomgroup@Academia0"
SERVER_ID = "f6d2656b-0f80-4df1-ac62-53b26d6d921b"

# --- Génération credentials LiveKit ---
def generate_secret(length=32):
    alphabet = string.ascii_letters + string.digits
    return ''.join(secrets.choice(alphabet) for _ in range(length))

LIVEKIT_API_KEY = "APIKey" + generate_secret(12)
LIVEKIT_API_SECRET = generate_secret(40)

def ssh_exec(client, cmd, timeout=300):
    """Execute a command via SSH and return output."""
    print(f"\n$ {cmd[:150]}{'...' if len(cmd) > 150 else ''}")
    stdin, stdout, stderr = client.exec_command(cmd, timeout=timeout)
    exit_code = stdout.channel.recv_exit_status()
    out = stdout.read().decode('utf-8', errors='replace')
    err = stderr.read().decode('utf-8', errors='replace')
    if out.strip():
        display = out.strip()[-500:]
        print(display)
    if err.strip() and exit_code != 0:
        print(f"STDERR: {err.strip()[-300:]}")
    if exit_code != 0:
        print(f"[Exit code: {exit_code}]")
    return exit_code, out, err

def main():
    print("=" * 60)
    print(" INSTALLATION LIVEKIT + REDIS + NGINX - NOUVEAU SERVEUR")
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
        print("✓ Connexion SSH OK!")
    except Exception as e:
        print(f"ERREUR connexion SSH: {e}")
        return

    # --- Étape 1: Vérification système ---
    print("\n--- Étape 1: Vérification système ---")
    ssh_exec(client, "cat /etc/os-release | head -5")
    ssh_exec(client, "free -m | head -3")
    ssh_exec(client, "df -h / | tail -1")
    ssh_exec(client, "nproc")

    # --- Étape 2: Mise à jour système ---
    print("\n--- Étape 2: Mise à jour système ---")
    ssh_exec(client, "apt-get update -y -qq", timeout=180)
    ssh_exec(client, "DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq", timeout=300)

    # --- Étape 3: Installer Docker ---
    print("\n--- Étape 3: Installation Docker ---")
    rc, out, _ = ssh_exec(client, "docker --version 2>/dev/null")
    if rc != 0:
        ssh_exec(client, "apt-get install -y -qq ca-certificates curl gnupg", timeout=120)
        ssh_exec(client, "install -m 0755 -d /etc/apt/keyrings", timeout=10)
        ssh_exec(client, "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes", timeout=60)
        ssh_exec(client, "chmod a+r /etc/apt/keyrings/docker.gpg", timeout=10)
        ssh_exec(client, 'echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null', timeout=30)
        ssh_exec(client, "apt-get update -y -qq", timeout=120)
        ssh_exec(client, "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin", timeout=300)
        ssh_exec(client, "systemctl enable docker && systemctl start docker", timeout=30)
        print("✓ Docker installé!")
    else:
        print(f"✓ Docker déjà installé: {out.strip()}")

    # --- Étape 4: Installer Redis ---
    print("\n--- Étape 4: Installation Redis ---")
    rc, out, _ = ssh_exec(client, "redis-server --version 2>/dev/null")
    if rc != 0:
        ssh_exec(client, "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq redis-server", timeout=120)
        ssh_exec(client, "systemctl enable redis-server && systemctl start redis-server", timeout=30)
        # Configurer Redis pour écouter uniquement en local
        ssh_exec(client, "sed -i 's/^bind .*/bind 127.0.0.1 ::1/' /etc/redis/redis.conf", timeout=10)
        ssh_exec(client, "systemctl restart redis-server", timeout=15)
        print("✓ Redis installé et configuré!")
    else:
        print(f"✓ Redis déjà installé: {out.strip()}")

    # --- Étape 5: Installer Nginx ---
    print("\n--- Étape 5: Installation Nginx ---")
    rc, out, _ = ssh_exec(client, "nginx -v 2>&1")
    if rc != 0:
        ssh_exec(client, "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq nginx certbot python3-certbot-nginx", timeout=120)
        ssh_exec(client, "systemctl enable nginx && systemctl start nginx", timeout=30)
        print("✓ Nginx installé!")
    else:
        print(f"✓ Nginx déjà installé: {out.strip()}")

    # --- Étape 6: Firewall ---
    print("\n--- Étape 6: Firewall ---")
    ssh_exec(client, "apt-get install -y -qq ufw", timeout=60)
    firewall_cmds = [
        "ufw allow 22/tcp",       # SSH
        "ufw allow 80/tcp",       # HTTP (Nginx)
        "ufw allow 443/tcp",      # HTTPS (Nginx)
        "ufw allow 443/udp",      # HTTPS UDP (WebRTC TURN)
        "ufw allow 7880/tcp",     # LiveKit API
        "ufw allow 7881/tcp",     # LiveKit WebRTC TCP
        "ufw allow 50000:60000/udp",  # LiveKit WebRTC UDP
        "ufw --force enable",
    ]
    for cmd in firewall_cmds:
        ssh_exec(client, cmd, timeout=15)
    print("✓ Firewall configuré!")

    # --- Étape 7: Configuration LiveKit ---
    print("\n--- Étape 7: Configuration LiveKit ---")
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
redis:
  address: 127.0.0.1:6379
webhook: {{}}
"""
    ssh_exec(client, f"cat > /opt/livekit/livekit.yaml << 'LKEOF'\n{livekit_yaml}LKEOF", timeout=15)
    print("✓ Config LiveKit écrite!")

    # --- Étape 8: Docker Compose LiveKit ---
    print("\n--- Étape 8: Docker Compose ---")
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
    print("✓ Docker Compose écrit!")

    # --- Étape 9: Pull et démarrer LiveKit ---
    print("\n--- Étape 9: Démarrage LiveKit ---")
    ssh_exec(client, "cd /opt/livekit && docker compose pull", timeout=300)
    ssh_exec(client, "cd /opt/livekit && docker compose up -d", timeout=60)
    print("Attente du démarrage (10s)...")
    time.sleep(10)

    # --- Étape 10: Configurer Nginx reverse proxy ---
    print("\n--- Étape 10: Nginx reverse proxy ---")
    nginx_conf = f"""
server {{
    listen 80;
    server_name {SERVER_IP};

    # LiveKit WebSocket proxy
    location /livekit/ {{
        proxy_pass http://127.0.0.1:7880/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_read_timeout 86400;
    }}

    # Health check
    location /health {{
        return 200 'OK';
        add_header Content-Type text/plain;
    }}
}}
"""
    ssh_exec(client, f"cat > /etc/nginx/sites-available/livekit << 'NGEOF'\n{nginx_conf}NGEOF", timeout=15)
    ssh_exec(client, "ln -sf /etc/nginx/sites-available/livekit /etc/nginx/sites-enabled/livekit", timeout=10)
    ssh_exec(client, "rm -f /etc/nginx/sites-enabled/default", timeout=10)
    ssh_exec(client, "nginx -t", timeout=10)
    ssh_exec(client, "systemctl reload nginx", timeout=15)
    print("✓ Nginx configuré!")

    # --- Étape 11: Vérification finale ---
    print("\n--- Étape 11: Vérification ---")
    ssh_exec(client, "docker ps --format 'table {{.Names}}\\t{{.Status}}\\t{{.Ports}}'")
    ssh_exec(client, "systemctl status redis-server --no-pager -l | head -5")
    ssh_exec(client, "systemctl status nginx --no-pager -l | head -5")

    rc, out, _ = ssh_exec(client, f"curl -s -o /dev/null -w '%{{http_code}}' http://localhost:7880")
    if "200" in out or "404" in out or "405" in out:
        print("\n✓ LiveKit Server est EN LIGNE!")
        success = True
    else:
        print(f"\n⚠ LiveKit répond avec code: {out}")
        ssh_exec(client, "docker logs livekit-server --tail 20")
        success = False

    rc2, out2, _ = ssh_exec(client, "redis-cli ping")
    redis_ok = "PONG" in out2
    print(f"{'✓' if redis_ok else '✗'} Redis: {'OK' if redis_ok else 'ERREUR'}")

    rc3, out3, _ = ssh_exec(client, f"curl -s -o /dev/null -w '%{{http_code}}' http://localhost/health")
    nginx_ok = "200" in out3
    print(f"{'✓' if nginx_ok else '✗'} Nginx: {'OK' if nginx_ok else 'ERREUR'}")

    # --- Sauvegarder credentials ---
    print("\n--- Sauvegarde credentials ---")
    creds = {
        "server_ip": SERVER_IP,
        "server_id": SERVER_ID,
        "server_name": "academia-livekit-new",
        "livekit_api_key": LIVEKIT_API_KEY,
        "livekit_api_secret": LIVEKIT_API_SECRET,
        "livekit_url": f"ws://{SERVER_IP}:7880",
        "livekit_ws_url": f"ws://{SERVER_IP}:7880",
        "livekit_http": f"http://{SERVER_IP}:7880",
        "redis": "127.0.0.1:6379 (local only)",
        "nginx": f"http://{SERVER_IP}",
        "installed_at": time.strftime("%Y-%m-%dT%H:%M:%S"),
    }

    creds_path = Path(__file__).parent / "livekit_credentials.json"
    creds_path.write_text(json.dumps(creds, indent=2))
    print(f"✓ Credentials sauvegardées: {creds_path}")

    client.close()

    # --- Résumé final ---
    print("\n" + "=" * 60)
    if success and redis_ok:
        print(" ✓ INSTALLATION COMPLÈTE RÉUSSIE!")
    else:
        print(" ⚠ INSTALLATION TERMINÉE (vérification nécessaire)")
    print("=" * 60)
    print(f"""
Serveur: {SERVER_IP} (Ubuntu 24.04, 4 vCPU, 10GB RAM)
Services:
  - LiveKit:  http://{SERVER_IP}:7880  (ws://{SERVER_IP}:7880)
  - Redis:    127.0.0.1:6379 (local)
  - Nginx:    http://{SERVER_IP}

LiveKit Credentials:
  LIVEKIT_API_KEY:    {LIVEKIT_API_KEY}
  LIVEKIT_API_SECRET: {LIVEKIT_API_SECRET}
  LIVEKIT_URL:        ws://{SERVER_IP}:7880

Prochaines étapes:
  1. Mettre à jour les secrets Supabase
  2. Mettre à jour supabase_permanent_config.json
  3. Redéployer l'Edge Function livekit-token
""")

if __name__ == "__main__":
    main()

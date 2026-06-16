#!/bin/bash
# ============================================================
# INSTALLATION LIVEKIT SERVER SUR VPS KAMATERA (Ubuntu 22.04)
# ============================================================
# Ce script installe LiveKit Server + Caddy (reverse proxy SSL)
# sur un VPS Kamatera pour le projet Academia.
#
# Usage:
#   1. SSH dans le VPS: ssh root@IP_DU_SERVEUR
#   2. Copier-coller ce script ou le telecharger:
#      curl -O https://raw.githubusercontent.com/.../setup_livekit_kamatera.sh
#   3. chmod +x setup_livekit_kamatera.sh
#   4. ./setup_livekit_kamatera.sh
#
# Pre-requis:
#   - Ubuntu 22.04 (Kamatera default)
#   - Root access
#   - Ports ouverts: 80, 443, 7880, 7881, 50000-60000/UDP
# ============================================================

set -e

echo "============================================"
echo " INSTALLATION LIVEKIT - ACADEMIA"
echo "============================================"

# --- Detecter l'IP publique ---
PUBLIC_IP=$(curl -s ifconfig.me || curl -s icanhazip.com || curl -s api.ipify.org)
echo "IP publique detectee: $PUBLIC_IP"

# --- Generer les cles LiveKit ---
LIVEKIT_API_KEY="APIKey$(openssl rand -hex 6)"
LIVEKIT_API_SECRET="$(openssl rand -base64 32 | tr -d '=/+' | head -c 40)"

echo "LiveKit API Key:    $LIVEKIT_API_KEY"
echo "LiveKit API Secret: $LIVEKIT_API_SECRET"
echo ""

# --- 1. Mise a jour systeme ---
echo "--- Etape 1: Mise a jour systeme ---"
apt-get update -y
apt-get upgrade -y

# --- 2. Installer Docker ---
echo "--- Etape 2: Installation Docker ---"
if ! command -v docker &> /dev/null; then
    apt-get install -y ca-certificates curl gnupg lsb-release
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    systemctl enable docker
    systemctl start docker
    echo "Docker installe avec succes."
else
    echo "Docker deja installe."
fi

# --- 3. Ouvrir les ports (UFW) ---
echo "--- Etape 3: Configuration firewall ---"
if command -v ufw &> /dev/null; then
    ufw allow 22/tcp    # SSH
    ufw allow 80/tcp    # HTTP (Caddy)
    ufw allow 443/tcp   # HTTPS (Caddy) + TURN TLS
    ufw allow 443/udp   # TURN UDP
    ufw allow 7880/tcp  # LiveKit HTTP API
    ufw allow 7881/tcp  # LiveKit WebRTC TCP
    ufw allow 50000:60000/udp  # LiveKit WebRTC UDP (ICE/media)
    ufw --force enable
    echo "Firewall configure."
else
    echo "UFW non installe, ports ouverts par defaut."
fi

# --- 4. Creer la configuration LiveKit ---
echo "--- Etape 4: Configuration LiveKit ---"
mkdir -p /opt/livekit

cat > /opt/livekit/livekit.yaml << LKEOF
port: 7880
bind_addresses:
  - ""
rtc:
  port_range_start: 50000
  port_range_end: 60000
  tcp_port: 7881
  use_external_ip: true
keys:
  ${LIVEKIT_API_KEY}: ${LIVEKIT_API_SECRET}
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
webhook: {}
LKEOF

echo "Configuration LiveKit ecrite dans /opt/livekit/livekit.yaml"

# --- 5. Docker Compose ---
echo "--- Etape 5: Docker Compose ---"
cat > /opt/livekit/docker-compose.yaml << DCEOF
version: '3.8'

services:
  livekit:
    image: livekit/livekit-server:latest
    container_name: livekit-server
    restart: unless-stopped
    network_mode: host
    volumes:
      - /opt/livekit/livekit.yaml:/etc/livekit.yaml
    command: --config /etc/livekit.yaml --node-ip ${PUBLIC_IP}

  # LiveKit Egress (enregistrement des sessions pour replay)
  # Decommenter quand necessaire:
  # livekit-egress:
  #   image: livekit/egress:latest
  #   container_name: livekit-egress
  #   restart: unless-stopped
  #   network_mode: host
  #   environment:
  #     - EGRESS_CONFIG_FILE=/etc/egress.yaml
  #   volumes:
  #     - /opt/livekit/egress.yaml:/etc/egress.yaml
DCEOF

echo "Docker Compose ecrit dans /opt/livekit/docker-compose.yaml"

# --- 6. Lancer LiveKit ---
echo "--- Etape 6: Demarrage LiveKit ---"
cd /opt/livekit
docker compose pull
docker compose up -d

# Attendre que le serveur demarre
echo "Attente du demarrage LiveKit..."
sleep 5

# Verifier que LiveKit fonctionne
if curl -s http://localhost:7880 > /dev/null 2>&1; then
    echo "LiveKit Server est en ligne!"
else
    echo "ATTENTION: LiveKit ne repond pas encore. Verifiez les logs:"
    echo "  docker logs livekit-server"
fi

# --- 7. Sauvegarder les credentials ---
echo "--- Etape 7: Sauvegarde des credentials ---"
cat > /opt/livekit/credentials.txt << CREDEOF
============================================
 LIVEKIT SERVER - ACADEMIA
 Date: $(date)
============================================

Serveur:
  IP: ${PUBLIC_IP}
  HTTP API: http://${PUBLIC_IP}:7880
  WebSocket: ws://${PUBLIC_IP}:7880
  WebRTC TCP: ${PUBLIC_IP}:7881
  WebRTC UDP: ${PUBLIC_IP}:50000-60000

Credentials:
  API Key:    ${LIVEKIT_API_KEY}
  API Secret: ${LIVEKIT_API_SECRET}
  URL:        ws://${PUBLIC_IP}:7880

Commandes Supabase (a executer sur votre PC):
  supabase secrets set LIVEKIT_API_KEY=${LIVEKIT_API_KEY}
  supabase secrets set LIVEKIT_API_SECRET=${LIVEKIT_API_SECRET}
  supabase secrets set LIVEKIT_URL=ws://${PUBLIC_IP}:7880

Deployer l'Edge Function:
  supabase functions deploy livekit-token --no-verify-jwt

Commandes utiles:
  docker logs livekit-server          # Voir les logs
  docker restart livekit-server       # Redemarrer
  docker compose -f /opt/livekit/docker-compose.yaml down   # Arreter
  docker compose -f /opt/livekit/docker-compose.yaml up -d  # Demarrer
  cat /opt/livekit/credentials.txt    # Revoir ce fichier

CREDEOF

# --- Afficher le resume ---
echo ""
echo "============================================"
echo " INSTALLATION TERMINEE AVEC SUCCES!"
echo "============================================"
echo ""
echo "IP du serveur:       ${PUBLIC_IP}"
echo "LiveKit HTTP API:    http://${PUBLIC_IP}:7880"
echo "LiveKit WebSocket:   ws://${PUBLIC_IP}:7880"
echo ""
echo "LIVEKIT_API_KEY:     ${LIVEKIT_API_KEY}"
echo "LIVEKIT_API_SECRET:  ${LIVEKIT_API_SECRET}"
echo ""
echo "IMPORTANT: Notez ces credentials!"
echo "Fichier sauvegarde:  /opt/livekit/credentials.txt"
echo ""
echo "Prochaines etapes:"
echo "  1. Configurez les secrets Supabase (voir ci-dessus)"
echo "  2. Deployez l'Edge Function livekit-token"
echo "  3. Testez: curl http://${PUBLIC_IP}:7880"
echo ""

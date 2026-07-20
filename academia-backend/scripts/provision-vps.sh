#!/usr/bin/env bash
# =============================================================================
# provision-vps.sh — À EXÉCUTER SUR LE VPS (Kamatera), en root.
# Idempotent : installe Node 20, build le backend, crée le service systemd
# `academia-node` et le (re)démarre. N'affecte PAS les workers existants
# (port 4000, distinct des workers vidéo sur 8000/8001).
#
# Prérequis : le dossier academia-backend doit déjà être présent sur le VPS
# (déposé par scripts/deploy-from-local.sh, ou via git).
# Usage :  sudo bash provision-vps.sh /opt/academia-backend
# =============================================================================
set -euo pipefail

APP_DIR="${1:-/opt/academia-backend}"
SERVICE="academia-node"
PORT="${PORT:-4000}"

echo "▶ Provisioning Academia backend dans ${APP_DIR}"

# 1. Node.js 20 si absent -----------------------------------------------------
if ! command -v node >/dev/null 2>&1 || [ "$(node -v | cut -d. -f1 | tr -d v)" -lt 20 ]; then
  echo "▶ Installation de Node.js 20..."
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  apt-get install -y nodejs
fi
echo "▶ Node $(node -v) / npm $(npm -v)"

# 2. Dépendances + build ------------------------------------------------------
cd "$APP_DIR"
if [ ! -f .env ]; then
  echo "⚠ Aucun .env trouvé dans ${APP_DIR}. Copie de .env.example — À COMPLÉTER !"
  cp .env.example .env
fi
echo "▶ npm ci ..."
npm ci
echo "▶ build ..."
npm run build

# 3. Service systemd ----------------------------------------------------------
echo "▶ Écriture du service systemd ${SERVICE}..."
cat > "/etc/systemd/system/${SERVICE}.service" <<UNIT
[Unit]
Description=Academia Node Backend (API REST + webhooks)
After=network.target

[Service]
Type=simple
WorkingDirectory=${APP_DIR}
ExecStart=/usr/bin/node ${APP_DIR}/dist/index.js
EnvironmentFile=${APP_DIR}/.env
Environment=NODE_ENV=production
Environment=PORT=${PORT}
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable "${SERVICE}"
systemctl restart "${SERVICE}"
sleep 2
systemctl --no-pager --full status "${SERVICE}" | head -12

echo ""
echo "✅ Terminé. Test santé :"
echo "   curl http://localhost:${PORT}/api/health"
echo "   journalctl -u ${SERVICE} -f   # suivre les logs"

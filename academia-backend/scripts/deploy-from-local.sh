#!/usr/bin/env bash
# =============================================================================
# deploy-from-local.sh — À EXÉCUTER DEPUIS TA MACHINE (qui a le réseau + SSH).
# Envoie academia-backend sur le VPS puis lance le provisioning à distance.
# UNE SEULE COMMANDE fait tout : upload + install + build + service systemd.
#
# Usage :
#   bash scripts/deploy-from-local.sh
#
# Variables (surchargeables) :
#   VPS_HOST (défaut 185.167.97.144)  VPS_USER (défaut root)
#   REMOTE_DIR (défaut /opt/academia-backend)
#
# Sécurité : n'écris JAMAIS le mot de passe ici. Utilise une clé SSH :
#   ssh-copy-id root@185.167.97.144   (une fois), puis ce script marche sans mot de passe.
# =============================================================================
set -euo pipefail

VPS_HOST="${VPS_HOST:-185.167.97.144}"
VPS_USER="${VPS_USER:-root}"
REMOTE_DIR="${REMOTE_DIR:-/opt/academia-backend}"
LOCAL_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "▶ Déploiement de ${LOCAL_DIR} vers ${VPS_USER}@${VPS_HOST}:${REMOTE_DIR}"

# 1. Upload (exclut node_modules/dist/.env — le build se fait sur le serveur)
rsync -az --delete \
  --exclude node_modules --exclude dist --exclude '.env' --exclude '.git' \
  "${LOCAL_DIR}/" "${VPS_USER}@${VPS_HOST}:${REMOTE_DIR}/"

# 2. Provisioning distant
ssh "${VPS_USER}@${VPS_HOST}" "sudo bash ${REMOTE_DIR}/scripts/provision-vps.sh ${REMOTE_DIR}"

echo "✅ Déploiement terminé. Vérifie : ssh ${VPS_USER}@${VPS_HOST} 'curl -s http://localhost:4000/api/health'"

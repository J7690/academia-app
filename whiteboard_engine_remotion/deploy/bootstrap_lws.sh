#!/usr/bin/env bash
# BOOTSTRAP LWS — installation COMPLETE du pipeline Smart Whiteboard sur serveur vierge.
# Cible : Ubuntu 24.04 (VPS LWS, alias SSH lws-nexiom / root@31.207.38.60).
# À exécuter SUR LE SERVEUR, APRÈS avoir copié les fichiers et créé /opt/whiteboard-worker/.env.
# Idempotent : relançable sans casser. Aucun port entrant requis (worker = sortant vers Supabase).
set -uo pipefail

WORKER_DIR=/opt/whiteboard-worker
ENGINE_DIR=/opt/whiteboard-engine-remotion

echo "==== BOOTSTRAP Smart Whiteboard (LWS) ===="
echo "-- Audit --"; uname -a; df -h / | tail -1; free -h | head -2

# Pré-condition : le .env du worker doit exister (secrets déjà posés)
if [ ! -f "$WORKER_DIR/.env" ]; then
  echo "❌ $WORKER_DIR/.env manquant. Crée-le AVANT (voir instructions). STOP."; exit 1
fi
if ! grep -q SUPABASE_SERVICE_KEY "$WORKER_DIR/.env"; then
  echo "❌ SUPABASE_SERVICE_KEY absent de .env. STOP."; exit 1
fi

echo "== 1. Paquets système =="
apt-get update -y
apt-get install -y --no-install-recommends \
  ffmpeg python3-pip python3-venv curl ca-certificates gnupg \
  fonts-liberation libnss3 libatk-bridge2.0-0 libgtk-3-0 libasound2t64 || \
apt-get install -y --no-install-recommends \
  ffmpeg python3-pip python3-venv curl ca-certificates gnupg \
  fonts-liberation libnss3 libatk-bridge2.0-0 libgtk-3-0 libasound2

echo "== 2. Dépendances Python du worker =="
pip3 install --break-system-packages --no-input httpx python-dotenv Pillow matplotlib

echo "== 3. Node 20 =="
if ! command -v node >/dev/null 2>&1; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  apt-get install -y nodejs
fi
node -v || { echo "❌ Node absent. STOP."; exit 1; }

echo "== 4. Moteur Remotion (deps + Chromium) =="
cd "$ENGINE_DIR" || { echo "❌ $ENGINE_DIR manquant (copie le dossier). STOP."; exit 1; }
npm ci
npx remotion browser ensure

echo "== 5. Docker + Kokoro (voix off) =="
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh
fi
if command -v docker >/dev/null 2>&1; then
  docker ps --format '{{.Names}}' | grep -q '^kokoro-tts$' || \
    docker run -d --restart unless-stopped -p 127.0.0.1:8880:8880 --name kokoro-tts \
      ghcr.io/remsky/kokoro-fastapi-cpu:latest || echo "⚠️ Kokoro non démarré (repli sans voix)."
else
  echo "⚠️ Docker indisponible — voix off désactivée (repli sans voix)."
fi

echo "== 6. Service systemd du worker =="
cat > /etc/systemd/system/whiteboard-worker.service <<EOF
[Unit]
Description=Academia Smart Whiteboard Render Worker
After=network.target docker.service

[Service]
Type=simple
WorkingDirectory=$WORKER_DIR
EnvironmentFile=$WORKER_DIR/.env
ExecStart=/usr/bin/python3 $WORKER_DIR/whiteboard_render_worker.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable whiteboard-worker
systemctl restart whiteboard-worker
sleep 2
systemctl --no-pager status whiteboard-worker | head -12

echo "== 7. Test moteur isolé =="
cd "$ENGINE_DIR"
if node render.mjs --storyboard src/sample_storyboard.json --out /tmp/pro.mp4; then
  ffprobe -v error -select_streams v:0 -show_entries stream=profile,level,width,height -of default=nw=1 /tmp/pro.mp4
  echo "✅ Rendu de test : /tmp/pro.mp4"
else
  echo "❌ Échec du rendu de test (voir logs)."
fi

echo "== 8. Balise de santé -> Supabase =="
set -a; . "$WORKER_DIR/.env"; set +a
python3 "$ENGINE_DIR/healthcheck.py" || echo "⚠️ Balise non publiée (vérifie SUPABASE_URL/KEY)."

echo "==== BOOTSTRAP TERMINÉ ===="

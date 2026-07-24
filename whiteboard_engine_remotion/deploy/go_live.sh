#!/usr/bin/env bash
# GO-LIVE moteur Remotion — À EXÉCUTER SUR LE VPS (root), en une fois.
# Depuis la machine qui a le dépôt + l'accès SSH (Windsurf ou toi) :
#   rsync -a whiteboard_engine_remotion/ root@185.167.97.144:/opt/whiteboard-engine-remotion/
#   scp academia_bobodo_backend/whiteboard_render_worker.py root@185.167.97.144:/opt/whiteboard-worker/
#   ssh root@185.167.97.144 'bash -s' < whiteboard_engine_remotion/deploy/go_live.sh
#
# Tout est opt-in : en cas d'échec d'un composant, le rendu retombe sur vision/legacy.
set -uo pipefail

ENGINE_DIR=/opt/whiteboard-engine-remotion
WORKER_DIR=/opt/whiteboard-worker

echo "===================================================="
echo " GO-LIVE Smart Whiteboard — moteur Remotion"
echo "===================================================="

echo "== 0. Disque (stack lourde : Chromium + Kokoro + node_modules) =="
df -h / | tail -1
FREE_GB=$(df -BG --output=avail / | tail -1 | tr -dc '0-9')
if [ "${FREE_GB:-0}" -lt 8 ]; then
  echo "  ⚠️  Moins de 8 Go libres — surveille la saturation disque."
fi

echo "== 1. Node 20 =="
if ! command -v node >/dev/null 2>&1; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  apt-get install -y nodejs
fi
node -v || { echo "  ❌ Node absent — stop."; exit 1; }

echo "== 2. Dépendances moteur + Chromium =="
cd "$ENGINE_DIR" || { echo "  ❌ $ENGINE_DIR introuvable (copie le dossier d'abord)."; exit 1; }
npm ci
npx remotion browser ensure
apt-get install -y --no-install-recommends libnss3 libatk-bridge2.0-0 libgtk-3-0 libasound2 fonts-liberation || true

echo "== 3. Kokoro TTS (Docker, voix off) =="
if command -v docker >/dev/null 2>&1; then
  if ! docker ps --format '{{.Names}}' | grep -q '^kokoro-tts$'; then
    docker run -d --restart unless-stopped -p 8880:8880 --name kokoro-tts \
      ghcr.io/remsky/kokoro-fastapi-cpu:latest || echo "  ⚠️  Kokoro non démarré (repli sans voix)."
  fi
else
  echo "  ⚠️  Docker absent — voix off indisponible (repli sans voix)."
fi

echo "== 4. Variables worker (.env) =="
touch "$WORKER_DIR/.env"
if ! grep -q REMOTION_ENGINE_DIR "$WORKER_DIR/.env"; then
  cat >> "$WORKER_DIR/.env" <<EOF
REMOTION_ENGINE_DIR=$ENGINE_DIR
KOKORO_URL=http://127.0.0.1:8880/v1/audio/speech
KOKORO_VOICE=ff_siwis
KOKORO_MODEL=kokoro
KOKORO_SPEED=0.95
EOF
  echo "  ✅ Variables ajoutées."
else
  echo "  (déjà présentes)"
fi

echo "== 5. Test moteur isolé (sans app) =="
if node render.mjs --storyboard src/sample_storyboard.json --out /tmp/pro.mp4; then
  ffprobe -v error -select_streams v:0 -show_entries stream=profile,level,width,height \
    -of default=nw=1 /tmp/pro.mp4
  echo "  ✅ Rendu de test produit : /tmp/pro.mp4"
else
  echo "  ❌ Échec du rendu de test — voir les logs ci-dessus."
fi

echo "== 6. Redémarrage du worker whiteboard =="
systemctl restart whiteboard-worker 2>/dev/null && echo "  ✅ worker redémarré" \
  || echo "  ⚠️  service whiteboard-worker introuvable — vérifie le nom du service."

echo "== 7. Balise de santé -> Supabase (permet la vérif à distance par Claude) =="
set -a; . "$WORKER_DIR/.env" 2>/dev/null; set +a
python3 "$ENGINE_DIR/healthcheck.py" || echo "  ⚠️  Balise non publiée (vérifie SUPABASE_URL/SUPABASE_SERVICE_KEY dans le .env)."

echo "===================================================="
echo " TERMINÉ. Dis à Claude de relire app.whiteboard_engine_health."
echo "===================================================="

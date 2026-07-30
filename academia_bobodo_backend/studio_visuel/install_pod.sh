#!/bin/bash
# Installation complete d'un pod GPU RunPod — Studio visuel Academia.
#
# Cible : image `runpod/pytorch:*-cu1281-torch280-ubuntu2404`
#         (Ubuntu 24.04, Python 3.12, torch 2.8 + CUDA 12.8, ffmpeg 6.1.1).
#
# Usage :
#   scp -P <port> install_pod.sh agent_pod.sh worker_pod.py capsule_orientation.py \
#       root@<ip>:/workspace/
#   ssh root@<ip> -p <port> "POD_ID=... POD_JETON=... /workspace/install_pod.sh"
#
# Variables attendues pour le demarrage automatique du worker :
#   POD_ID, POD_JETON, SUPABASE_URL, SUPABASE_ANON_KEY
#
# TOUT VA DANS /workspace, QUI EST EFFACE PAR `podTerminate`. Ce script est donc
# la base de l'image Docker de la phase 4 du cahier des charges. Tant qu'elle
# n'existe pas, il faut le rejouer a chaque location -- compter ~15 minutes.
set -u
exec > >(tee -a /workspace/install.log) 2>&1

echo "=== DEBUT $(date -Is) ==="

# ── Dependances systeme ───────────────────────────────────────────────────
apt-get update -qq

# Blender est livre en binaire : il exige ces bibliotheques X/GL MEME en mode
# headless (`-b`), sans quoi il refuse de demarrer. Piege reel.
apt-get install -y -qq \
  libxi6 libxxf86vm1 libxfixes3 libxrender1 libgl1 libsm6 libxkbcommon0 \
  git wget curl jq bc procps \
  fonts-dejavu-core fonts-liberation2 fontconfig

# Les polices comptent : sans elles, tout objet texte 3D et toute incrustation
# ffmpeg tombe sur une police de remplacement, et le rendu « premium » s'effondre.
fc-cache -f >/dev/null 2>&1

# ── Blender ───────────────────────────────────────────────────────────────
# La version d'Ubuntu est trop ancienne. On prend la LTS officielle, et on la
# DECOUVRE au lieu de la coder en dur, pour que le script vieillisse bien.
if [ ! -x /workspace/blender/blender ]; then
  cd /workspace
  VER=$(wget -qO- https://download.blender.org/release/ | grep -oE 'Blender4\.[0-9]+' | sort -uV | tail -1)
  FICHIER=$(wget -qO- "https://download.blender.org/release/$VER/" | grep -oE 'blender-4\.[0-9.]+-linux-x64\.tar\.xz' | sort -uV | tail -1)
  echo "Blender retenu : $VER / $FICHIER"
  wget -q "https://download.blender.org/release/$VER/$FICHIER"
  tar -xf "$FICHIER" && rm -f "$FICHIER"
  mv blender-4* blender
fi
/workspace/blender/blender --version | head -1

# ── ComfyUI ───────────────────────────────────────────────────────────────
if [ ! -f /workspace/ComfyUI/main.py ]; then
  cd /workspace
  git clone --depth 1 https://github.com/comfyanonymous/ComfyUI.git
fi
cd /workspace/ComfyUI
# PEP 668 : Ubuntu 24.04 refuse pip sur le Python systeme
# (« externally-managed-environment »). Sans ce drapeau, le clone reussit,
# l'installation des dependances echoue EN SILENCE, et ComfyUI semble installe
# alors que rien ne fonctionne. Un venv ferait perdre le torch de l'image,
# deja compile pour CUDA 12.8 : dans un conteneur jetable, on force.
pip install --break-system-packages -q -r requirements.txt
pip install --break-system-packages -q requests

python3 -c "import torch, torchsde, einops, safetensors; print('ComfyUI OK | cuda', torch.cuda.is_available())"

# ── Verification que Cycles voit bien le GPU ──────────────────────────────
# Sans cette verification, un pod peut rendre en CPU sans qu'on s'en apercoive,
# a 50 fois le temps -- et donc 50 fois le prix.
/workspace/blender/blender -b --python-expr "
import bpy, sys
p = bpy.context.preferences.addons['cycles'].preferences
p.compute_device_type = 'OPTIX'; p.get_devices()
noms = [d.name for d in p.devices if d.type == 'OPTIX']
print('OPTIX_DISPONIBLE', noms)
sys.exit(0 if noms else 1)
" 2>/dev/null | grep OPTIX_DISPONIBLE || { echo 'ECHEC: Cycles ne voit pas le GPU'; exit 1; }

# ── Agent de presence, sous surveillance ──────────────────────────────────
# L'agent a deja plante une fois, et le veilleur a supprime la machine en plein
# travail. On ne le lance donc plus « nu » : une boucle le relance s'il tombe.
if [ -n "${POD_ID:-}" ] && [ -n "${POD_JETON:-}" ]; then
  cat > /workspace/agent.env <<ENV
export POD_ID=$POD_ID
export POD_JETON=$POD_JETON
export SUPABASE_URL=${SUPABASE_URL:-https://thevdfcwlcqzdoybfvgs.supabase.co}
export SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY:-}
ENV
  chmod 600 /workspace/agent.env

  cat > /workspace/superviseur.sh <<'SUP'
#!/bin/bash
# Relance l'agent et le worker s'ils tombent. Sans ca, la mort silencieuse de
# l'agent fait supprimer une machine qui travaillait -- c'est arrive.
source /workspace/agent.env
while true; do
  pgrep -f 'agent[_]pod\.sh' >/dev/null || \
    (setsid bash /workspace/agent_pod.sh </dev/null >>/workspace/agent.log 2>&1 &)
  pgrep -f 'worker[_]pod\.py' >/dev/null || \
    (setsid python3 /workspace/worker_pod.py </dev/null >>/workspace/worker.log 2>&1 &)
  sleep 30
done
SUP
  chmod +x /workspace/superviseur.sh
  chmod +x /workspace/agent_pod.sh 2>/dev/null || true

  # `pkill -f superviseur.sh` tuerait la session SSH qui lance la commande,
  # le motif correspondant a sa propre ligne. D'ou les crochets.
  pkill -f 'superviseur[.]sh' 2>/dev/null || true
  setsid bash /workspace/superviseur.sh </dev/null >>/workspace/superviseur.log 2>&1 &
  echo "superviseur demarre (agent + worker)"
else
  echo "POD_ID/POD_JETON absents : agent et worker non demarres"
fi

echo "=== FIN $(date -Is) ==="

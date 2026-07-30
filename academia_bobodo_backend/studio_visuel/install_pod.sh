#!/bin/bash
# Installation d'un pod GPU RunPod pour le Studio visuel Academia.
#
# Cible : image `runpod/pytorch:*-cu1281-torch280-ubuntu2404` (Ubuntu 24.04,
# Python 3.12, torch 2.8 + CUDA 12.8, ffmpeg 6.1.1 deja presents).
#
# Usage :
#   scp academia_bobodo_backend/studio_visuel/install_pod.sh root@<ip>:/workspace/
#   ssh root@<ip> -p <port> "nohup /workspace/install_pod.sh &"
#   ssh root@<ip> -p <port> "tail -f /workspace/install.log"
#
# Tout s'installe dans /workspace : c'est le disque de volume. Attention, il
# est supprime par `podTerminate`. Ce script est donc la base de l'image Docker
# de la phase 4 du cahier des charges -- c'est elle qui evitera de rejouer
# cette installation a chaque session.
set -x
exec > /workspace/install.log 2>&1

echo "=== DEBUT $(date) ==="

apt-get update -qq
# Blender est fourni en binaire : il lui faut ces bibliotheques X/GL meme en
# mode headless (`-b`), sans quoi il refuse de demarrer.
apt-get install -y -qq libxi6 libxxf86vm1 libxfixes3 libxrender1 libgl1 libsm6 git wget

# ── Blender ───────────────────────────────────────────────────────────────
# La version d'Ubuntu est trop ancienne : on prend la LTS officielle, et on la
# decouvre au lieu de la coder en dur, pour que le script vieillisse bien.
cd /workspace
VER=$(wget -qO- https://download.blender.org/release/ | grep -oE 'Blender4\.[0-9]+' | sort -uV | tail -1)
FICHIER=$(wget -qO- https://download.blender.org/release/$VER/ | grep -oE 'blender-4\.[0-9.]+-linux-x64\.tar\.xz' | sort -uV | tail -1)
echo "Blender retenu : $VER / $FICHIER"
wget -q https://download.blender.org/release/$VER/$FICHIER
tar -xf "$FICHIER"
rm -f "$FICHIER"
mv blender-4* blender
/workspace/blender/blender --version

# ── ComfyUI ───────────────────────────────────────────────────────────────
cd /workspace
git clone --depth 1 https://github.com/comfyanonymous/ComfyUI.git
cd ComfyUI

# PEP 668 : Ubuntu 24.04 refuse pip sur le Python systeme
# (« error: externally-managed-environment »). Piege reel -- sans ce drapeau,
# le clone reussit, l'installation echoue en silence, et ComfyUI semble
# installe alors qu'aucune dependance ne l'est.
# Un venv ferait perdre le torch de l'image, deja compile pour CUDA 12.8 :
# dans un conteneur jetable, on force.
pip install --break-system-packages -q -r requirements.txt

echo "=== FIN $(date) ==="

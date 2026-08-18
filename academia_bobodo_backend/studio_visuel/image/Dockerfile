# Image autonome du Studio visuel — Academia
#
# POURQUOI ELLE EXISTE, ET POURQUOI ELLE PASSE AVANT L'AUTOMATISATION.
#
# RunPod efface le disque du conteneur a chaque arret ; seul `/workspace`
# survit. Tant que Node, Chromium et Blender sont installes A CHAUD par SSH
# apres le demarrage, un Pod arrete redemarre NU : il ne peut plus rien rendre,
# et l'arret automatique deviendrait une panne au lieu d'une economie.
#
# Mesure du 11/08 qui l'impose : sur un Pod amorce depuis l'image RunPod, `node`
# etait ABSENT ; il a fallu 4 minutes d'apt/npm/playwright pour le rendre
# capable de rendre une image. Multiplie par chaque reveil, c'est intenable.
#
# LE PIEGE QUI ANNULE TOUT LE RESTE, ET IL EST EN UNE LIGNE.
# `NVIDIA_DRIVER_CAPABILITIES` vaut `compute,utility` par defaut. Sans
# `graphics`, la carte calcule mais ne rasterise pas : EGL ne voit aucun
# peripherique, et Chromium retombe SILENCIEUSEMENT sur SwiftShader. C'est
# exactement le defaut mesure le 11/08 -- 1245 images/seconde annoncees sur des
# captures de 10 Ko, c'est-a-dire du vide compte tres vite.

# `base` ET NON `runtime` : mesure du 12/08, l'image pesait 9,68 Go avec
# `runtime`, qui embarque cuDNN et cuBLAS. Or ce studio RASTERISE -- EEVEE et
# WebGL ne veulent qu'OpenGL et EGL, pas une pile d'algebre lineaire pour
# reseaux de neurones. Chaque gigaoctet se paie au tirage, a CHAQUE creation de
# machine, et c'est precisement ce que l'image devait faire economiser.
FROM nvidia/cuda:12.8.0-base-ubuntu24.04

# `graphics` est la capacite qui donne EGL et OpenGL. Sans elle, tout le reste
# de cette image est inutile.
ENV NVIDIA_DRIVER_CAPABILITIES=compute,graphics,utility \
    NVIDIA_VISIBLE_DEVICES=all \
    DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    HF_HOME=/workspace/hf

# ── Systeme ───────────────────────────────────────────────────────────────
# libegl1/libgles2/libglvnd0 : la couche de repartition EGL. Le pilote NVIDIA
# est monte par RunPod au demarrage, mais la repartition doit etre dans l'image.
# Les libx* sont exigees par le binaire Blender MEME en mode headless.
RUN apt-get update -qq && apt-get install -y --no-install-recommends \
      ca-certificates curl wget jq bc procps xz-utils \
      python3 python3-requests python3-pip \
      ffmpeg \
      libegl1 libgles2 libglvnd0 libgbm1 libopengl0 libglx0 \
      libxi6 libxxf86vm1 libxfixes3 libxrender1 libgl1 libsm6 libxkbcommon0 \
      libnss3 libatk1.0-0t64 libatk-bridge2.0-0t64 libcups2t64 libdrm2 \
      libxcomposite1 libxdamage1 libxrandr2 libasound2t64 libpango-1.0-0 \
      libcairo2 libatspi2.0-0t64 \
      fonts-dejavu-core fonts-liberation2 fontconfig \
    && fc-cache -f >/dev/null \
    && rm -rf /var/lib/apt/lists/*

# ── Declaration du pilote EGL ─────────────────────────────────────────────
# RunPod monte la bibliotheque mais pas toujours son fichier de declaration.
# Sans lui, `eglQueryDevices` ne voit aucune carte -- panne silencieuse.
RUN mkdir -p /usr/share/glvnd/egl_vendor.d && \
    printf '%s\n' '{ "file_format_version" : "1.0.0", "ICD" : { "library_path" : "libEGL_nvidia.so.0" } }' \
      > /usr/share/glvnd/egl_vendor.d/10_nvidia.json

# ── Node ──────────────────────────────────────────────────────────────────
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - >/dev/null 2>&1 && \
    apt-get install -y --no-install-recommends nodejs && \
    rm -rf /var/lib/apt/lists/*

# ── Blender ───────────────────────────────────────────────────────────────
# Version FIGEE, pas « la derniere ». Une image doit rendre la meme chose dans
# six mois : `amorcer.sh` decouvrait la derniere LTS a chaud, ce qui rendait le
# rendu dependant du jour de location.
ARG BLENDER_VERSION=4.5.12
RUN cd /opt && \
    wget -q "https://download.blender.org/release/Blender${BLENDER_VERSION%.*}/blender-${BLENDER_VERSION}-linux-x64.tar.xz" && \
    tar -xf "blender-${BLENDER_VERSION}-linux-x64.tar.xz" && \
    rm -f "blender-${BLENDER_VERSION}-linux-x64.tar.xz" && \
    mv "blender-${BLENDER_VERSION}-linux-x64" blender && \
    ln -s /opt/blender/blender /usr/local/bin/blender

# ── Chromium et Three.js, pour le moteur temps reel ───────────────────────
# PLAYWRIGHT_BROWSERS_PATH fixe : sans lui, Chromium atterrit dans le HOME et
# disparait avec le disque conteneur.
ENV PLAYWRIGHT_BROWSERS_PATH=/opt/playwright
WORKDIR /opt/rendu
COPY image/package.json ./package.json
RUN npm install --omit=dev --silent && npx playwright install chromium

# ── Le moteur ─────────────────────────────────────────────────────────────
COPY style_reference.py academia_scene.py generateur_scenes.py generateur_ia.py \
     montage.py sound_design.py executer_capsule.py worker_pod.py narration.py \
     academia3d.py academia3d_style.py composer_scene.py \
     /opt/moteur/
COPY contours/ /opt/moteur/contours/
# Le moteur navigateur : six verbes en Three.js + le lanceur image par image.
# Il remplace Blender depuis le 18/08 ; Blender reste dans l'image, joignable
# par MOTEUR_RENDU=blender, tant que le neuf n'a pas fait ses preuves.
COPY web/ /opt/moteur/web/
# La version EMBARQUEE, dans un fichier plutot que dans une variable. `entree.sh`
# la remplace par celle de l'archive s'il en tire une depuis Storage : ce qui est
# annonce est alors ce qui est REELLEMENT installe, et non l'etiquette de
# l'image. Sans ce fichier, un moteur non tire passerait pour un moteur a jour.
COPY VERSION /opt/moteur/VERSION
COPY image/sonde_pret.js image/entree.sh /opt/rendu/
RUN chmod +x /opt/rendu/entree.sh

# La version est LUE par la sonde de readiness et comparee a ce que Supabase
# attend : un Pod qui rend avec une version differente doit etre refuse, pas
# decouvert apres coup sur une capsule livree.
ARG VERSION_MOTEUR=dev
ENV VERSION_MOTEUR=${VERSION_MOTEUR}

WORKDIR /workspace
ENTRYPOINT ["/opt/rendu/entree.sh"]

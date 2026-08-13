#!/usr/bin/env python3
"""Amorceur du Studio — LWS installe la machine que Supabase a louee.

LE CHAINON QUI MANQUAIT. L'orchestrateur sait creer un pod, mais un pod neuf ne
contient ni Blender ni nos scripts, et une Edge Function ne peut pas s'y
connecter en SSH. Sans cet amorceur, l'automatisation creerait des machines
incapables de travailler, qui factureraient jusqu'a leur plafond de quatre
heures.

LE PARTAGE DES SECRETS EST VOLONTAIRE :
    la cle RunPod reste chez Supabase — elle cree et detruit les machines
    la cle SSH reste sur LWS       — elle les installe
    la machine louee n'a que son jeton — elle travaille, et rien d'autre
Aucune des trois n'a besoin de ce que detiennent les autres. Un pod compromis
ne donne acces ni au compte RunPod ni a la base.

Boucle : toutes les 30 s, demander s'il y a une machine a amorcer, l'installer,
la marquer. Idempotent : si l'installation echoue a mi-chemin, le passage
suivant la reprend.

Variables attendues : SUPABASE_URL, SUPABASE_SERVICE_KEY
Usage : systemd, ou `python3 studio_amorceur.py`
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request

SUPABASE_URL = os.environ.get("SUPABASE_URL", "").rstrip("/")
SERVICE_KEY = os.environ.get("SUPABASE_SERVICE_KEY", "")
CLE_SSH = os.environ.get("STUDIO_CLE_SSH", os.path.expanduser("~/.ssh/id_ed25519_runpod"))
SOURCES = os.environ.get("STUDIO_SOURCES", "/opt/studio_visuel")
INTERVALLE = int(os.environ.get("STUDIO_INTERVALLE", "30"))

# Fichiers a deposer sur la machine. Ce sont eux qui la rendent capable de
# travailler ; sans eux elle n'est qu'un GPU qui chauffe.
FICHIERS = ("style_reference.py", "academia_scene.py", "generateur_scenes.py",
            "generateur_ia.py", "montage.py", "sound_design.py",
            "executer_capsule.py", "worker_pod.py", "agent_pod.sh")


def journal(message: str) -> None:
    print(f"{time.strftime('%Y-%m-%dT%H:%M:%S')} {message}", flush=True)


def rpc(nom: str, corps: dict | None = None):
    try:
        requete = urllib.request.Request(
            f"{SUPABASE_URL}/rest/v1/rpc/{nom}",
            data=json.dumps(corps or {}).encode("utf-8"), method="POST",
            headers={
                "apikey": SERVICE_KEY,
                "Authorization": f"Bearer {SERVICE_KEY}",
                "Content-Type": "application/json",
            })
        with urllib.request.urlopen(requete, timeout=30) as reponse:
            return json.loads(reponse.read() or b"null")
    except urllib.error.HTTPError as e:
        journal(f"rpc {nom} -> HTTP {e.code} {e.read()[:160]!r}")
    except Exception as e:  # noqa: BLE001
        journal(f"rpc {nom} -> {e}")
    return None


def _ssh(hote: str, port: int, commande: str, delai: int = 1800):
    return subprocess.run(
        ["ssh", "-o", "StrictHostKeyChecking=accept-new",
         "-o", "ConnectTimeout=20", "-o", "BatchMode=yes",
         "-i", CLE_SSH, "-p", str(port), f"root@{hote}", commande],
        capture_output=True, text=True, timeout=delai)


def _scp(hote: str, port: int, fichiers: list[str], delai: int = 600) -> bool:
    existants = [os.path.join(SOURCES, f) for f in fichiers
                 if os.path.isfile(os.path.join(SOURCES, f))]
    if not existants:
        journal("aucun fichier source a deposer")
        return False
    r = subprocess.run(
        ["scp", "-o", "StrictHostKeyChecking=accept-new", "-o", "BatchMode=yes",
         "-i", CLE_SSH, "-P", str(port), *existants, f"root@{hote}:/workspace/"],
        capture_output=True, text=True, timeout=delai)
    if r.returncode != 0:
        journal(f"depot des sources refuse : {r.stderr[-200:]}")
    return r.returncode == 0


def amorcer(pod: dict) -> bool:
    pod_id, jeton = pod["pod_id"], pod["jeton"]
    hote, port = pod["hote"], int(pod["port"])
    journal(f"amorcage de {pod_id} sur {hote}:{port}")

    # 1. Attendre que sshd reponde. Une machine « RUNNING » chez RunPod n'a pas
    #    forcement fini de demarrer son service SSH.
    for essai in range(1, 13):
        if _ssh(hote, port, "echo pret", 40).stdout.strip() == "pret":
            break
        time.sleep(10)
    else:
        journal(f"{pod_id} injoignable apres deux minutes — on reessaiera")
        return False

    # 2. Deposer les sources AVANT l'installation : si la machine meurt en
    #    cours de route, le passage suivant repart d'un etat coherent.
    if not _scp(hote, port, list(FICHIERS)):
        return False

    # Les contours SVG : sans eux, `silhouette` retombe sur son texte de
    # secours et la capsule perd le sujet qu'elle devait montrer.
    contours = os.path.join(SOURCES, "contours")
    if os.path.isdir(contours):
        _ssh(hote, port, "mkdir -p /workspace/contours", 60)
        subprocess.run(
            ["scp", "-o", "StrictHostKeyChecking=accept-new", "-o", "BatchMode=yes",
             "-i", CLE_SSH, "-P", str(port),
             *[os.path.join(contours, f) for f in os.listdir(contours) if f.endswith(".svg")],
             f"root@{hote}:/workspace/contours/"],
            capture_output=True, text=True, timeout=300)

    # NORMALISATION DES FINS DE LIGNE, A LA DESTINATION.
    #
    # Ce defaut a coute deux machines. Un script copie depuis un poste Windows
    # arrive avec des CRLF ; bash repond « syntax error near unexpected token
    # inattendu » suivi d'un retour chariot, et l'agent meurt a sa premiere
    # boucle -- AVANT son premier
    # battement de coeur. Le veilleur constate alors le silence et supprime une
    # machine parfaitement saine.
    #
    # J'avais d'abord corrige a la source, par un `.gitattributes`. Insuffisant :
    # il ne regit que ce que git STOCKE, pas l'arbre de travail ni ce qu'on
    # copie a la main. On ne fait donc plus confiance a la provenance -- on
    # normalise ici, ou l'on sait ce qui compte.
    _ssh(hote, port,
         "sed -i 's/\r$//' /workspace/*.sh /workspace/*.py 2>/dev/null; "
         "bash -n /workspace/agent_pod.sh", 120)

    # 3. Environnement de l'agent. Le pod ne recoit QUE son jeton : ni la cle
    #    de service, ni la cle RunPod.
    env = (f"export POD_ID={pod_id}\n"
           f"export POD_JETON={jeton}\n"
           f"export SUPABASE_URL={SUPABASE_URL}\n"
           f"export SUPABASE_ANON_KEY={os.environ.get('SUPABASE_ANON_KEY', '')}\n")
    r = _ssh(hote, port, f"cat > /workspace/agent.env <<'ENV'\n{env}ENV\nchmod 600 /workspace/agent.env", 60)
    if r.returncode != 0:
        journal(f"ecriture de l'environnement refusee : {r.stderr[-200:]}")
        return False

    # 4. Installation. `-x` sur le fichier temoin : idempotent, une reprise ne
    #    reinstalle pas Blender pour rien.
    script = r"""
set -u
exec > /workspace/amorcage.log 2>&1
if [ ! -x /workspace/blender/blender ]; then
  apt-get update -qq
  apt-get install -y -qq libxi6 libxxf86vm1 libxfixes3 libxrender1 libgl1 libsm6 \
    libxkbcommon0 wget curl fonts-dejavu-core fontconfig \
    libegl1 libgles2 libglvnd0 libgbm1 libopengl0 libglx0 python3-requests
  pip install --break-system-packages -q diffusers transformers accelerate protobuf sentencepiece ftfy
  fc-cache -f >/dev/null 2>&1
  cd /workspace
  VER=$(wget -qO- https://download.blender.org/release/ | grep -oE 'Blender4\.[0-9]+' | sort -uV | tail -1)
  FICHIER=$(wget -qO- https://download.blender.org/release/$VER/ | grep -oE 'blender-4\.[0-9.]+-linux-x64\.tar\.xz' | sort -uV | tail -1)
  wget -q https://download.blender.org/release/$VER/$FICHIER
  tar -xf "$FICHIER" && rm -f "$FICHIER" && mv blender-4* blender
fi
/workspace/blender/blender --version | head -1
chmod +x /workspace/agent_pod.sh 2>/dev/null || true

# Le jeton HuggingFace : la machine va le CHERCHER elle-meme, en prouvant son
# identite avec son propre jeton. Il ne transite jamais par LWS, et Supabase
# reste la source unique. Sans lui, seuls les depots ouverts sont accessibles
# -- ce qui suffit pour les modeles que nous utilisons aujourd'hui.
source /workspace/agent.env
REP=$(curl -s --max-time 30 -X POST "$SUPABASE_URL/functions/v1/studio-jeton-huggingface"   -H "apikey: $SUPABASE_ANON_KEY" -H "Authorization: Bearer $SUPABASE_ANON_KEY"   -H 'Content-Type: application/json'   -d "{\"pod_id\":\"$POD_ID\",\"jeton\":\"$POD_JETON\"}")
HF=$(echo "$REP" | sed -n 's/.*"jeton":"\([^"]*\)".*/\1/p')
if [ -n "$HF" ]; then
  echo "export HF_TOKEN=$HF" >> /workspace/agent.env
  echo "export HUGGING_FACE_HUB_TOKEN=$HF" >> /workspace/agent.env
  echo 'jeton HuggingFace obtenu'
else
  echo 'aucun jeton HuggingFace — depots ouverts seulement'
fi
# LE CACHE DES MODELES VA SUR LE DISQUE CONTENEUR, PAS SUR LE VOLUME.
#
# C'est l'inverse de ce qui etait fait, et le commentaire precedent -- « 40 Go
# contre 60 » -- ne correspondait plus a la machine reellement demandee.
# Mesure du 06/08 sur deux pods successifs :
#
#     /            (conteneur, containerDiskInGb: 30)   30 Go, 377 Mo utilises
#     /workspace   (volume,    volumeInGb: 20)          20 Go, 14 Go de cache HF
#
# Le volume etait donc plein aux trois quarts par le cache lui-meme, et le
# telechargement du modele echouait en « Disk quota exceeded » -- deux fois,
# y compris apres avoir exclu la documentation du depot. Pendant ce temps le
# disque conteneur etait vide a 98 %.
#
# C'est CE defaut qui empechait toute scene `genere` : le modele ne pouvait
# pas finir de se telecharger, `produire_image` levait, et la scene basculait
# sur un archetype procedural. Rien a voir avec le VAE.
#
# Contrepartie assumee : le disque conteneur est ephemere, le modele est donc
# retelecharge a chaque nouvelle machine (~10 min). C'est le prix a payer tant
# que `volumeInGb` vaut 20 dans `studio-orchestrateur` ; l'augmenter est un
# deploiement d'Edge Function, et cela se decide avec Jocelyn.
echo 'export HF_HOME=/root/hf' >> /workspace/agent.env
mkdir -p /root/hf

cat > /workspace/superviseur.sh <<'SUP'
#!/bin/bash
source /workspace/agent.env
while true; do
  pgrep -f 'agent[_]pod\.sh'  >/dev/null || (setsid bash /workspace/agent_pod.sh </dev/null >>/workspace/agent.log 2>&1 &)
  pgrep -f 'worker[_]pod\.py' >/dev/null || (setsid python3 /workspace/worker_pod.py </dev/null >>/workspace/worker.log 2>&1 &)
  sleep 30
done
SUP
chmod +x /workspace/superviseur.sh
pkill -f 'superviseur[.]sh' 2>/dev/null || true
setsid bash /workspace/superviseur.sh </dev/null >>/workspace/superviseur.log 2>&1 &
sleep 2
# Le temoin n'est pose QUE si le superviseur tourne reellement. Un fichier
# ecrit avant verification ne prouverait rien.
pgrep -f 'superviseur[.]sh' >/dev/null && touch /workspace/amorce.ok
echo AMORCAGE_OK
"""
    # LE SUCCES SE CONSTATE PAR UN FICHIER TEMOIN, PAS PAR LA SORTIE STANDARD.
    #
    # Premiere version : on cherchait « AMORCAGE_OK » dans la sortie de la
    # commande SSH. Or le script redirige tout vers son journal, et il finit par
    # un `setsid ... &` qui garde le canal ouvert -- la sortie revenait vide et
    # l'amorcage etait declare incomplet ALORS QU'IL AVAIT REUSSI. L'amorceur
    # reessayait alors toutes les trente secondes sur une machine deja au
    # travail.
    #
    # Un fichier ne ment pas et survit a la fermeture du canal.
    _ssh(hote, port,
         f"cat > /workspace/amorcer.sh <<'SCRIPT'\n{script}\nSCRIPT\nbash /workspace/amorcer.sh", 2400)
    temoin = _ssh(hote, port, "test -f /workspace/amorce.ok && echo TEMOIN_PRESENT", 60)
    if "TEMOIN_PRESENT" not in (temoin.stdout or ""):
        journal(f"amorcage incomplet : {(temoin.stdout or temoin.stderr or '')[-200:] or 'temoin absent'}")
        return False

    rpc("gpu_pod_marquer_amorce", {"p_pod_id": pod_id})
    journal(f"{pod_id} amorce — worker en marche")
    return True


def main() -> int:
    if not (SUPABASE_URL and SERVICE_KEY):
        journal("SUPABASE_URL ou SUPABASE_SERVICE_KEY absent")
        return 1
    if not os.path.isfile(CLE_SSH):
        journal(f"cle SSH introuvable : {CLE_SSH}")
        return 2

    journal(f"amorceur demarre (sources: {SOURCES}, intervalle: {INTERVALLE}s)")
    while True:
        pod = rpc("gpu_pod_a_amorcer")
        if isinstance(pod, dict) and pod.get("pod_id"):
            try:
                amorcer(pod)
            except subprocess.TimeoutExpired:
                journal(f"{pod['pod_id']} : delai depasse, reprise au prochain passage")
            except Exception as e:  # noqa: BLE001
                journal(f"{pod.get('pod_id')} : {e}")
        time.sleep(INTERVALLE)


if __name__ == "__main__":
    sys.exit(main())

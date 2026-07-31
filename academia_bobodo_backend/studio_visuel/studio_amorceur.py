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
            "montage.py", "sound_design.py", "executer_capsule.py",
            "worker_pod.py", "agent_pod.sh")


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
  fc-cache -f >/dev/null 2>&1
  cd /workspace
  VER=$(wget -qO- https://download.blender.org/release/ | grep -oE 'Blender4\.[0-9]+' | sort -uV | tail -1)
  FICHIER=$(wget -qO- https://download.blender.org/release/$VER/ | grep -oE 'blender-4\.[0-9.]+-linux-x64\.tar\.xz' | sort -uV | tail -1)
  wget -q https://download.blender.org/release/$VER/$FICHIER
  tar -xf "$FICHIER" && rm -f "$FICHIER" && mv blender-4* blender
fi
/workspace/blender/blender --version | head -1
chmod +x /workspace/agent_pod.sh 2>/dev/null || true

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
echo AMORCAGE_OK
"""
    r = _ssh(hote, port, f"cat > /workspace/amorcer.sh <<'SCRIPT'\n{script}\nSCRIPT\nbash /workspace/amorcer.sh; tail -2 /workspace/amorcage.log", 2400)
    if "AMORCAGE_OK" not in (r.stdout or ""):
        journal(f"amorcage incomplet : {(r.stdout or r.stderr)[-300:]}")
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

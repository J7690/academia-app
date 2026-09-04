#!/usr/bin/env python3
"""Prepare les capsules 3D commandees par les etudiants. Tourne sur LWS.

CE QU'IL FAIT, ET POURQUOI ICI PLUTOT QUE SUR LE POD.
Quand un etudiant choisit « Animation 3D », l'application depose un travail
portant son STORYBOARD -- le meme que celui du tableau manuscrit. Il reste deux
choses a faire avant qu'une machine puisse rendre :

  1. traduire le storyboard en capsule (`depuis_storyboard`) ;
  2. synthetiser la voix et MESURER la duree de chaque scene (`narration`).

Aucune des deux ne demande de carte graphique. Les faire sur un pod couterait
0,44 $/h a ne rien calculer -- c'est exactement l'erreur qui a fait passer une
machine de 66 minutes a 12 minutes de travail utile le 30/07.

LE POINT QUI COMMANDE TOUTE LA CONCEPTION.
`statut = 'queued'` ne signifie pas « en attente » mais « pret pour une
machine » : `studio_etat_file` le compte et l'orchestrateur LOUE des qu'il
depasse zero. Un travail non prepare ne doit donc jamais y figurer. D'ou la
sequence :

    a_preparer  --(ce service)-->  preparation  -->  queued  -->  rendering

Le service SORT vers Supabase, comme tous les workers du projet : aucun port
entrant, rien a ouvrir sur le pare-feu.

Variables attendues : SUPABASE_URL, SUPABASE_SERVICE_KEY.
Facultatives : STUDIO_CLE_WORKER, STUDIO_INTERVALLE, STUDIO_AUTORISER_IMAGES.
"""

from __future__ import annotations

import os
import shutil
import socket
import sys
import tempfile
import time
import traceback

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import academia_scene  # noqa: E402
import depuis_storyboard  # noqa: E402
import narration  # noqa: E402

SUPABASE_URL = os.environ.get("SUPABASE_URL", "").rstrip("/")
SERVICE_KEY = os.environ.get("SUPABASE_SERVICE_KEY", "")
CLE_WORKER = os.environ.get("STUDIO_CLE_WORKER", "lws-preparateur")
INTERVALLE = int(os.environ.get("STUDIO_INTERVALLE", "15"))
TRAVAIL = os.environ.get("STUDIO_TRAVAIL", "/tmp/studio_preparation")

# L'archetype `genere` (images produites par diffusion) reste DESACTIVE par
# defaut. Sa cause d'echec est etablie -- le volume du pod est trop petit pour
# le modele, voir docs/STUDIO_VISUEL_REPRISE_2026-08-05.md -- mais le correctif
# n'a pas encore ete verifie sur une machine. Tant qu'il ne l'est pas, une
# scene `genere` retomberait sur un archetype procedural : autant ne pas la
# proposer plutot que promettre une matiere qu'on ne livre pas.
AUTORISER_IMAGES = os.environ.get("STUDIO_AUTORISER_IMAGES", "0") == "1"


def est_deja_une_capsule(scenes: object) -> bool:
    """Dit si ces scenes sont DEJA une capsule 3D, ou un storyboard a traduire.

    Fonction nommee et non pas expression en ligne : c'est le point exact ou
    la composition de l'IA a ete perdue le 12/08, et un defaut qu'on ne peut
    pas tester revient. Voir `test_preparateur.py`.

    Deux formes de capsule coexistent volontairement :
      `gestes`     une COMPOSITION -- des verbes et des coordonnees.
      `archetype`  une des dix formes historiques, gardee comme raccourci.

    Un storyboard de tableau, lui, porte des `blocks` : ni l'un ni l'autre.
    """
    if not isinstance(scenes, list) or not scenes:
        return False
    return any(
        isinstance(s, dict) and (s.get("gestes") or s.get("archetype"))
        for s in scenes)


def journal(message: str) -> None:
    print(f"{time.strftime('%Y-%m-%dT%H:%M:%S')} [preparateur] {message}", flush=True)


def rpc(nom: str, corps: dict | None = None):
    """Appel d'une RPC. Renvoie None plutot que de lever : un service de fond
    ne doit pas mourir parce que le reseau a hoquete."""
    import json
    import urllib.error
    import urllib.request
    try:
        requete = urllib.request.Request(
            f"{SUPABASE_URL}/rest/v1/rpc/{nom}",
            data=json.dumps(corps or {}).encode("utf-8"),
            method="POST",
            headers={
                "apikey": SERVICE_KEY,
                "Authorization": f"Bearer {SERVICE_KEY}",
                "Content-Type": "application/json",
            })
        with urllib.request.urlopen(requete, timeout=60) as reponse:
            brut = reponse.read().decode("utf-8")
        return json.loads(brut) if brut else None
    except Exception as e:  # noqa: BLE001
        journal(f"rpc {nom} indisponible : {str(e)[:160]}")
        return None


def reveiller_une_machine(job_id: str) -> None:
    """Demande une machine TOUT DE SUITE, des que la capsule est prete.

    POURQUOI CE RACCOURCI EXISTE.
    Le preparateur sait a la seconde pres quand la capsule devient prete. Sans
    lui, l'etudiant attendrait le passage d'un cron -- une attente pure,
    pendant laquelle rien ne se passe et rien ne s'affiche.

    POURQUOI `runpod-control` ET PLUS `studio-orchestrateur` (04/09/2026).

    Cet appel visait `studio-orchestrateur`, qui cree ses machines sur
    `runpod/pytorch:...` -- une image generique, SANS Blender ni moteur, ecrite
    en dur ligne 55 de cette fonction. C'est exactement l'image qui a provoque
    le defaut majeur du 14/08 (« deux chaines de production en parallele : la
    vieille a pris le travail et l'a tue en 4 secondes »), apres quoi son cron a
    ete desactive -- mais CET appel-ci, lui, est reste.

    Consequence mesuree : le 21/08 a 06:55, la capsule « la tonneur » etait
    PRETE (1 156 images, 5 scenes, narration de 46 s). Cet appel a cree la
    machine `qlxutcbw5bh5wd` sur la mauvaise image : jamais amorcee, aucune
    adresse SSH, journal vide, tuee a 07:20 pour `amorcage_jamais_abouti`. Le
    cron « filet » evoque ci-dessus etant desactive, **le travail est reste
    bloque 14 jours**. C'etait le dernier travail 3D du projet.

    `runpod-control` est la chaine en service, celle qui a produit les rendus du
    20/08 : elle lit l'image ET l'environnement dans `app.studio_config` (donc
    `academia-studio:1.3.0`, avec Blender et le moteur), demande une RTX 4090 et
    non une A40, et injecte le jeton AVANT la creation -- notre image n'ouvrant
    pas sshd, un jeton ecrit apres coup n'arriverait jamais.

    Les protections restent : plafond de machines et comptage des machines non
    terminees sont dans `runpod-control`. Appeler plus souvent ne peut donc pas
    faire louer davantage.
    """
    import json
    import urllib.request
    try:
        requete = urllib.request.Request(
            f"{SUPABASE_URL}/functions/v1/runpod-control",
            data=json.dumps({"action": "creer"}).encode("utf-8"), method="POST",
            headers={
                "apikey": SERVICE_KEY,
                "Authorization": f"Bearer {SERVICE_KEY}",
                "Content-Type": "application/json",
            })
        with urllib.request.urlopen(requete, timeout=120) as reponse:
            corps = json.loads(reponse.read().decode("utf-8") or "{}")
        action = corps.get("action") or corps.get("error") or "?"
        journal(f"{job_id} machine demandee — {action}"
                + (f" ({corps.get('pod_id')})" if corps.get("pod_id") else ""))
    except Exception as e:  # noqa: BLE001
        # IL N'Y A PLUS DE FILET, ET ON LE DIT.
        #
        # Ce message annoncait « le cron prendra le relais dans 3 min au plus ».
        # C'etait faux depuis le 14/08 : le cron `studio-orchestrateur` a ete
        # desactive ce jour-la, et rien ne l'a remplace. Un message qui promet
        # un rattrapage inexistant est pire que pas de message -- on lit le
        # journal, on se rassure, et le travail dort pendant deux semaines.
        # C'est litteralement ce qui est arrive au travail du 21/08.
        journal(f"{job_id} demande immediate impossible ({str(e)[:120]}) — "
                f"AUCUN RATTRAPAGE AUTOMATIQUE : le travail restera en attente "
                f"tant qu'une machine ne sera pas creee a la main")


def preparer_un(job: dict) -> None:
    """Traduit, narre, et rend le travail pret pour une machine."""
    job_id = job["id"]
    manifeste = job.get("manifeste") or {}
    storyboard = manifeste.get("storyboard") or {}
    discipline = str(manifeste.get("discipline") or "")

    dossier = os.path.join(TRAVAIL, str(job_id))
    shutil.rmtree(dossier, ignore_errors=True)
    os.makedirs(dossier, exist_ok=True)

    try:
        # NE PLUS TRADUIRE CE QUI EST DEJA ECRIT POUR NOUS.
        #
        # Depuis le 07/08, l'Edge Function genere DIRECTEMENT une capsule quand
        # l'etudiant choisit l'animation : le modele choisit lui-meme la forme
        # qui sert le propos, au lieu qu'un adaptateur la devine a partir du
        # type de bloc.
        #
        # La traduction reste en place pour les cours generes AVANT ce
        # changement, et pour un etudiant qui bascule un cours ecrit pour le
        # tableau vers la 3D. Les deux entrees doivent marcher.
        #
        # LE PIEGE QUI ETAIT ICI, ET C'ETAIT LE SEPTIEME DU MEME DEFAUT.
        # La reconnaissance ne testait QUE `archetype`. Or une capsule COMPOSEE
        # ne porte pas d'archetype : elle porte des `gestes`. Elle etait donc
        # prise pour un storyboard de tableau, passee a `depuis_storyboard`, et
        # ressortait en archetypes -- `reseau` faute de `blocks` a traduire.
        #
        # Mesure du 12/08 18h21, travail 1396f11c : « Poussee d'Archimede »,
        # cinq scenes composees (revolutionner, sculpter, extruder), arrivait
        # dans la file avec `gestes` absent et `archetype = reseau`. La machine
        # etait deja allumee et allait rendre la video generique. Rien n'avait
        # echoue ; aucun message n'avait ete emis.
        #
        # On teste donc les DEUX formes de capsule. Un storyboard de tableau se
        # distingue par ses `blocks`, qu'aucune des deux ne porte.
        deja_capsule = est_deja_une_capsule(storyboard.get("scenes"))

        if deja_capsule:
            capsule = academia_scene.normaliser(dict(storyboard))
            journal(f"{job_id} capsule native — " + academia_scene.resume(capsule))
        else:
            capsule = depuis_storyboard.convertir(
                storyboard, discipline=discipline,
                autoriser_images=AUTORISER_IMAGES)
            capsule = academia_scene.normaliser(capsule)
            journal(f"{job_id} traduit depuis un storyboard — "
                    + academia_scene.resume(capsule))

        # Le garde-fou des images IA vaut aussi pour la generation native : le
        # modele peut proposer `genere`, mais tant que la cause du noir n'est
        # pas verifiee sur GPU, on n'en promet pas.
        if not AUTORISER_IMAGES:
            remplacees = 0
            for scene in capsule["scenes"]:
                if scene["archetype"] in academia_scene.ARCHETYPES_IA:
                    scene["archetype"] = "terrain"
                    remplacees += 1
            if remplacees:
                journal(f"{job_id} {remplacees} scene(s) `genere` ramenee(s) sur "
                        f"`terrain` (images IA desactivees)")

        # La voix commande l'image : `caler` remplace chaque duree estimee par
        # la duree MESUREE sur la voix reellement synthetisee.
        capsule = narration.caler(capsule, dossier)
        capsule = academia_scene.normaliser(capsule)

        muette = not capsule.get("narration_url")
        if muette:
            # On refuse plutot que de louer une machine pour une capsule sans
            # voix : l'etudiant a demande un cours, pas un diaporama muet.
            rpc("studio_preparation_echouee", {
                "p_job_id": job_id, "p_worker_key": CLE_WORKER,
                "p_erreur": "voix indisponible — capsule non mise en file"})
            journal(f"{job_id} REFUSE : aucune voix obtenue")
            return

        reponse = rpc("studio_capsule_prete", {
            "p_job_id": job_id, "p_worker_key": CLE_WORKER, "p_manifeste": capsule})
        if reponse and reponse.get("success"):
            journal(f"{job_id} PRET — {capsule['duree_totale_s']}s, "
                    f"{capsule['images_total']} images, {reponse.get('scenes')} scenes")
            reveiller_une_machine(job_id)
        else:
            journal(f"{job_id} mise en file refusee : {reponse}")
    except Exception as e:  # noqa: BLE001
        # ECHOUER BRUYAMMENT. Un travail laisse en `preparation` bloquerait la
        # file en silence, et l'etudiant regarderait tourner une roue.
        detail = f"{type(e).__name__}: {e}"[:400]
        journal(f"{job_id} ECHEC — {detail}")
        journal(traceback.format_exc()[-600:])
        rpc("studio_preparation_echouee", {
            "p_job_id": job_id, "p_worker_key": CLE_WORKER, "p_erreur": detail})
    finally:
        shutil.rmtree(dossier, ignore_errors=True)


def main() -> int:
    if not (SUPABASE_URL and SERVICE_KEY):
        journal("ERREUR SUPABASE_URL ou SUPABASE_SERVICE_KEY absent")
        return 2

    os.makedirs(TRAVAIL, exist_ok=True)
    journal(f"demarre (cle={CLE_WORKER}, intervalle={INTERVALLE}s, "
            f"images IA {'autorisees' if AUTORISER_IMAGES else 'desactivees'})")

    hote = socket.gethostname()
    while True:
        reponse = rpc("studio_prendre_a_preparer",
                      {"p_worker_key": CLE_WORKER, "p_host": hote})
        job = (reponse or {}).get("job")
        if job:
            journal(f"travail {job['id']} — {job.get('titre')}")
            preparer_un(job)
        else:
            time.sleep(INTERVALLE)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(0)

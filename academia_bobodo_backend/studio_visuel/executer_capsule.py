#!/usr/bin/env python3
"""Execute une capsule de bout en bout sur le pod, puis DEPOSE le resultat.

Rendu -> sous-titres -> assemblage -> controle -> depot Supabase.

POURQUOI TOUT D'UN TRAIT. Deux lecons payees le 30/07 :

  1. Une capsule rendue avec succes a ete PERDUE parce que je la telechargeais
     a la main apres coup, et que le veilleur a supprime la machine entre-temps.
     `podTerminate` efface /workspace. Un resultat qui n'est pas sorti de la
     machine n'existe pas.
  2. Sur une machine de 66 minutes, 12 minutes de calcul : le reste attendait
     pendant que je reflechissais. Une ressource au compteur ne doit jamais
     servir d'atelier interactif.

D'ou ce script : on prepare tout hors ligne, on lance UNE fois, la machine fait
tout, depose, et peut mourir juste apres sans que rien ne soit perdu.

Usage :
  POD_ID=... POD_JETON=... SUPABASE_URL=... SUPABASE_ANON_KEY=... \\
  python3 executer_capsule.py capsule.json
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, "/workspace")

import academia_scene  # noqa: E402
import montage  # noqa: E402

BLENDER = os.environ.get("BLENDER", "/workspace/blender/blender")
GENERATEUR = os.environ.get("GENERATEUR", "/workspace/generateur_scenes.py")
TRAVAIL = os.environ.get("TRAVAIL", "/workspace/capsule")
BUCKET = "studio-visuel"

SUPABASE_URL = os.environ.get("SUPABASE_URL", "").rstrip("/")
SUPABASE_KEY = os.environ.get("SUPABASE_ANON_KEY", "")


def journal(message: str) -> None:
    print(f"{time.strftime('%H:%M:%S')} {message}", flush=True)


def deposer(chemin: str, cle: str) -> tuple[bool, str]:
    """Depot dans le bucket prive. C'est l'etape qui fait EXISTER le resultat ;
    tout ce qui precede n'est que calcul jetable.

    PAS D'`x-upsert`. Il a coute une heure de diagnostic : l'ecrasement oblige
    Supabase a VERIFIER si l'objet existe, donc a le LIRE -- or la lecture du
    bucket est volontairement fermee, les videos ne sortant que par URL signee.
    Resultat : un 403 « row-level security » parfaitement trompeur, alors que
    la policy d'ecriture etait correcte.

    Le chemin horodate resout les deux problemes a la fois : plus besoin
    d'ecraser, et on conserve l'historique des rendus -- ce qui compte pour la
    validation editoriale, ou l'on veut pouvoir comparer deux versions.
    """
    if not (SUPABASE_URL and SUPABASE_KEY):
        return False, "configuration_supabase_absente"
    try:
        import urllib.request
        with open(chemin, "rb") as f:
            donnees = f.read()
        requete = urllib.request.Request(
            f"{SUPABASE_URL}/storage/v1/object/{BUCKET}/{cle}",
            data=donnees, method="POST",
            headers={
                "apikey": SUPABASE_KEY,
                "Authorization": f"Bearer {SUPABASE_KEY}",
                "Content-Type": "video/mp4",
            })
        with urllib.request.urlopen(requete, timeout=600) as reponse:
            return reponse.status < 300, str(reponse.status)
    except Exception as e:  # noqa: BLE001
        return False, str(e)[:200]


def recuperer_narration(capsule: dict) -> str | None:
    """Telecharge la bande produite par LWS, si elle existe.

    Degradation gracieuse : sans narration, la capsule est produite muette
    plutot que pas produite du tout. Le journal le dit clairement -- une
    capsule silencieuse par accident et une capsule silencieuse par choix ne
    doivent pas se ressembler.
    """
    cle = capsule.get("narration_cle")
    if not cle:
        journal("NARRATION aucune bande annoncee — capsule muette")
        return None
    if not (SUPABASE_URL and SUPABASE_KEY):
        journal("NARRATION configuration absente — capsule muette")
        return None
    try:
        import urllib.request
        requete = urllib.request.Request(
            f"{SUPABASE_URL}/storage/v1/object/{BUCKET}/{cle}",
            headers={"apikey": SUPABASE_KEY,
                     "Authorization": f"Bearer {SUPABASE_KEY}"})
        with urllib.request.urlopen(requete, timeout=300) as reponse:
            donnees = reponse.read()
        chemin = os.path.join(TRAVAIL, "narration.wav")
        with open(chemin, "wb") as f:
            f.write(donnees)
        journal(f"NARRATION recuperee — {len(donnees)//1024} Ko")
        return chemin
    except Exception as e:  # noqa: BLE001
        journal(f"NARRATION indisponible ({e}) — capsule muette")
        return None


def executer(capsule: dict, travail: str | None = None) -> tuple[bool, str]:
    """Produit la capsule complete. Renvoie (succes, chemin_video | erreur).

    Extrait de `main` pour que le worker de la file l'appelle directement :
    sans cela, deux chemins de code auraient diverge -- l'un pour les rendus
    manuels, l'autre pour la file -- et un correctif applique a l'un aurait
    manque a l'autre. C'est exactement ainsi qu'on se retrouve avec une capsule
    muette d'un cote et sonore de l'autre.
    """
    global TRAVAIL
    if travail:
        TRAVAIL = travail

    capsule = academia_scene.normaliser(capsule)
    journal("CAPSULE " + academia_scene.resume(capsule))
    for correction in capsule["avertissements"]:
        journal(f"  correction: {correction}")

    images = os.path.join(TRAVAIL, "frames")
    os.makedirs(images, exist_ok=True)
    depart = time.time()

    # ── 1. Rendu ──────────────────────────────────────────────────────────
    journal("RENDU en cours")
    with open(os.path.join(TRAVAIL, "capsule_normalisee.json"), "w", encoding="utf-8") as f:
        json.dump(capsule, f, ensure_ascii=False)

    rendu = subprocess.run(
        [BLENDER, "-b", "--python", GENERATEUR, "--",
         os.path.join(TRAVAIL, "capsule_normalisee.json"), images],
        capture_output=True, text=True, timeout=10800)

    for ligne in rendu.stdout.splitlines():
        if ligne.startswith(("SCENE ", "GENERATEUR_", "CAPSULE ")):
            journal("  " + ligne)

    produites = [n for n in os.listdir(images) if n.endswith(".png")]
    if not produites:
        journal("ECHEC aucune image produite")
        journal(rendu.stdout[-800:] or rendu.stderr[-800:])
        return False, "aucune_image_produite"
    journal(f"RENDU termine — {len(produites)} images en {int(time.time()-depart)}s")

    # ── 2. Sous-titres ────────────────────────────────────────────────────
    ass = os.path.join(TRAVAIL, "sous_titres.ass")
    nombre = montage.ecrire_sous_titres(capsule, ass)
    journal(f"SOUS-TITRES {nombre} ecrits")

    # ── 3. Narration ──────────────────────────────────────────────────────
    # Produite en amont sur LWS, deposee dans Storage, recuperee ici. Sans
    # cette etape la capsule sortait MUETTE : la voix existait, le montage
    # aussi, mais ils ne se rencontraient jamais -- et les deux journaux
    # affichaient un succes.
    bande = recuperer_narration(capsule)

    # ── 4. Assemblage ─────────────────────────────────────────────────────
    video = os.path.join(TRAVAIL, "capsule.mp4")
    ok, detail = montage.assembler(images, capsule, video, chemin_ass=ass, audio=bande)
    if not ok:
        journal(f"ECHEC assemblage: {detail}")
        return False, f"assemblage:{detail}"
    journal(f"ASSEMBLAGE termine — {os.path.getsize(video)//1024} Ko")

    # ── 4. Controle automatique (etape 10 du cahier des charges) ──────────
    infos = montage.verifier(video)
    journal(f"CONTROLE {infos}")
    if infos.get("lisible") != "True":
        journal("ECHEC video illisible — on ne depose pas un fichier corrompu")
        return False, "video_illisible"

    # ── 5. Depot ──────────────────────────────────────────────────────────
    # Horodate : chaque rendu garde sa trace, et aucun ecrasement n'est
    # necessaire — voir `deposer`.
    cle = f"capsules/{capsule['capsule_id']}/{int(depart)}/capsule.mp4"
    depose, detail = deposer(video, cle)
    journal(f"DEPOT {'reussi' if depose else 'ECHEC'} — {cle} ({detail})")
    if not depose:
        return False, f"depot:{detail}"

    total = int(time.time() - depart)
    journal(f"TERMINE en {total}s — cout GPU estime {total/3600*0.44:.3f} USD")
    journal(f"RESULTAT {BUCKET}/{cle}")
    return True, cle


def main() -> int:
    if len(sys.argv) < 2:
        journal("ERREUR chemin_json_manquant")
        return 1
    with open(sys.argv[1], encoding="utf-8") as f:
        capsule = json.load(f)
    ok, detail = executer(capsule)
    if not ok:
        journal(f"ECHEC {detail}")
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())

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


def main() -> int:
    if len(sys.argv) < 2:
        journal("ERREUR chemin_json_manquant")
        return 1

    with open(sys.argv[1], encoding="utf-8") as f:
        capsule = academia_scene.normaliser(json.load(f))

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
        return 2
    journal(f"RENDU termine — {len(produites)} images en {int(time.time()-depart)}s")

    # ── 2. Sous-titres ────────────────────────────────────────────────────
    ass = os.path.join(TRAVAIL, "sous_titres.ass")
    nombre = montage.ecrire_sous_titres(capsule, ass)
    journal(f"SOUS-TITRES {nombre} ecrits")

    # ── 3. Assemblage ─────────────────────────────────────────────────────
    video = os.path.join(TRAVAIL, "capsule.mp4")
    ok, detail = montage.assembler(images, capsule, video, chemin_ass=ass)
    if not ok:
        journal(f"ECHEC assemblage: {detail}")
        return 3
    journal(f"ASSEMBLAGE termine — {os.path.getsize(video)//1024} Ko")

    # ── 4. Controle automatique (etape 10 du cahier des charges) ──────────
    infos = montage.verifier(video)
    journal(f"CONTROLE {infos}")
    if infos.get("lisible") != "True":
        journal("ECHEC video illisible — on ne depose pas un fichier corrompu")
        return 4

    # ── 5. Depot ──────────────────────────────────────────────────────────
    # Horodate : chaque rendu garde sa trace, et aucun ecrasement n'est
    # necessaire — voir `deposer`.
    cle = f"capsules/{capsule['capsule_id']}/{int(depart)}/capsule.mp4"
    depose, detail = deposer(video, cle)
    journal(f"DEPOT {'reussi' if depose else 'ECHEC'} — {cle} ({detail})")
    if not depose:
        return 5

    total = int(time.time() - depart)
    journal(f"TERMINE en {total}s — cout GPU estime "
            f"{total/3600*0.44:.3f} USD")
    journal(f"RESULTAT {BUCKET}/{cle}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

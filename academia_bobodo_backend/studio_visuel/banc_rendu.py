#!/usr/bin/env python3
"""Banc de mesure du rendu — separe CE QUI EST FIXE de CE QUI EST PROPORTIONNEL.

POURQUOI CE FICHIER EXISTE.
Toutes les decisions d'architecture du Studio butent sur une inconnue : le
COUT FIXE d'une machine. Mesure du 07/08 sur dix amorcages reels : mediane
3 min 25, meilleur cas 1 min 50, du `podFindAndDeploy` au « worker en marche ».
Mais cet amorcage n'est qu'une partie du fixe. Il reste, une fois la machine
prete et AVANT la premiere image utile :

    - le lancement de Blender ;
    - la construction de la scene ;
    - la COMPILATION DES SHADERS EEVEE, qui se paie sur la premiere image.

Tant que ces trois-la ne sont pas chiffres separement, decider combien de
machines louer pour decouper un rendu est une devinette : si le fixe vaut F et
le calcul T, le temps mural est T/N + F, et aucun N ne descend sous F.

CE QUE LE BANC MESURE, ET IL NE MOYENNE RIEN.

    lancement       demarrage de Blender jusqu'a l'execution du script
    construction    creation de la geometrie d'une scene reelle
    premiere image  compilation des shaders comprise -- toujours la plus chere
    regime etabli   mediane et P95 des images suivantes
    encodage        assemblage ffmpeg de la sequence

On rend une sequence de DIX SECONDES, soit 250 images a 25 i/s : assez pour
que le regime etabli se degage du bruit, assez court pour que la campagne
complete tienne dans quelques minutes de machine.

Usage :
    python3 banc_rendu.py <archetype> <largeur> <hauteur> <echantillons> [images]
"""

from __future__ import annotations

import json
import os
import statistics
import subprocess
import sys
import time

SORTIE = os.environ.get("BANC_SORTIE", "/workspace/banc")


def journal(m: str) -> None:
    print(f"{time.strftime('%H:%M:%S')} [banc] {m}", flush=True)


def mesurer(archetype: str, largeur: int, hauteur: int, echantillons: int,
            images: int) -> dict:
    """Rend `images` images et chronometre chaque phase separement."""
    import random

    import bpy  # noqa: F401  (present uniquement dans Blender)

    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import academia_scene
    import generateur_scenes as gen
    import style_reference as style

    resultat: dict = {
        "archetype": archetype, "largeur": largeur, "hauteur": hauteur,
        "echantillons": echantillons, "images_demandees": images,
        "gpu": os.environ.get("BANC_GPU", "?"),
    }

    # ── Construction de la scene ──────────────────────────────────────────
    t = time.time()
    scene_def = academia_scene._nettoyer_scene({
        "id": "banc", "archetype": archetype,
        "narration": "x " * 40, "duree_s": images / 25.0,
        "parametres": {"texte": "100 m", "texte_second": "sans pompe"},
    }, 0, [])
    gen._EST_ACCROCHE = False
    gen._vider()
    distance = gen.ARCHETYPES[archetype](
        scene_def, images, academia_scene.ACCENTS["orange"], random.Random(3))
    # Meme ordre qu'en production (`rendre_scene`) : sans elle, le banc
    # mesurerait une scene que personne ne rend.
    brume = style.atmosphere(distance)
    resultat["brume"] = brume is not None
    gen._camera(scene_def["camera"], distance, images)
    resultat["construction_s"] = round(time.time() - t, 2)

    scene = bpy.context.scene
    scene.render.resolution_x, scene.render.resolution_y = largeur, hauteur
    scene.render.fps = 25
    scene.render.image_settings.file_format = "PNG"
    style.monde_nuit(scene)
    style.cadre_cinema(scene)
    style.compositing(scene)
    style.moteur_eevee(scene, echantillons=echantillons)

    dossier = os.path.join(SORTIE, f"{archetype}_{largeur}x{hauteur}_{echantillons}")
    os.makedirs(dossier, exist_ok=True)

    # ── Images, une par une ───────────────────────────────────────────────
    # On chronometre CHAQUE image. La premiere porte la compilation des
    # shaders : la noyer dans une moyenne masquerait justement le cout fixe
    # qu'on cherche a mesurer.
    durees: list[float] = []
    for i in range(1, images + 1):
        scene.frame_set(i)
        scene.render.filepath = os.path.join(dossier, f"i_{i:04d}.png")
        t = time.time()
        bpy.ops.render.render(write_still=True)
        durees.append(time.time() - t)
        if i == 1:
            journal(f"  premiere image (shaders compris) : {durees[0]:.2f}s")
        elif i % 50 == 0:
            journal(f"  {i}/{images} — {statistics.median(durees[1:]):.2f}s/image")

    resultat["premiere_image_s"] = round(durees[0], 3)
    suite = durees[1:] or durees
    resultat["regime_median_s"] = round(statistics.median(suite), 3)
    resultat["regime_p95_s"] = round(sorted(suite)[int(len(suite) * 0.95) - 1], 3)
    resultat["rendu_total_s"] = round(sum(durees), 1)
    # Ce que coute la compilation des shaders, isolee : c'est elle qu'on paie
    # a chaque machine supplementaire dans un decoupage.
    resultat["surcout_premiere_image_s"] = round(
        durees[0] - resultat["regime_median_s"], 3)

    # ── Encodage ──────────────────────────────────────────────────────────
    video = os.path.join(dossier, "sortie.mp4")
    t = time.time()
    r = subprocess.run(
        ["ffmpeg", "-y", "-v", "error", "-framerate", "25",
         "-i", os.path.join(dossier, "i_%04d.png"),
         "-c:v", "libx264", "-preset", "veryfast", "-crf", "20",
         "-pix_fmt", "yuv420p", video],
        capture_output=True, text=True, timeout=1800)
    resultat["encodage_s"] = round(time.time() - t, 2)
    resultat["encodage_ok"] = r.returncode == 0
    if os.path.isfile(video):
        resultat["poids_ko"] = os.path.getsize(video) // 1024

    # Projection sur une capsule reelle de 100 s : c'est le chiffre qui parle.
    resultat["projection_2500_images_min"] = round(
        (resultat["regime_median_s"] * 2500) / 60, 1)
    return resultat


def main() -> int:
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    if len(args) < 4:
        print("usage: banc_rendu.py <archetype> <largeur> <hauteur> "
              "<echantillons> [images]", flush=True)
        return 1
    archetype = args[0]
    largeur, hauteur, echantillons = int(args[1]), int(args[2]), int(args[3])
    images = int(args[4]) if len(args) > 4 else 250

    os.makedirs(SORTIE, exist_ok=True)
    journal(f"{archetype} {largeur}x{hauteur} {echantillons} echantillons, "
            f"{images} images")
    r = mesurer(archetype, largeur, hauteur, echantillons, images)

    chemin = os.path.join(SORTIE, "mesures.jsonl")
    with open(chemin, "a", encoding="utf-8") as f:
        f.write(json.dumps(r, ensure_ascii=False) + "\n")

    print("BANC_RESULTAT " + json.dumps(r, ensure_ascii=False), flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())

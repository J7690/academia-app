"""Recompose la DEUXIEME image de reference, uniquement avec des verbes.

C'EST LE TEST D'ACCEPTATION DU VOCABULAIRE. Si les verbes d'`academia3d` ne
suffisent pas a reproduire une image que Jocelyn a fournie comme cible, ils
sont mal choisis -- et il vaut mieux le savoir sur vingt lignes que sur une
capsule de quatre-vingts minutes.

L'image visee : terrain en grille filaire bleu jusqu'a l'horizon, lueur
rouge-orange affleurant dessous, ovoides facettes translucides flottant a des
profondeurs echelonnees, halo, profondeur de champ, 9:16.

AUCUNE BANQUE DE MAILLAGES N'EST NECESSAIRE ICI : un ovoide se genere par
equation. C'est la PREMIERE image de reference -- le corps humain -- qui
exigera `convoquer` et des maillages.

CE QUE LA CALIBRATION CHERCHE, ET C'EST UNE SEULE CHOSE.
Sur la reference, l'ecran reste MAJORITAIREMENT NOIR et seuls quelques
elements brillent. `style_reference.py` le dit depuis le 30/07 : « c'est le
rapport qui fait le premium, pas l'intensite absolue ». Le premier rendu du
12/08 echouait precisement la -- des cordes bleues pales sur un fond clair.
Les trois leviers sont donc, dans l'ordre : ARETES FINES, EMISSION FORTE,
EXPOSITION NEGATIVE.

Usage :
    blender -b --python scene_oeufs.py -- [sortie.png] [largeur] [hauteur] [echantillons]
"""

from __future__ import annotations

import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402
import academia3d as a3  # noqa: E402
import academia3d_style as st  # noqa: E402
import style_reference as style  # noqa: E402

# ── Ce fichier ne contient PLUS de reglage de style ───────────────────────
# Les huit constantes calibrees le 12/08 vivaient ici. Elles n'y sont plus :
# une scene qui porte son propre style produit une capsule qui ne ressemble a
# aucune autre. Elles sont dans `academia3d_style.py`, et TOUTES les scenes en
# heritent. Les epaisseurs y sont des RAPPORTS, calcules ici a partir des
# dimensions reelles de la scene.
#
# Ce qui reste ici est la MISE EN SCENE, et elle seule : quels objets, ou est
# la camera, combien d'exemplaires. C'est exactement ce que l'IA devra ecrire
# pour chaque sujet.

COTE_SOL = 220.0      # le terrain s'etend loin : c'est ce qui cree l'horizon
PAS_SOL = 46          # mailles LARGES : a 110 divisions, la grille lue a ras
                      # devenait un enchevetrement illisible
NOMBRE_OEUFS = 8
OUVERTURE = 1.4       # cadrage : petit nombre = lointains fondus


def composer():
    """La scene, en verbes. C'est le point : vingt lignes, aucune primitive."""
    a3.vider()
    a3.nuiter()

    # Le sol s'etend LOIN : c'est ce qui cree l'horizon, et l'horizon est la
    # moitie de l'image de reference.
    sol = a3.napper(cote=COTE_SOL, pas=PAS_SOL, amplitude=1.8)
    a3.affleurer(sol, chaleur=st.CHALEUR_AFFLEUREMENT, dessous=0.9,
                 etendue=COTE_SOL)
    a3.filairer(sol, epaisseur=st.arete_grille(COTE_SOL, PAS_SOL),
                emission=st.EMISSION_STRUCTURE)

    # Les oeufs. `essaimer` appelle `fabriquer` pour CHACUN : c'est une boucle,
    # pas une duplication -- chaque exemplaire est legerement different.
    def un_oeuf(position, echelle, graine):
        oeuf = a3.sculpter("ovoide", facettes=1, echelle=echelle,
                           position=position, deformation=0.05, graine=graine)
        a3.vitrer(oeuf, force=st.VERRE_FORCE, densite_bord=st.VERRE_BORD)
        a3.filairer(oeuf, epaisseur=st.arete_objet(echelle),
                    emission=st.EMISSION_SUJET, garder_surface=True)
        return oeuf

    a3.essaimer(un_oeuf, nombre=NOMBRE_OEUFS, etendue=26.0,
                profondeur=(-4.0, -56.0),   # Y : du proche au lointain
                altitudes=(3.0, 8.5),       # Z : la hauteur
                echelles=(1.7, 3.0))

    # Camera BASSE et proche du sol : c'est elle qui met l'horizon en haut du
    # cadre et laisse le noir occuper le ciel.
    a3.cadrer(vise=(0.0, -26.0, 1.0), depuis=(1.2, 16.0, 13.5),
              focale=42.0, ouverture=OUVERTURE, mise_au_point=26.0)
    a3.haloter(taille=st.HALO_TAILLE, exposition=st.EXPOSITION)


def main() -> int:
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    sortie = args[0] if args else "/scene/oeufs.png"
    largeur = int(args[1]) if len(args) > 1 else 540
    hauteur = int(args[2]) if len(args) > 2 else 960
    echantillons = int(args[3]) if len(args) > 3 else 16

    composer()

    scene = bpy.context.scene
    scene.render.resolution_x = largeur
    scene.render.resolution_y = hauteur
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = sortie
    style.cadre_cinema(scene)
    style.moteur_eevee(scene, echantillons=echantillons)

    t = time.time()
    bpy.ops.render.render(write_still=True)
    ecoule = time.time() - t

    poids = os.path.getsize(sortie) if os.path.isfile(sortie) else 0
    print(f"SCENE_OEUFS sortie={sortie} secondes={ecoule:.1f} octets={poids} "
          f"objets={len(bpy.data.objects)}", flush=True)
    # Une image de quelques kilo-octets est une image NOIRE : on le dit ici
    # plutot que de le decouvrir en la regardant.
    if poids < 15000:
        print("SCENE_OEUFS ALERTE image tres legere — probablement noire", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())

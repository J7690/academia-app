# Essai de style : la meme scene que le banc, mais avec la grammaire visuelle
# corrigee. Sert a juger l'ecart avec la video de reference.
#
# Rendu volontairement en 540x960 : pour JUGER UN STYLE, la demi-resolution
# suffit et coute quatre fois moins. On ne passe en pleine resolution qu'une
# fois le style arrete.
#
# Usage : blender -b --python essai_style.py

import bpy
import math
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, "/workspace")
import style_reference as style

LARGEUR = int(os.environ.get("ESSAI_LARGEUR", "540"))
HAUTEUR = int(os.environ.get("ESSAI_HAUTEUR", "960"))
IMAGES = int(os.environ.get("ESSAI_IMAGES", "3"))
SORTIE = os.environ.get("ESSAI_SORTIE", "/workspace/essai")


def nettoyer():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


def vegetation():
    bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 0, 0))
    sol = bpy.context.object
    sol.data.materials.append(style.matiere_sol())

    systeme = sol.modifiers.new("herbe", "PARTICLE_SYSTEM")
    reglages = systeme.particle_system.settings
    reglages.type = "HAIR"
    # Sur la reference, on DISTINGUE chaque filament parce qu'il y a du noir
    # entre eux. Le premier essai en mettait 150 000 : ils fusionnaient en un
    # aplat bleu. Moins de brins, plus fins, moins lumineux -- c'est le vide
    # entre les filaments qui fait la texture, pas les filaments.
    reglages.count = 2200
    reglages.hair_length = 2.4
    reglages.hair_step = 5
    reglages.child_type = "INTERPOLATED"
    reglages.rendered_child_count = 6
    reglages.child_length = 0.9
    reglages.brownian_factor = 0.7
    reglages.root_radius = 0.012
    reglages.tip_radius = 0.0
    sol.data.materials.append(style.matiere_emissive("filaments", style.BLEU_FROID, 0.35))
    reglages.material = 2


def feu():
    # Nettement plus grande. Les volumetriques d'EEVEE s'echantillonnent dans
    # une grille liee a la taille A L'ECRAN : une colonne minuscule voit toute
    # sa structure ecrasee et redevient un bloc, quel que soit le bruit. C'est
    # ce qui faisait echouer les deux essais precedents.
    bpy.ops.mesh.primitive_cube_add(size=2.0, location=(0, 0, 3.2))
    colonne = bpy.context.object
    colonne.scale = (1.6, 1.6, 3.4)
    # Densite et emission relevees pour compenser l'enveloppe : celle-ci
    # eteint la flamme sur tout son rayon, il faut donc partir de bien plus
    # haut au coeur pour que le coeur reste incandescent.
    colonne.data.materials.append(style.matiere_feu(densite=22.0, force=16.0))

    bpy.ops.mesh.primitive_cube_add(size=44, location=(0, 0, 6))
    brume = bpy.context.object
    brume.data.materials.append(style.matiere_brume())


def camera():
    # Recule et abaisse : sur la reference le sujet occupe une petite part du
    # cadre, entoure de noir. C'est ce qui donne l'echelle.
    # Plus haute, et l'horizon remonte : dans l'essai precedent le sol occupait
    # les trois quarts du cadre. Sur la reference, le noir domine.
    bpy.ops.object.camera_add(location=(13, -13, 5.0),
                              rotation=(math.radians(80), 0, math.radians(45)))
    cam = bpy.context.object
    cam.data.lens = 52
    cam.data.dof.use_dof = True
    cam.data.dof.focus_distance = 24.0
    cam.data.dof.aperture_fstop = 2.4
    bpy.context.scene.camera = cam

    for image in range(1, IMAGES + 1):
        t = (image - 1) / max(IMAGES - 1, 1)
        cam.location = (17 - 1.5 * t, -17 + 1.5 * t, 2.6 + 0.5 * t)
        cam.keyframe_insert("location", frame=image)


def main():
    nettoyer()
    vegetation()
    feu()
    camera()

    scene = bpy.context.scene
    scene.render.resolution_x = LARGEUR
    scene.render.resolution_y = HAUTEUR
    scene.frame_start = 1
    scene.frame_end = IMAGES
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = f"{SORTIE}/essai_"

    style.monde_nuit(scene)
    style.cadre_cinema(scene)
    style.compositing(scene)
    style.moteur_eevee(scene)

    os.makedirs(SORTIE, exist_ok=True)
    debut = time.time()
    bpy.ops.render.render(animation=True)
    print(f"ESSAI_TERMINE images={IMAGES} total={time.time()-debut:.1f}s", flush=True)


main()

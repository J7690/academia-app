# Banc d'essai : EEVEE Next contre Cycles, sur le style de la video de reference.
#
# POURQUOI CE TEST DECIDE DE TOUT. La video de reference dure 140 s a 30 i/s,
# soit 4 200 images. A 15 s l'image en Cycles, une seule capsule couterait
# ~7,70 $ -- les trois quarts du credit. Si EEVEE tient la qualite, le meme
# rendu tombe sous le dollar. Ce n'est donc pas une optimisation, c'est une
# condition d'existence du studio.
#
# La scene reprend les cinq marqueurs releves sur la reference :
#   1. vegetation en filaments (systeme de particules cheveux)
#   2. volumetrique emissif pour le feu et la brume
#   3. deux teintes seulement : cyan/bleu et rouge/orange
#   4. emission comme seule source de lumiere
#   5. halos au compositing
#
# Usage : blender -b --python banc_eevee_vs_cycles.py

import bpy
import math
import os
import time

LARGEUR = int(os.environ.get("BANC_LARGEUR", "1080"))
HAUTEUR = int(os.environ.get("BANC_HAUTEUR", "1920"))
IMAGES = int(os.environ.get("BANC_IMAGES", "3"))
SORTIE = os.environ.get("BANC_SORTIE", "/workspace/banc")

CYAN = (0.10, 0.45, 1.0, 1.0)
ORANGE = (1.0, 0.22, 0.03, 1.0)


def nettoyer():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


def matiere_emissive(nom, couleur, force):
    mat = bpy.data.materials.new(nom)
    mat.use_nodes = True
    arbre = mat.node_tree
    arbre.nodes.clear()
    emission = arbre.nodes.new("ShaderNodeEmission")
    emission.inputs["Color"].default_value = couleur
    emission.inputs["Strength"].default_value = force
    sortie = arbre.nodes.new("ShaderNodeOutputMaterial")
    arbre.links.new(emission.outputs["Emission"], sortie.inputs["Surface"])
    return mat


def vegetation():
    """Le sol et sa fourrure lumineuse. Sur la reference, les arbres ne sont pas
    des modeles 3D mais des filaments -- c'est ce qui donne la texture."""
    bpy.ops.mesh.primitive_plane_add(size=26, location=(0, 0, 0))
    sol = bpy.context.object
    sol.data.materials.append(matiere_emissive("sol", (0.01, 0.03, 0.10, 1.0), 0.4))

    systeme = sol.modifiers.new("herbe", "PARTICLE_SYSTEM")
    reglages = systeme.particle_system.settings
    reglages.type = "HAIR"
    reglages.count = 4000
    reglages.hair_length = 1.7
    reglages.hair_step = 3
    reglages.child_type = "INTERPOLATED"
    reglages.rendered_child_count = 40
    reglages.child_length = 0.9
    reglages.brownian_factor = 0.4

    # Les cheveux prennent la matiere de l'emplacement 2 : on l'ajoute apres.
    sol.data.materials.append(matiere_emissive("filaments", CYAN, 2.6))
    reglages.material = 2


def feu_volumetrique():
    """La colonne de feu et la brume. C'est le poste le plus cher en Cycles, et
    c'est justement ce qu'on veut mesurer."""
    bpy.ops.mesh.primitive_cube_add(size=3.0, location=(0, 0, 2.2))
    feu = bpy.context.object
    feu.scale = (0.5, 0.5, 1.6)

    mat = bpy.data.materials.new("feu")
    mat.use_nodes = True
    arbre = mat.node_tree
    arbre.nodes.clear()
    volume = arbre.nodes.new("ShaderNodeVolumePrincipled")
    volume.inputs["Color"].default_value = ORANGE
    volume.inputs["Density"].default_value = 2.2
    volume.inputs["Emission Strength"].default_value = 14.0
    volume.inputs["Emission Color"].default_value = ORANGE
    sortie = arbre.nodes.new("ShaderNodeOutputMaterial")
    arbre.links.new(volume.outputs["Volume"], sortie.inputs["Volume"])
    feu.data.materials.append(mat)

    # Brume d'ambiance : c'est elle qui fait « cinema » plutot que « schema ».
    bpy.ops.mesh.primitive_cube_add(size=30, location=(0, 0, 4))
    brume = bpy.context.object
    mat2 = bpy.data.materials.new("brume")
    mat2.use_nodes = True
    a2 = mat2.node_tree
    a2.nodes.clear()
    diffusion = a2.nodes.new("ShaderNodeVolumeScatter")
    diffusion.inputs["Color"].default_value = (0.05, 0.20, 0.75, 1.0)
    diffusion.inputs["Density"].default_value = 0.012
    s2 = a2.nodes.new("ShaderNodeOutputMaterial")
    a2.links.new(diffusion.outputs["Volume"], s2.inputs["Volume"])
    brume.data.materials.append(mat2)


def camera():
    bpy.ops.object.camera_add(location=(11, -11, 3.4), rotation=(math.radians(80), 0, math.radians(45)))
    cam = bpy.context.object
    cam.data.lens = 45
    cam.data.dof.use_dof = True          # profondeur de champ : marqueur premium
    cam.data.dof.focus_distance = 15.0
    cam.data.dof.aperture_fstop = 1.8
    bpy.context.scene.camera = cam

    for image in range(1, IMAGES + 1):
        t = (image - 1) / max(IMAGES - 1, 1)
        cam.location = (11 - 1.2 * t, -11 + 1.2 * t, 3.4 + 0.8 * t)
        cam.keyframe_insert("location", frame=image)


def commun():
    scene = bpy.context.scene
    scene.render.resolution_x = LARGEUR
    scene.render.resolution_y = HAUTEUR
    scene.frame_start = 1
    scene.frame_end = IMAGES
    scene.render.image_settings.file_format = "PNG"

    monde = bpy.data.worlds.new("nuit")
    monde.use_nodes = True
    monde.node_tree.nodes["Background"].inputs["Color"].default_value = (0.004, 0.010, 0.030, 1.0)
    scene.world = monde

    try:
        scene.view_settings.view_transform = "AgX"
    except TypeError:
        pass

    scene.use_nodes = True
    arbre = scene.node_tree
    arbre.nodes.clear()
    entree = arbre.nodes.new("CompositorNodeRLayers")
    halo = arbre.nodes.new("CompositorNodeGlare")
    halo.glare_type = "FOG_GLOW"
    halo.quality = "MEDIUM"
    halo.size = 8
    sortie = arbre.nodes.new("CompositorNodeComposite")
    arbre.links.new(entree.outputs["Image"], halo.inputs["Image"])
    arbre.links.new(halo.outputs["Image"], sortie.inputs["Image"])


def regler_cycles():
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    prefs = bpy.context.preferences.addons["cycles"].preferences
    prefs.compute_device_type = "OPTIX"
    prefs.get_devices()
    for appareil in prefs.devices:
        appareil.use = (appareil.type == "OPTIX")
    scene.cycles.device = "GPU"
    scene.cycles.samples = 64
    scene.cycles.use_denoising = True
    scene.cycles.denoiser = "OPTIX"
    scene.cycles.volume_max_steps = 128


def regler_eevee():
    scene = bpy.context.scene
    # EEVEE Next depuis Blender 4.2 ; on retombe sur l'ancien nom si besoin.
    for moteur in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
        try:
            scene.render.engine = moteur
            break
        except TypeError:
            continue

    e = scene.eevee
    # Les volumetriques d'EEVEE se reglent explicitement : par defaut la
    # resolution est trop grossiere pour une colonne de feu.
    for attribut, valeur in (
        ("taa_render_samples", 64),
        ("use_volumetric_shadows", True),
        ("volumetric_tile_size", "4"),
        ("volumetric_samples", 128),
        ("use_bloom", True),
        ("use_gtao", True),
    ):
        if hasattr(e, attribut):
            try:
                setattr(e, attribut, valeur)
            except TypeError:
                pass
    return scene.render.engine


def mesurer(nom_moteur, dossier):
    """La PREMIERE image d'EEVEE paie la compilation des shaders -- une vingtaine
    de secondes qui ne se represente jamais. La mesurer avec les autres
    fausserait la comparaison du simple au double : on la sort du calcul."""
    scene = bpy.context.scene
    scene.render.filepath = f"{dossier}/{nom_moteur}_"

    scene.frame_start = scene.frame_end = 1
    debut_amorce = time.time()
    bpy.ops.render.render(animation=True)
    amorce = time.time() - debut_amorce

    scene.frame_start, scene.frame_end = 2, IMAGES
    debut = time.time()
    bpy.ops.render.render(animation=True)
    total = time.time() - debut
    par_image = total / max(IMAGES - 1, 1)

    print(f"BANC {nom_moteur} amorce={amorce:.1f}s regime={total:.1f}s "
          f"par_image={par_image:.2f}s", flush=True)
    scene.frame_start, scene.frame_end = 1, IMAGES
    return par_image


def main():
    nettoyer()
    vegetation()
    feu_volumetrique()
    camera()
    commun()

    os.makedirs(SORTIE, exist_ok=True)
    moteurs = os.environ.get("BANC_MOTEURS", "cycles,eevee").split(",")
    resultats = {}

    if "cycles" in moteurs:
        regler_cycles()
        resultats["cycles"] = mesurer("cycles", SORTIE)

    if "eevee" in moteurs:
        # EEVEE Next exige libEGL pour rendre sans ecran. Sans elle, Blender
        # meurt sur « Couldn't open libEGL.so.1 » -- et comme les `print` de
        # Blender sont bufferises quand la sortie est un tube, TOUT le journal
        # part avec, y compris les mesures deja faites. Piege coûteux.
        regler_eevee()
        resultats["eevee"] = mesurer("eevee", SORTIE)

    print("BANC_RESULTAT " + " ".join(f"{n}={v:.2f}s" for n, v in resultats.items()), flush=True)
    if len(resultats) == 2:
        print(f"BANC_RAPPORT {resultats['cycles'] / resultats['eevee']:.1f}x", flush=True)
    # 4200 images = la video de reference (140 s a 30 i/s), a 0,44 $/h.
    for nom, valeur in resultats.items():
        print(f"BANC_COUT_4200 {nom}={valeur * 4200 / 3600 * 0.44:.2f}USD", flush=True)


main()

# Capsule pilote « Orientation » — Studio visuel Academia.
#
# Livrable de la phase 1 du cahier des charges : une capsule verticale courte,
# en 3D procedurale, respectant la grammaire visuelle retenue.
#
#   Fond        : bleu nuit tres sombre
#   Matiere     : reseau filaire, noeuds lumineux, pas de photorealisme
#   Couleurs    : cyan/bleu pour les structures neutres, orange pour l'action
#   Camera      : travelling lent et rotation limitee, aucune coupe
#   Format      : 1080 x 1920 (9:16)
#
# CE QUE LA SCENE RACONTE. Un nuage de noeuds relies : l'ensemble des filieres.
# Puis un chemin s'allume en orange, de proche en proche : trouver sa voie n'est
# pas choisir un point au hasard, c'est suivre une suite d'etapes reliees.
#
# ECONOMIE. 64 echantillons + debruitage OptiX = ~1 s par image sur A40. Ce
# reglage n'est pas un detail : a 256 echantillons sur une scene chargee, la
# meme duree de video coute 14 fois plus cher. Le style filaire n'est pas
# seulement une esthetique, c'est ce qui rend le dispositif viable.
#
# Usage : blender -b --python capsule_orientation.py

import bpy
import math
import random

# ── Parametres ────────────────────────────────────────────────────────────
FPS = 25
DUREE_S = 20
IMAGES = FPS * DUREE_S
NB_NOEUDS = 44
DISTANCE_LIEN = 2.6          # deux noeuds plus proches que ca sont relies
CHEMIN = 7                   # nombre d'etapes du parcours mis en avant
SORTIE = "/workspace/pilote/frames/f_"

CYAN = (0.15, 0.62, 1.0, 1.0)
ORANGE = (1.0, 0.36, 0.09, 1.0)

random.seed(7)


def nettoyer():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    for bloc in (bpy.data.meshes, bpy.data.materials, bpy.data.curves):
        for item in list(bloc):
            if item.users == 0:
                bloc.remove(item)


def matiere_emissive(nom, couleur, force):
    """Une matiere purement emissive : c'est elle qui donne l'aspect « lumiere
    dans le noir » sans avoir a eclairer la scene, donc sans cout de calcul."""
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


def construire_reseau():
    """Le nuage de noeuds et leurs liens, en une seule maille : un objet plutot
    que plusieurs centaines, ce qui allege le rendu."""
    points = []
    for _ in range(NB_NOEUDS):
        points.append((
            random.uniform(-3.2, 3.2),
            random.uniform(-3.2, 3.2),
            random.uniform(-4.5, 4.5),
        ))

    aretes = []
    for i in range(len(points)):
        for j in range(i + 1, len(points)):
            d = math.dist(points[i], points[j])
            if d < DISTANCE_LIEN:
                aretes.append((i, j))

    maille = bpy.data.meshes.new("reseau")
    maille.from_pydata(points, aretes, [])
    maille.update()
    objet = bpy.data.objects.new("reseau", maille)
    bpy.context.collection.objects.link(objet)

    # Le modificateur Wireframe transforme les aretes en tubes fins : c'est ce
    # qui donne la matiere « filaire » sans modeliser chaque lien.
    fil = objet.modifiers.new("fil", "WIREFRAME")
    fil.thickness = 0.012
    objet.data.materials.append(matiere_emissive("lien", CYAN, 1.2))
    return points


def poser_noeuds(points, chemin):
    """Une petite sphere a chaque noeud. Celles du chemin recoivent leur propre
    matiere, car leur intensite est animee individuellement."""
    objets = []
    mat_repos = matiere_emissive("noeud", CYAN, 3.0)

    for indice, p in enumerate(points):
        bpy.ops.mesh.primitive_ico_sphere_add(radius=0.075, subdivisions=2, location=p)
        sphere = bpy.context.object
        sphere.data.materials.append(mat_repos)
        objets.append(sphere)

    for rang, indice in enumerate(chemin):
        sphere = objets[indice]
        sphere.data.materials.clear()
        mat = matiere_emissive(f"etape_{rang}", ORANGE, 3.0)
        sphere.data.materials.append(mat)
        sphere.scale = (1.9, 1.9, 1.9)

        # Chaque etape s'allume a son tour, etalees sur les deux premiers tiers
        # de la capsule : le regard suit le parcours au lieu de tout recevoir
        # d'un coup.
        debut = int(IMAGES * 0.12) + rang * int(IMAGES * 0.62 / CHEMIN)
        force = mat.node_tree.nodes["Emission"].inputs["Strength"]
        force.default_value = 0.6
        force.keyframe_insert("default_value", frame=debut)
        force.default_value = 26.0
        force.keyframe_insert("default_value", frame=debut + int(FPS * 0.5))
        force.default_value = 14.0
        force.keyframe_insert("default_value", frame=debut + int(FPS * 1.4))


def choisir_chemin(points):
    """Un parcours de proche en proche : a chaque etape, le voisin le plus
    proche pas encore visite. Un chemin qui saute d'un bout a l'autre ne
    raconterait rien."""
    courant = min(range(len(points)), key=lambda i: points[i][2])
    chemin = [courant]
    while len(chemin) < CHEMIN:
        restants = [i for i in range(len(points)) if i not in chemin]
        suivant = min(restants, key=lambda i: math.dist(points[courant], points[i]))
        chemin.append(suivant)
        courant = suivant
    return chemin


def poser_camera():
    """Travelling lent et rotation limitee : la camera monte legerement en
    tournant, sans jamais couper. C'est la regle « maintenir l'attention sans
    creer de confusion »."""
    cible = bpy.data.objects.new("cible", None)
    bpy.context.collection.objects.link(cible)
    cible.location = (0, 0, 0)

    bpy.ops.object.camera_add(location=(9.5, -9.5, -3.0))
    camera = bpy.context.object
    camera.data.lens = 42

    suivi = camera.constraints.new("TRACK_TO")
    suivi.target = cible
    suivi.track_axis = "TRACK_NEGATIVE_Z"
    suivi.up_axis = "UP_Y"

    rayon = 13.0
    for image in range(1, IMAGES + 1):
        t = (image - 1) / (IMAGES - 1)
        angle = math.radians(-38 + 26 * t)      # rotation limitee
        camera.location = (
            rayon * math.cos(angle),
            rayon * math.sin(angle),
            -3.2 + 6.4 * t,                     # montee continue
        )
        camera.keyframe_insert("location", frame=image)

    for fcourbe in camera.animation_data.action.fcurves:
        for point in fcourbe.keyframe_points:
            point.interpolation = "LINEAR"      # vitesse constante, pas d'a-coup

    bpy.context.scene.camera = camera


def reglages_rendu():
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
    scene.cycles.max_bounces = 2          # scene emissive : les rebonds ne servent a rien

    scene.render.resolution_x = 1080
    scene.render.resolution_y = 1920
    scene.render.fps = FPS
    scene.frame_start = 1
    scene.frame_end = IMAGES
    scene.render.filepath = SORTIE
    scene.render.image_settings.file_format = "PNG"

    # Fond bleu nuit, presque noir : c'est lui qui fait ressortir les lumieres.
    monde = bpy.data.worlds.new("nuit")
    monde.use_nodes = True
    monde.node_tree.nodes["Background"].inputs["Color"].default_value = (0.006, 0.014, 0.035, 1.0)
    scene.world = monde

    # Halos : le « premium » du cahier des charges tient beaucoup a ca, et ca
    # se calcule au compositing, donc pour presque rien.
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


def main():
    nettoyer()
    points = construire_reseau()
    chemin = choisir_chemin(points)
    poser_noeuds(points, chemin)
    poser_camera()
    reglages_rendu()
    print(f"SCENE_PRETE noeuds={len(points)} chemin={chemin} images={IMAGES}")
    bpy.ops.render.render(animation=True)
    print("RENDU_TERMINE")


main()

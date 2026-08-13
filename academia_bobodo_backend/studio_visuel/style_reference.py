# Grammaire visuelle du Studio Academia — reglages tires de l'analyse image par
# image de la video de reference fournie le 30/07.
#
# CE MODULE N'EST PAS UNE SCENE, c'est le style. Les scenes l'importent pour
# que toutes les capsules se ressemblent -- c'est ce que le cahier des charges
# appelle « grammaire visuelle constante d'un episode a l'autre ».
#
# LES CINQ ECARTS CORRIGES par rapport au premier brouillon :
#   1. la densite du volume est pilotee par une texture de bruit ANIMEE, sans
#      quoi le feu est une boite ;
#   2. la couleur d'emission suit la densite -- rouge sombre aux bords, orange,
#      blanc au coeur -- au lieu d'une teinte plate ;
#   3. les intensites sont divisees : sur la reference l'ecran reste
#      majoritairement NOIR et seuls quelques elements brillent. C'est le
#      rapport qui fait le premium, pas l'intensite absolue ;
#   4. le sol n'emet plus : il noyait l'image ;
#   5. cadrage cinema (bandes noires) et sujet plus petit dans le cadre.

import math
import os
import random

import bpy

# Deux teintes, jamais trois. C'est la discipline la plus visible de la
# reference et la moins couteuse a tenir.
BLEU_FROID = (0.05, 0.28, 0.95, 1.0)
BLEU_SOMBRE = (0.010, 0.035, 0.14, 1.0)
ROUGE = (1.0, 0.06, 0.01, 1.0)
ORANGE = (1.0, 0.32, 0.04, 1.0)
COEUR = (1.0, 0.78, 0.45, 1.0)
FOND = (0.0015, 0.0045, 0.014, 1.0)   # presque noir, legerement bleu


def _arbre_vierge(materiau):
    materiau.use_nodes = True
    arbre = materiau.node_tree
    arbre.nodes.clear()
    return arbre


def filaire(objet, epaisseur=0.012):
    """Transforme les aretes d'une maille en tubes visibles.

    LE PIEGE. Le modificateur Wireframe travaille sur les FACES : il epaissit
    le contour des polygones. Sur une geometrie qui n'a QUE des aretes -- un
    reseau de noeuds, un cercle, un rail -- il ne produit rien du tout, et
    surtout il ne produit rien EN SILENCE. Aucune erreur, juste un objet
    invisible.

    Un seul defaut expliquait trois symptomes : reseau sans liens, rail
    invisible, et strates entierement noires.

    La conversion en courbe avec un biseau est la seule methode fiable sur de
    la geometrie purement filaire.

    LE SECOND PIEGE, ET IL ETAIT PLUS COUTEUX QUE LE PREMIER.
    `bpy.ops.object.convert(target="CURVE")` fabrique une courbe NEUVE et la
    substitue a la maille : la nouvelle donnee n'a AUCUN emplacement de
    matiere. La matiere emissive posee juste avant sur la maille reste
    attachee a une donnee que plus rien ne rend.

    Mesure du 06/08, Blender 4.5.9, sur les deux geometries du studio :

        geometrie              materiaux AVANT   APRES   points   rendu
        chaine (degre max 2)          1            0       12    3,35/255
        graphe dense (degre 11)       1            0       59    3,28/255

    La geometrie survit parfaitement -- 59 points pour le graphe dense. Seule
    la matiere disparait. L'objet est alors rendu avec la surface grise par
    defaut de Blender ; or il n'existe AUCUNE lampe dans tout le studio (le
    style veut que les objets s'eclairent eux-memes) et le monde est quasi
    noir. Un tube gris sur fond noir, c'est du noir.

    Un seul defaut expliquait donc quatre symptomes de plus : `comparaison` et
    `strates` entierement noirs, les reseaux sans liens, le rail invisible.
    Et il explique pourquoi le correctif « emission x3 » du 04/08 n'a rien
    change : il augmentait une emission qui n'etait plus reliee a rien.

    On repose donc les matieres apres la conversion, et on ECHOUE BRUYAMMENT
    si elles n'ont pas pu l'etre -- c'est precisement le silence qui a coute
    trois rendus.
    """
    # Capturees AVANT : apres la conversion, `objet.data` est une autre donnee.
    materiaux = [m for m in objet.data.materials]

    bpy.context.view_layer.objects.active = objet
    bpy.ops.object.select_all(action="DESELECT")
    objet.select_set(True)
    bpy.ops.object.convert(target="CURVE")

    if objet.type != "CURVE":
        raise RuntimeError(f"filaire: {objet.name} n'a pas ete converti en courbe")

    courbe = objet.data
    courbe.bevel_depth = epaisseur
    courbe.bevel_resolution = 1      # 1 suffit a cette echelle, et coute moitie moins
    courbe.fill_mode = "FULL"

    if not [m for m in courbe.materials if m]:
        for matiere in materiaux:
            courbe.materials.append(matiere)

    if materiaux and not [m for m in courbe.materials if m]:
        raise RuntimeError(
            f"filaire: {objet.name} a perdu sa matiere a la conversion — "
            f"il rendrait en gris sur fond noir, donc invisible")

    return objet


def matiere_emissive(nom, couleur, force):
    """Emission pure. Aucune lumiere dans la scene : ce sont les objets qui
    eclairent. C'est ce qui rend le style peu couteux -- rien a tracer."""
    mat = bpy.data.materials.new(nom)
    arbre = _arbre_vierge(mat)
    emission = arbre.nodes.new("ShaderNodeEmission")
    emission.inputs["Color"].default_value = couleur
    emission.inputs["Strength"].default_value = force
    sortie = arbre.nodes.new("ShaderNodeOutputMaterial")
    arbre.links.new(emission.outputs["Emission"], sortie.inputs["Surface"])
    return mat


def matiere_hologramme(nom, couleur=BLEU_FROID, force=6.0, densite_bord=1.6):
    """La matiere qui fait « hologramme » : transparente de face, lumineuse sur
    les bords.

    C'est LE traitement commun aux trois references analysees -- la silhouette
    humaine filaire, les chiffres translucides, les cadres de portes. Un nœud
    Fresnel mesure l'angle de vue : de face on voit a travers, en incidence
    rasante l'objet s'illumine. C'est ce qui donne le volume sans masquer ce
    qu'il y a derriere, et c'est exactement ce qu'il faut en pedagogie : on
    montre l'interieur sans couper l'objet.

    Fonctionne dans les deux moteurs. En EEVEE il faut en plus autoriser la
    transparence sur la matiere -- l'attribut a change de nom entre les
    versions, d'ou les essais successifs.
    """
    mat = bpy.data.materials.new(nom)
    arbre = _arbre_vierge(mat)
    liens = arbre.links

    fresnel = arbre.nodes.new("ShaderNodeFresnel")
    fresnel.inputs["IOR"].default_value = densite_bord

    emission = arbre.nodes.new("ShaderNodeEmission")
    emission.inputs["Color"].default_value = couleur
    emission.inputs["Strength"].default_value = force

    transparent = arbre.nodes.new("ShaderNodeBsdfTransparent")

    melange = arbre.nodes.new("ShaderNodeMixShader")
    liens.new(fresnel.outputs["Fac"], melange.inputs["Fac"])
    liens.new(transparent.outputs["BSDF"], melange.inputs[1])
    liens.new(emission.outputs["Emission"], melange.inputs[2])

    sortie = arbre.nodes.new("ShaderNodeOutputMaterial")
    liens.new(melange.outputs["Shader"], sortie.inputs["Surface"])

    # Sans ceci, EEVEE rend l'objet opaque et tout l'effet disparait.
    for attribut, valeurs in (
        ("surface_render_method", ("BLENDED",)),
        ("blend_method", ("HASHED", "BLEND")),
    ):
        if hasattr(mat, attribut):
            for valeur in valeurs:
                try:
                    setattr(mat, attribut, valeur)
                    break
                except TypeError:
                    continue
    mat.use_backface_culling = False
    return mat


def texte_3d(contenu, taille=1.0, extrusion=0.06, position=(0, 0, 0), rotation=(0, 0, 0)):
    """Du texte comme geometrie lumineuse.

    C'EST LA BRIQUE QUI REND LE STUDIO UNIVERSEL. On ne peut pas modeliser
    procedurallement un violon pour la musique ni une molecule pour la chimie
    -- mais on peut TOUJOURS rendre une formule, un mot, un chiffre, un
    symbole. Les references le montrent : « 0.999… » et « 1 » ne sont pas
    illustres, ils SONT les objets de la scene.

    Une seule brique couvre donc les mathematiques, la physique, la chimie, la
    litterature, la musique et l'architecture.
    """
    bpy.ops.object.text_add(location=position, rotation=rotation)
    objet = bpy.context.object
    donnees = objet.data
    donnees.body = str(contenu)
    donnees.size = taille
    donnees.extrude = extrusion
    donnees.bevel_depth = extrusion * 0.15
    donnees.bevel_resolution = 1
    donnees.align_x = "CENTER"
    donnees.align_y = "CENTER"

    # DejaVu est installee par install_pod.sh. La police par defaut de Blender
    # rend mal les accents francais -- « é », « à », « ç » -- ce qui serait
    # visible sur chaque capsule.
    for chemin in ("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
                   "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"):
        if os.path.isfile(chemin):
            try:
                donnees.font = bpy.data.fonts.load(chemin)
                break
            except Exception:  # noqa: BLE001
                pass
    return objet


def mesurer(objet):
    """Dimensions REELLES d'un objet, apres evaluation du graphe.

    `objet.dimensions` vaut zero tant que le graphe de dependances n'a pas ete
    evalue : lu juste apres la creation, il ment. C'est ce qui a permis de
    placer deux textes a un ecart FIXE sans jamais s'apercevoir qu'ils se
    chevauchaient des que l'un d'eux etait long.
    """
    bpy.context.view_layer.update()
    return tuple(objet.dimensions)


def tenir_dans(objet, largeur_max):
    """Reduit la taille d'un texte jusqu'a ce qu'il tienne dans la largeur.

    C'est la condition de l'universalite promise : « 100 m » et « la
    stratigraphie archeologique » doivent tous deux passer, sans qu'un
    redacteur ait a compter ses caracteres.
    """
    largeur = mesurer(objet)[0]
    if largeur > largeur_max > 0:
        objet.data.size *= largeur_max / largeur
        largeur = mesurer(objet)[0]
    return largeur


def sol_grille(cote=26.0, pas=52, amplitude=0.55, graine=3):
    """Le sol quadrille et ondule, present dans presque toutes les references.

    Il donne l'echelle et l'horizon. Sans lui, un objet flotte dans le vide et
    l'oeil n'a aucun repere -- c'est ce qui separe une image « 3D » d'une image
    « cinema ».

    Le relief est calcule en Python plutot que par un modificateur : c'est
    deterministe, donc la meme capsule rendue deux fois donne exactement la
    meme image.
    """
    alea = random.Random(graine)
    phase_x = alea.uniform(0, 6.28)
    phase_y = alea.uniform(0, 6.28)

    points = []
    for iy in range(pas + 1):
        for ix in range(pas + 1):
            x = -cote / 2 + cote * ix / pas
            y = -cote / 2 + cote * iy / pas
            z = (math.sin(x * 0.42 + phase_x) * math.cos(y * 0.37 + phase_y)) * amplitude
            points.append((x, y, z))

    aretes = []
    largeur = pas + 1
    for iy in range(largeur):
        for ix in range(largeur):
            indice = iy * largeur + ix
            if ix < pas:
                aretes.append((indice, indice + 1))
            if iy < pas:
                aretes.append((indice, indice + largeur))

    maille = bpy.data.meshes.new("sol_grille")
    maille.from_pydata(points, aretes, [])
    maille.update()
    objet = bpy.data.objects.new("sol_grille", maille)
    bpy.context.collection.objects.link(objet)
    return objet


def ondes(nombre=14, rayon_max=11.0, hauteur=0.0):
    """Cercles concentriques : la propagation, l'onde, le champ, l'influence.

    Present tel quel dans la troisieme reference. Sert a montrer ce qui se
    diffuse -- un son, une chaleur, une idee, une reputation.
    """
    cercles = []
    for indice in range(nombre):
        rayon = rayon_max * (indice + 1) / nombre
        bpy.ops.mesh.primitive_circle_add(vertices=96, radius=rayon,
                                          location=(0, 0, hauteur))
        cercles.append(bpy.context.object)
    return cercles


def matiere_sol(nom="sol"):
    """Presque noir et NON emissif. Dans le brouillon il emettait, et il
    remplissait les deux tiers de l'image d'un bleu laiteux."""
    mat = bpy.data.materials.new(nom)
    arbre = _arbre_vierge(mat)
    principled = arbre.nodes.new("ShaderNodeBsdfPrincipled")
    principled.inputs["Base Color"].default_value = BLEU_SOMBRE
    principled.inputs["Roughness"].default_value = 0.95
    sortie = arbre.nodes.new("ShaderNodeOutputMaterial")
    arbre.links.new(principled.outputs["BSDF"], sortie.inputs["Surface"])
    return mat


def matiere_feu(nom="feu", echelle_bruit=9.0, densite=7.0, force=3.0):
    """Le volume turbulent.

    La densite vient d'un bruit 4D dont la dimension W est animee : c'est ce
    qui fait vivre la flamme sans aucune simulation physique -- donc sans le
    cout d'une simulation. Le meme bruit pilote la couleur, du rouge sombre au
    coeur clair, ce qui donne la profondeur qu'une teinte plate n'a jamais.
    """
    mat = bpy.data.materials.new(nom)
    arbre = _arbre_vierge(mat)
    liens = arbre.links

    coord = arbre.nodes.new("ShaderNodeTexCoord")
    mapping = arbre.nodes.new("ShaderNodeMapping")
    liens.new(coord.outputs["Object"], mapping.inputs["Vector"])

    bruit = arbre.nodes.new("ShaderNodeTexNoise")
    bruit.noise_dimensions = "4D"
    bruit.inputs["Scale"].default_value = echelle_bruit
    bruit.inputs["Detail"].default_value = 9.0
    bruit.inputs["Roughness"].default_value = 0.62
    liens.new(mapping.outputs["Vector"], bruit.inputs["Vector"])

    # Resserre le bruit, mais SANS l'ecraser : une plage trop etroite renvoie
    # 1 partout et le volume redevient un bloc plein. C'est l'erreur du premier
    # essai.
    contraste = arbre.nodes.new("ShaderNodeValToRGB")
    contraste.color_ramp.elements[0].position = 0.30
    contraste.color_ramp.elements[1].position = 0.88
    liens.new(bruit.outputs["Fac"], contraste.inputs["Fac"])

    separer = arbre.nodes.new("ShaderNodeSeparateXYZ")
    liens.new(coord.outputs["Object"], separer.inputs["Vector"])

    # Attenuation VERTICALE : la flamme se dissipe en montant.
    fondu = arbre.nodes.new("ShaderNodeMapRange")
    fondu.inputs["From Min"].default_value = 1.0
    fondu.inputs["From Max"].default_value = -1.0
    fondu.inputs["To Min"].default_value = 0.0
    fondu.inputs["To Max"].default_value = 1.0
    liens.new(separer.outputs["Z"], fondu.inputs["Value"])

    # Attenuation RADIALE : sans elle, le volume garde les faces verticales du
    # cube -- c'est ce qui faisait lire « boite » malgre le bruit. La flamme
    # doit s'eteindre en s'eloignant de son axe, dans toutes les directions.
    rayon = arbre.nodes.new("ShaderNodeVectorMath")
    rayon.operation = "LENGTH"
    aplati = arbre.nodes.new("ShaderNodeCombineXYZ")
    liens.new(separer.outputs["X"], aplati.inputs["X"])
    liens.new(separer.outputs["Y"], aplati.inputs["Y"])
    liens.new(aplati.outputs["Vector"], rayon.inputs[0])

    # L'attenuation commence des le centre et va jusqu'au bord : une plage
    # courte laisse une zone pleine au milieu, et c'est elle qu'on lit comme
    # une « boite ». Il faut degrader sur tout le rayon.
    bord = arbre.nodes.new("ShaderNodeMapRange")
    bord.inputs["From Min"].default_value = 0.62
    bord.inputs["From Max"].default_value = 0.0
    bord.inputs["To Min"].default_value = 0.0
    bord.inputs["To Max"].default_value = 1.0
    liens.new(rayon.outputs["Value"], bord.inputs["Value"])

    produit = arbre.nodes.new("ShaderNodeMath")
    produit.operation = "MULTIPLY"
    liens.new(fondu.outputs["Result"], produit.inputs[0])
    liens.new(bord.outputs["Result"], produit.inputs[1])

    # Eleve au carre : un degrade lineaire garde un bord franc a l'oeil, alors
    # qu'une courbe s'eteint doucement. C'est ce qui efface les dernieres
    # aretes du cube.
    enveloppe = arbre.nodes.new("ShaderNodeMath")
    enveloppe.operation = "POWER"
    enveloppe.inputs[1].default_value = 1.7
    liens.new(produit.outputs["Value"], enveloppe.inputs[0])

    masque = arbre.nodes.new("ShaderNodeMath")
    masque.operation = "MULTIPLY"
    liens.new(contraste.outputs["Color"], masque.inputs[0])
    liens.new(enveloppe.outputs["Value"], masque.inputs[1])

    force_densite = arbre.nodes.new("ShaderNodeMath")
    force_densite.operation = "MULTIPLY"
    force_densite.inputs[1].default_value = densite
    liens.new(masque.outputs["Value"], force_densite.inputs[0])

    # Couleur pilotee par la meme densite : bords rouges, coeur clair.
    teintes = arbre.nodes.new("ShaderNodeValToRGB")
    teintes.color_ramp.elements[0].position = 0.0
    teintes.color_ramp.elements[0].color = ROUGE
    teintes.color_ramp.elements[1].position = 0.75
    teintes.color_ramp.elements[1].color = COEUR
    milieu = teintes.color_ramp.elements.new(0.38)
    milieu.color = ORANGE
    liens.new(masque.outputs["Value"], teintes.inputs["Fac"])

    # LE PIEGE QUI A COUTE TROIS RENDUS. Dans le Principled Volume, l'emission
    # n'est PAS multipliee par la densite : elle remplit uniformement tout le
    # volume englobant. Une flamme dont seule la densite est bruitee emet donc
    # un bloc plein, et l'emission noie la turbulence qui, elle, fonctionnait
    # parfaitement. Il faut piloter l'emission par le MEME masque.
    force_emission = arbre.nodes.new("ShaderNodeMath")
    force_emission.operation = "MULTIPLY"
    force_emission.inputs[1].default_value = force
    liens.new(masque.outputs["Value"], force_emission.inputs[0])

    volume = arbre.nodes.new("ShaderNodeVolumePrincipled")
    liens.new(force_emission.outputs["Value"], volume.inputs["Emission Strength"])
    liens.new(force_densite.outputs["Value"], volume.inputs["Density"])
    liens.new(teintes.outputs["Color"], volume.inputs["Emission Color"])
    liens.new(teintes.outputs["Color"], volume.inputs["Color"])

    sortie = arbre.nodes.new("ShaderNodeOutputMaterial")
    liens.new(volume.outputs["Volume"], sortie.inputs["Volume"])

    # Anime la 4e dimension du bruit : la flamme bouge sans simulation.
    w = bruit.inputs["W"]
    w.default_value = 0.0
    w.keyframe_insert("default_value", frame=1)
    w.default_value = 6.0
    w.keyframe_insert("default_value", frame=250)
    if mat.node_tree.animation_data:
        for courbe in mat.node_tree.animation_data.action.fcurves:
            for point in courbe.keyframe_points:
                point.interpolation = "LINEAR"
    return mat


def matiere_brume(nom="brume", densite=0.006):
    """Diffusion d'ambiance. C'est elle qui fait « cinema » plutot que
    « schema ». Densite volontairement faible : au-dela, elle blanchit tout."""
    mat = bpy.data.materials.new(nom)
    arbre = _arbre_vierge(mat)
    diffusion = arbre.nodes.new("ShaderNodeVolumeScatter")
    diffusion.inputs["Color"].default_value = BLEU_FROID
    diffusion.inputs["Density"].default_value = densite
    sortie = arbre.nodes.new("ShaderNodeOutputMaterial")
    arbre.links.new(diffusion.outputs["Volume"], sortie.inputs["Volume"])
    return mat


def atmosphere(distance, densite=None):
    """Enveloppe la scene de brume volumetrique. Rend l'objet, ou None.

    POURQUOI CETTE FONCTION EXISTE ALORS QUE `matiere_brume` EXISTAIT DEJA.
    Relevé du 11/08 : `matiere_brume` et `matiere_feu` sont ecrites, abouties,
    et appelees par AUCUN archetype de production -- seulement par
    `essai_style.py`. Le brouillard volumetrique, qui est l'un des dix elements
    de la grammaire de reference et l'un des trois qui font « cinema » plutot
    que « schema », n'a donc jamais ete rendu dans une seule capsule livree.
    Le moteur payait meme le reglage sans en tirer l'image : `moteur_eevee`
    pose `volumetric_samples = 96` depuis toujours.

    LA TAILLE EST CALCULEE, PAS FIXEE. Un volume ne se rend que si la camera
    est DEDANS. `_camera` s'eloigne jusqu'a 1,25 x distance selon le mouvement,
    et monte jusqu'a +8,5 en « montee ». Le cube doit donc envelopper la course
    entiere de la camera, pas seulement le sujet : d'ou le facteur 3,4 (demi-
    cote 1,7 x distance) et le decentrage vertical.

    DESACTIVEE PAR DEFAUT DEPUIS LA MESURE DU 11/08. Elle ne s'allume qu'avec
    `STUDIO_BRUME=1`, et voici pourquoi -- banc A40, `reseau`, 1080x1920,
    64 echantillons, 60 images, deux passages dont seule cette variable change :

        sans brume   2,185 s/image   (P95 2,413)   projection 2500 images :  91,0 min
        avec brume   2,982 s/image   (P95 3,258)   projection 2500 images : 124,3 min

    Soit **+36,5 % de temps de rendu, +33 minutes par capsule**. Et les deux
    images temoins sont INDISCERNABLES a l'oeil.

    POURQUOI ELLE NE SE VOIT PAS -- hypothese fondee sur le code, NON MESUREE.
    `matiere_brume` est un `VolumeScatter` : il DIFFUSE de la lumiere, il n'en
    emet pas. Or ce studio n'a aucune lampe -- « le style veut que les objets
    s'eclairent eux-memes », voir `filaire` -- et le monde vaut (0.0015, 0.0045,
    0.014), c'est-a-dire noir. Il n'y a donc quasiment rien a diffuser. Le
    brouillard de la reference, lui, est ECLAIRE : ses bandes ont une structure
    et une lueur.

    La rendre visible ne consiste donc pas a monter la densite mais a AJOUTER
    UNE SOURCE DE LUMIERE, ce qui change le parti pris du studio et couterait
    davantage, pas moins. A trancher avec le choix de moteur : un moteur temps
    reel rend ce brouillard pour presque rien.

    Le code reste : le jour ou il y a une lumiere, la fonction est prete.
    """
    if os.environ.get("STUDIO_BRUME", "0") != "1":
        return None

    if densite is None:
        try:
            densite = float(os.environ.get("STUDIO_BRUME_DENSITE") or 0.006)
        except ValueError:
            densite = 0.006

    cote = max(12.0, float(distance) * 3.4)
    bpy.ops.mesh.primitive_cube_add(size=cote, location=(0, 0, cote * 0.12))
    brume = bpy.context.object
    brume.name = "atmosphere"
    brume.data.materials.append(matiere_brume(densite=densite))
    # Le volume ne doit jamais masquer ni recevoir d'ombre : il habille, il ne
    # participe pas a la scene.
    brume.visible_shadow = False
    return brume


def monde_nuit(scene):
    monde = bpy.data.worlds.new("nuit")
    monde.use_nodes = True
    monde.node_tree.nodes["Background"].inputs["Color"].default_value = FOND
    scene.world = monde


def compositing(scene, taille_halo=7, exposition=-0.6):
    """Halos et etalonnage.

    Le pipeline professionnel fabrique la coherence au compositing, pas au
    rendu. Ici deux choses suffisent : un halo diffus, et une EXPOSITION
    NEGATIVE -- c'est elle qui ramene l'ecran vers le noir et fait ressortir
    les quelques elements lumineux. Le brouillon n'en avait pas, d'ou la
    surexposition generale.
    """
    try:
        scene.view_settings.view_transform = "AgX"
        scene.view_settings.look = "AgX - Medium High Contrast"
        scene.view_settings.exposure = exposition
    except TypeError:
        pass

    scene.use_nodes = True
    arbre = scene.node_tree
    arbre.nodes.clear()
    entree = arbre.nodes.new("CompositorNodeRLayers")
    halo = arbre.nodes.new("CompositorNodeGlare")
    halo.glare_type = "FOG_GLOW"
    halo.quality = "MEDIUM"
    halo.size = taille_halo
    sortie = arbre.nodes.new("CompositorNodeComposite")
    arbre.links.new(entree.outputs["Image"], halo.inputs["Image"])
    arbre.links.new(halo.outputs["Image"], sortie.inputs["Image"])


def cadre_cinema(scene, proportion=0.62):
    """Bandes noires haut et bas dans un format vertical.

    C'est un marqueur immediat de la reference, et il ne coute rien : on rend
    une bande centrale plus courte, ffmpeg complete en noir. On economise meme
    du calcul, puisqu'il y a moins de pixels a rendre.
    """
    scene.render.use_border = True
    scene.render.use_crop_to_border = False
    marge = (1.0 - proportion) / 2.0
    scene.render.border_min_y = marge
    scene.render.border_max_y = 1.0 - marge


def moteur_eevee(scene, echantillons=64, echantillons_volume=96):
    """EEVEE Next. Mesure a 2,51 s/image contre 6,00 s pour Cycles sur ce style.
    Exige libEGL pour rendre sans ecran -- voir install_pod.sh.

    STUDIO_ECHANTILLONS permet de baisser la qualite sans toucher au code.
    Ce n'est pas un confort : mesure du 06/08 sur une machine a 1 Go de VRAM,
    en 1080x1920,

        64 echantillons  33,48 s/image
        16 echantillons   1,66 s/image

    soit un facteur VINGT pour un facteur quatre d'echantillons -- la memoire
    decroche. Sur un GPU large le rapport reste lineaire, mais le reglage
    permet de rendre une capsule de controle en quatorze minutes sur une
    machine ordinaire, donc sans rien louer.
    """
    import os
    try:
        echantillons = int(os.environ.get("STUDIO_ECHANTILLONS") or echantillons)
    except ValueError:
        pass
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    e = scene.eevee
    for attribut, valeur in (
        ("taa_render_samples", echantillons),
        ("use_volumetric_shadows", True),
        ("volumetric_tile_size", "2"),
        ("volumetric_samples", echantillons_volume),
        ("use_gtao", True),
    ):
        if hasattr(e, attribut):
            try:
                setattr(e, attribut, valeur)
            except TypeError:
                pass


def moteur_cycles(scene, echantillons=64):
    scene.render.engine = "CYCLES"
    prefs = bpy.context.preferences.addons["cycles"].preferences
    prefs.compute_device_type = "OPTIX"
    prefs.get_devices()
    for appareil in prefs.devices:
        appareil.use = (appareil.type == "OPTIX")
    scene.cycles.device = "GPU"
    scene.cycles.samples = echantillons
    scene.cycles.use_denoising = True
    scene.cycles.denoiser = "OPTIX"

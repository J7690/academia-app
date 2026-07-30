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

    bord = arbre.nodes.new("ShaderNodeMapRange")
    bord.inputs["From Min"].default_value = 0.95
    bord.inputs["From Max"].default_value = 0.15
    bord.inputs["To Min"].default_value = 0.0
    bord.inputs["To Max"].default_value = 1.0
    liens.new(rayon.outputs["Value"], bord.inputs["Value"])

    enveloppe = arbre.nodes.new("ShaderNodeMath")
    enveloppe.operation = "MULTIPLY"
    liens.new(fondu.outputs["Result"], enveloppe.inputs[0])
    liens.new(bord.outputs["Result"], enveloppe.inputs[1])

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
    Exige libEGL pour rendre sans ecran -- voir install_pod.sh."""
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

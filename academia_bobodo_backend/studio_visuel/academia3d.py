"""academia3d — le vocabulaire que l'IA compose pour fabriquer une scene.

CE QUE C'EST, ET CE QUE CE N'EST PAS.
Ce n'est PAS un nouveau moteur. C'est une facade nommee au-dessus de
`style_reference.py`, qui porte deja la grammaire visuelle : le filaire bleu,
le verre translucide a bord dense, le volume incandescent, la brume, le halo,
le cadre vertical. Ces treize gestes existent depuis le 30/07 et ne changent pas.

CE QU'ELLE AJOUTE EST LE SEUL VRAI MANQUE : le SUJET.

Mesure du 07/08 sur deux capsules reelles : « la sociologie » et « la
germination » ont produit la MEME suite de formes. Sur les onze archetypes du
moteur, huit n'acceptent que des nombres -- `noeuds`, `couches`, `rayon`,
`points`. Un nombre de noeuds ne dit rien de la sociologie. Le style etait
correct ; c'est le sujet qui n'entrait nulle part.

D'OU LA DIFFERENCE AVEC UN CATALOGUE. Les archetypes se CHOISISSENT dans une
liste fermee ; ces verbes se COMPOSENT. La forme n'existe pas avant que le
programme l'ecrive : boucles, positions relatives, imbrication. C'est ce que
`3DCodeBench` (06/2026) mesure noir sur blanc -- deux reprises sur erreur font
+27,2 points d'executabilite et -0,010 de pertinence au sujet. La pertinence ne
vient jamais du retry : elle vient du vocabulaire.

PREMIERE LIVRAISON — les verbes que la DEUXIEME image de reference exige :
terrain en grille, lueur affleurant dessous, ovoides facettes translucides a
profondeurs echelonnees. Aucun d'eux ne demande de banque de maillages : un
ovoide se genere par equation. Le corps humain de la PREMIERE image, lui,
exigera `convoquer` et une banque -- on ne sort pas un corps allonge d'une
equation.

Usage : importe depuis un script Blender.
    import academia3d as a3
    sol = a3.napper(cote=190, pas=96)
    a3.filairer(sol)
    a3.affleurer(sol, chaleur=1.0)
"""

from __future__ import annotations

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402
import style_reference as style  # noqa: E402

# La palette ne se redefinit pas ici : deux teintes, jamais trois, et elles
# viennent de l'analyse image par image des references.
BLEU = style.BLEU_FROID
ROUGE = style.ROUGE
ORANGE = style.ORANGE


# ══ STRUCTURE — le connu, en bleu emissif ════════════════════════════════

def napper(cote: float = 190.0, pas: int = 96, amplitude: float = 2.6,
           graine: int = 3):
    """Le terrain en grille jusqu'a l'horizon.

    Enveloppe `style.sol_grille` en gardant ses equations : le relief est
    calcule en Python, donc la meme capsule rendue deux fois donne exactement
    la meme image. Un relief aleatoire a chaque rendu rendrait tout diagnostic
    visuel impossible.
    """
    return style.sol_grille(cote=cote, pas=pas, amplitude=amplitude, graine=graine)


def filairer(objet, epaisseur: float = 0.012, couleur=None, emission: float = 3.2,
             garder_surface: bool = False):
    """Transforme les aretes en tubes lumineux.

    DEUX TECHNIQUES, ET LE DEPOT DOCUMENTE DEJA LEURS DEUX ECHECS SYMETRIQUES.

      - `style.filaire` convertit la maille en COURBE avec un biseau. C'est la
        seule methode fiable sur une geometrie faite d'ARETES SEULES -- une
        grille, un reseau, un cercle. Sur une maille pleine, la conversion ne
        fait rien : Blender ne sait pas transformer un solide ferme en courbe.
      - Le modificateur Wireframe travaille sur les FACES. Sur une geometrie
        sans faces il ne produit rien, ET IL NE PRODUIT RIEN EN SILENCE : c'est
        ce defaut qui a coute trois rendus le 06/08 (reseau sans liens, rail
        invisible, strates entierement noires).

    Chacune echoue exactement la ou l'autre reussit. On choisit donc selon la
    geometrie, au lieu de parier. Mesure du 12/08 : sans ce choix, l'ovoide
    faisait lever `filaire: sculpte_ovoide_aretes n'a pas ete converti`.

    `garder_surface` traite une COPIE : l'oeuf de la reference a les deux, une
    peau translucide ET ses aretes soulignees. Un seul objet ne peut pas etre
    les deux -- la conversion en courbe detruirait la peau.
    """
    matiere = style.matiere_emissive(
        f"filaire_{objet.name}", couleur or BLEU, emission)

    if garder_surface:
        copie = objet.copy()
        copie.data = objet.data.copy()
        copie.name = f"{objet.name}_aretes"
        bpy.context.collection.objects.link(copie)
        cible = copie
    else:
        cible = objet

    cible.data.materials.clear()
    cible.data.materials.append(matiere)

    if len(cible.data.polygons) == 0:
        # Aretes seules : la conversion en courbe, avec son garde-fou.
        return style.filaire(cible, epaisseur=epaisseur)

    # Maille pleine : le modificateur Wireframe, qui epaissit le contour des
    # polygones. `use_replace` remplace la surface par ses aretes -- c'est bien
    # ce qu'on veut sur la COPIE, l'original gardant sa peau.
    bpy.context.view_layer.objects.active = cible
    mod = cible.modifiers.new("aretes", "WIREFRAME")
    # L'EPAISSEUR RECUE EST UNE LONGUEUR MONDE ; LE MODIFICATEUR TRAVAILLE EN
    # LOCAL. Sans conversion, l'echelle de l'objet remultiplie les tubes une
    # SECONDE fois : `sculpter` pose `objet.scale = base * echelle` (voir plus
    # bas) et personne ne fige la transformation, si bien qu'une epaisseur deja
    # proportionnelle a `echelle` ressortait en echelle^2.
    #
    # Consequence : a echelle 1,35 -- l'exemple meme de l'invite -- l'arete
    # etait 35 % trop epaisse ; a la borne haute acceptee, huit fois. La forme
    # restait juste, mais un gros objet ne ressemblait plus a un petit. C'est
    # exactement ce que `academia3d_style.py` existe pour empecher : le style
    # tient a des RAPPORTS constants, pas a des valeurs absolues.
    #
    # On divise par la plus grande composante : le tube est un scalaire, une
    # echelle anisotrope ne peut de toute facon pas etre rendue fidelement, et
    # sous-estimer l'epaisseur abime moins l'image que la surestimer.
    facteur = max(abs(cible.scale[0]), abs(cible.scale[1]), abs(cible.scale[2]))
    mod.thickness = epaisseur / facteur if facteur > 1e-6 else epaisseur
    mod.use_replace = True
    mod.use_even_offset = True
    mod.material_offset = 0
    bpy.ops.object.modifier_apply(modifier=mod.name)

    if len(cible.data.polygons) == 0:
        raise RuntimeError(
            f"filairer: {cible.name} n'a plus aucune face apres Wireframe — "
            f"il serait invisible")
    return cible


def vitrer(objet, couleur=None, force: float = 2.4, densite_bord: float = 1.6):
    """La peau translucide qui s'allume en incidence rasante.

    C'est le traitement commun a toutes les references : de face on voit au
    travers, de biais l'objet s'illumine. En pedagogie c'est exactement ce
    qu'il faut -- montrer l'interieur sans couper l'objet.
    """
    objet.data.materials.clear()
    objet.data.materials.append(
        style.matiere_hologramme(f"verre_{objet.name}", couleur or BLEU,
                                 force, densite_bord))
    return objet


# ══ SUJET — ce qui manquait, et qui porte toute la pertinence ════════════

# Les bases sculptables. Chacune est une EQUATION, pas un fichier : elle nous
# appartient sans discussion, elle est deterministe, et elle ne pese rien.
# C'est la doctrine de `contours/fabriquer_contours.py`, etendue a la 3D.
_BASES = {
    "ovoide":  dict(rayon=1.0, echelle=(0.78, 0.78, 1.0)),
    "sphere":  dict(rayon=1.0, echelle=(1.0, 1.0, 1.0)),
    "galet":   dict(rayon=1.0, echelle=(1.0, 0.72, 0.55)),
    "goutte":  dict(rayon=1.0, echelle=(0.7, 0.7, 1.35)),
    "lentille": dict(rayon=1.0, echelle=(1.0, 1.0, 0.32)),
}


def sculpter(base: str = "ovoide", facettes: int = 1, echelle: float = 1.0,
             position=(0.0, 0.0, 0.0), deformation: float = 0.0,
             graine: int = 0):
    """Fabrique un volume facette a partir d'une base geometrique.

    `facettes` est le nombre de subdivisions de l'icosphere : 1 donne les
    grandes faces triangulaires de la reference, 3 lisse trop et perd le
    caractere « low-poly » qui fait tout le style.

    `deformation` bouge chaque sommet le long de sa normale. A 0 la forme est
    parfaite -- donc morte. Un peu d'irregularite suffit a la rendre organique
    sans la rendre sale.
    """
    if base not in _BASES:
        base = "ovoide"
    reglage = _BASES[base]

    bpy.ops.mesh.primitive_ico_sphere_add(
        subdivisions=max(1, min(4, facettes)),
        radius=reglage["rayon"], location=position)
    objet = bpy.context.object
    objet.name = f"sculpte_{base}"

    ex, ey, ez = reglage["echelle"]
    objet.scale = (ex * echelle, ey * echelle, ez * echelle)

    if deformation > 0:
        alea = random.Random(graine)
        for sommet in objet.data.vertices:
            f = 1.0 + alea.uniform(-deformation, deformation)
            sommet.co = (sommet.co[0] * f, sommet.co[1] * f, sommet.co[2] * f)

    # Faces PLATES : c'est le facettage qui signe le style. Un ombrage lisse
    # ferait disparaitre les aretes que le filaire doit souligner.
    for face in objet.data.polygons:
        face.use_smooth = False
    return objet


def essaimer(fabriquer, nombre: int = 6, etendue: float = 22.0,
             profondeur=(-6.0, -46.0), altitudes=(2.2, 6.2),
             echelles=(1.5, 2.8), graine: int = 7):
    """Repartit N exemplaires a des profondeurs et tailles echelonnees.

    C'EST LA PROFONDEUR QUI FAIT L'IMAGE, pas le nombre. Sur la reference, les
    oeufs lointains sont petits ET flous ET pales : c'est cet echelonnement qui
    donne l'echelle et le volume. Les poser tous au meme plan donnerait un
    alignement decoratif, exactement le defaut qu'on corrige.

    `fabriquer` est appele pour CHAQUE exemplaire : c'est une boucle, pas une
    duplication. Une forme legerement differente a chaque fois, comme dans la
    nature -- et c'est ce qu'un catalogue de parametres ne sait pas exprimer.
    """
    # CONVENTION BLENDER : Z est la HAUTEUR, Y la PROFONDEUR. Premiere ecriture
    # de cette fonction : j'avais garde la convention de Three.js -- Y en
    # hauteur, Z en profondeur -- ecrite quelques heures plus tot le meme jour.
    # Les oeufs se seraient donc enfonces dans le sol au lieu de flotter.
    alea = random.Random(graine)
    produits = []
    for rang in range(nombre):
        t = rang / max(nombre - 1, 1)
        y = profondeur[0] + (profondeur[1] - profondeur[0]) * t   # profondeur
        x = alea.uniform(-etendue / 2, etendue / 2)
        z = alea.uniform(altitudes[0], altitudes[1])              # hauteur
        # Les lointains sont plus petits : la perspective seule ne suffit pas
        # a creer la sensation de profondeur dans un cadre vertical etroit.
        e = alea.uniform(*echelles) * (1.0 - 0.35 * t)
        produits.append(fabriquer(position=(x, y, z), echelle=e, graine=rang))
    return produits


def silhouetter(segments, rayons=None, lisser: int = 1, position=(0.0, 0.0, 0.0),
                nom: str = "silhouette"):
    """Construit un volume a partir d'un SQUELETTE de segments.

    C'EST LE VERBE QUI OUVRE LE PLUS DE SUJETS. Un corps, un membre, une tige,
    une racine, un vaisseau, un neurone, un fleuve, une chaine de montagnes :
    tous se decrivent comme une suite de points relies, avec une epaisseur qui
    varie. Le modificateur Skin fabrique le volume autour ; nous ne posons que
    la ligne.

    DEUX RAISONS DE PROCEDER AINSI PLUTOT QUE DE TELECHARGER UN MAILLAGE :

      1. Un squelette se decrit EN COORDONNEES, donc une IA peut l'ecrire. Un
         maillage, non : il faudrait qu'elle le choisisse dans une banque, et
         l'on retomberait sur un catalogue -- le defaut qu'on corrige.
      2. Il nous appartient sans discussion. C'est la doctrine de
         `contours/fabriquer_contours.py`, etendue a la 3D : « un contour
         recupere sur internet arrive avec sa licence, son auteur, et le doute
         qui va avec ».

    ET LA BARRE DE FIDELITE EST BASSE, ce qui rend l'approche viable : dans
    cette esthetique tout est filaire, facette et lumineux. Un corps allonge
    stylise n'a besoin d'aucune exactitude anatomique -- la reference du 11/08
    le montre.

    `segments` : liste de points (x, y, z). Les points consecutifs sont relies.
        Pour une branche, passer une liste de listes : chaque sous-liste repart
        du point le plus proche deja pose.
    `rayons` : epaisseur a chaque point. Un seul nombre s'applique partout.
        C'est la variation d'epaisseur qui donne la vie -- un membre s'affine,
        une racine aussi.
    """
    import bmesh  # local : n'existe que dans Blender

    chaines = segments if segments and isinstance(segments[0][0], (list, tuple)) \
        else [segments]

    if isinstance(rayons, (int, float)):
        plat = None
        rayon_uniforme = float(rayons)
    else:
        plat = list(rayons) if rayons else None
        rayon_uniforme = 0.35

    # UN POINT PARTAGE EST UN SEUL SOMMET, ET C'EST TOUT LE CORRECTIF.
    #
    # Premiere ecriture (12/08) : chaque chaine ajoutait ses propres sommets,
    # puis on reliait le premier au point deja pose le plus proche. Quand une
    # branche partait d'un point du tronc -- le cas normal, une epaule, une
    # hanche -- on creait donc un DOUBLON a la meme position, relie par une
    # arete de longueur NULLE. Le modificateur Skin ne sait pas epaissir une
    # arete nulle : les branches sortaient en lignes plates, sans volume, et
    # fuyaient hors cadre. Le tronc, lui, etait correct -- ce qui rendait le
    # defaut d'autant plus trompeur.
    #
    # On indexe donc les points par leur position : une branche qui repart d'un
    # point existant REUTILISE son sommet au lieu d'en creer un second.
    points: list[tuple] = []
    rayons_points: list[float] = []
    aretes: list[tuple] = []
    connu: dict = {}
    lu = 0

    def indice(p, r):
        cle = (round(float(p[0]), 4), round(float(p[1]), 4), round(float(p[2]), 4))
        if cle in connu:
            return connu[cle]
        connu[cle] = len(points)
        points.append((float(p[0]), float(p[1]), float(p[2])))
        rayons_points.append(r)
        return connu[cle]

    for chaine in chaines:
        precedent = None
        for p in chaine:
            r = float(plat[lu]) if plat and lu < len(plat) else rayon_uniforme
            lu += 1
            i = indice(p, r)
            if precedent is not None and precedent != i:
                aretes.append((precedent, i))
            precedent = i

    if not aretes:
        raise RuntimeError(
            f"silhouetter: {nom} n'a aucune arete — un squelette d'un seul "
            f"point ne peut pas produire de volume")

    maille = bpy.data.meshes.new(nom)
    maille.from_pydata(points, aretes, [])
    maille.update()
    objet = bpy.data.objects.new(nom, maille)
    bpy.context.collection.objects.link(objet)
    objet.location = position

    bpy.context.view_layer.objects.active = objet
    objet.select_set(True)
    peau = objet.modifiers.new("peau", "SKIN")
    peau.use_smooth_shade = False   # facettes : c'est le style

    # Les rayons. `skin_vertices` n'existe qu'APRES l'ajout du modificateur, et
    # il est indexe sur les sommets REELS -- ceux d'apres la fusion des
    # jonctions, pas ceux du squelette d'origine.
    couche = objet.data.skin_vertices[0].data
    for i, sommet in enumerate(couche):
        r = rayons_points[i] if i < len(rayons_points) else rayon_uniforme
        sommet.radius = (r, r)
    # UNE RACINE PAR MORCEAU, ET NON UNE SEULE POUR TOUT LE SQUELETTE.
    #
    # SANS RACINE, LE MODIFICATEUR NE PRODUIT RIEN -- et il ne produit rien en
    # silence. Meme classe de panne que le Wireframe sur une geometrie sans
    # faces (cf. `filairer`).
    #
    # Mesure du 12/08 : un squelette de corps dont les jambes partaient de
    # (0, 0, 0.1) alors que le tronc passait par (0, 0, 0). Les jambes
    # formaient donc un ILOT separe. Avec une seule racine posee sur le premier
    # sommet, le tronc et les bras sortaient en volume et les jambes en lignes
    # PLATES. L'image etait a moitie juste, ce qui est la pire des sorties :
    # elle donne l'illusion que le verbe fonctionne.
    #
    # Une IA qui ecrira des squelettes fera exactement cette erreur. On la
    # rattrape ici plutot que d'exiger des donnees parfaites.
    voisins: dict = {}
    for a, b in aretes:
        voisins.setdefault(a, set()).add(b)
        voisins.setdefault(b, set()).add(a)

    vus: set = set()
    morceaux = 0
    for depart in range(len(points)):
        if depart in vus:
            continue
        morceaux += 1
        pile, groupe = [depart], []
        while pile:
            n = pile.pop()
            if n in vus:
                continue
            vus.add(n)
            groupe.append(n)
            pile.extend(voisins.get(n, ()))
        if depart < len(couche):
            couche[depart].use_root = True

    if lisser > 0:
        doux = objet.modifiers.new("adoucir", "SUBSURF")
        doux.levels = doux.render_levels = max(1, min(2, lisser))

    for mod in list(objet.modifiers):
        bpy.ops.object.modifier_apply(modifier=mod.name)

    if len(objet.data.polygons) == 0:
        raise RuntimeError(
            f"silhouetter: {nom} n'a produit aucune face — squelette invalide "
            f"({len(points)} points, {len(aretes)} aretes)")
    return objet


def revolutionner(profil, tours: int = 48, position=(0.0, 0.0, 0.0),
                  nom: str = "revolution"):
    """Fait tourner un PROFIL autour de l'axe vertical.

    Un profil est une suite de couples (rayon, hauteur). En le faisant tourner,
    on obtient tout ce qui est de revolution : un vase, une colonne, un verre,
    un entonnoir, une fusee, une goutte, une cellule, une planete aplatie.

    C'est le deuxieme verbe qui se decrit entierement en nombres -- donc que
    l'IA peut ecrire sans rien choisir dans une liste.
    """
    points = [(float(r), 0.0, float(z)) for r, z in profil]
    aretes = [(i, i + 1) for i in range(len(points) - 1)]

    maille = bpy.data.meshes.new(nom)
    maille.from_pydata(points, aretes, [])
    maille.update()
    objet = bpy.data.objects.new(nom, maille)
    bpy.context.collection.objects.link(objet)
    objet.location = position

    bpy.context.view_layer.objects.active = objet
    objet.select_set(True)
    vis = objet.modifiers.new("revolution", "SCREW")
    vis.angle = math.radians(360.0)
    vis.axis = "Z"
    vis.steps = vis.render_steps = max(8, int(tours))
    vis.use_merge_vertices = True
    vis.use_normal_calculate = True
    bpy.ops.object.modifier_apply(modifier=vis.name)

    for face in objet.data.polygons:
        face.use_smooth = False

    if len(objet.data.polygons) == 0:
        raise RuntimeError(
            f"revolutionner: {nom} n'a produit aucune face — profil de "
            f"{len(points)} point(s), il en faut au moins deux")
    return objet


def extruder(contour, epaisseur: float = 0.25, position=(0.0, 0.0, 0.0),
             nom: str = "extrude"):
    """Pousse un CONTOUR 2D en epaisseur.

    Une lettre, un symbole, un pays, une piece, un logo, une section. C'est le
    verbe qui rejoint la brique dite universelle de `style_reference.texte_3d`,
    mais pour une forme quelconque plutot que pour du texte.

    `contour` : liste de couples (x, y), dans l'ordre, fermee implicitement.
    """
    points = [(float(x), float(y), 0.0) for x, y in contour]
    if len(points) < 3:
        raise RuntimeError(
            f"extruder: {nom} demande au moins trois points, {len(points)} recu(s)")

    maille = bpy.data.meshes.new(nom)
    maille.from_pydata(points, [], [list(range(len(points)))])
    maille.update()
    objet = bpy.data.objects.new(nom, maille)
    bpy.context.collection.objects.link(objet)
    objet.location = position

    bpy.context.view_layer.objects.active = objet
    objet.select_set(True)
    epais = objet.modifiers.new("epaisseur", "SOLIDIFY")
    epais.thickness = float(epaisseur)
    epais.offset = 0.0
    bpy.ops.object.modifier_apply(modifier=epais.name)

    for face in objet.data.polygons:
        face.use_smooth = False
    return objet


# ══ ENERGIE — le phenomene explique, en rouge-orange ═════════════════════

def affleurer(surface, chaleur: float = 1.0, dessous: float = 2.6,
             etendue: float = None):
    """Fait transparaitre une lueur SOUS une resille.

    Motif signature de la deuxieme reference : de la lave sous un grillage.
    C'est un plan emissif place sous la grille, dont l'intensite est modulee
    par un bruit et eteinte sur les bords -- sans cette extinction, on lit un
    rectangle lumineux et non une lueur.

    On n'utilise PAS `matiere_feu` ici : c'est un volume, il coute +36,5 % de
    temps de rendu (mesure du 11/08) et il ne se verrait pas davantage sous une
    grille. Une surface emissive suffit, et ne coute presque rien.
    """
    cote = etendue or max(surface.dimensions[0], 40.0)
    bpy.ops.mesh.primitive_plane_add(size=cote, location=(0, 0, -abs(dessous)))
    lueur = bpy.context.object
    lueur.name = "lueur_affleurante"

    mat = bpy.data.materials.new("affleurement")
    mat.use_nodes = True
    arbre = mat.node_tree
    arbre.nodes.clear()
    liens = arbre.links

    # COORDONNEES `Generated`, ET NON `Object`. Mesure du 12/08 : avec `Object`,
    # les coordonnees d'un plan de 220 unites vont de -110 a +110. L'extinction
    # des bords, reglee entre 0,15 et 0,55, eteignait donc TOUT le plan sauf un
    # disque d'un demi-unite au centre -- invisible a l'ecran. La lueur etait
    # calculee, rendue, et nulle part.
    # `Generated` rend 0..1 sur la boite englobante, quelle que soit la taille :
    # le reglage devient une PROPORTION, donc il vaut pour tous les plans.
    coord = arbre.nodes.new("ShaderNodeTexCoord")
    centre = arbre.nodes.new("ShaderNodeVectorMath")
    centre.operation = "SUBTRACT"
    centre.inputs[1].default_value = (0.5, 0.5, 0.0)
    liens.new(coord.outputs["Generated"], centre.inputs[0])

    bruit = arbre.nodes.new("ShaderNodeTexNoise")
    bruit.inputs["Scale"].default_value = 7.0
    bruit.inputs["Detail"].default_value = 6.0
    liens.new(centre.outputs["Vector"], bruit.inputs["Vector"])

    # Extinction sur les bords : c'est elle qui transforme un rectangle en
    # lueur. Sans elle, l'oeil lit un panneau.
    separer = arbre.nodes.new("ShaderNodeSeparateXYZ")
    liens.new(centre.outputs["Vector"], separer.inputs["Vector"])
    rayon = arbre.nodes.new("ShaderNodeVectorMath")
    rayon.operation = "LENGTH"
    aplati = arbre.nodes.new("ShaderNodeCombineXYZ")
    liens.new(separer.outputs["X"], aplati.inputs["X"])
    liens.new(separer.outputs["Y"], aplati.inputs["Y"])
    liens.new(aplati.outputs["Vector"], rayon.inputs[0])
    bord = arbre.nodes.new("ShaderNodeMapRange")
    # 0 au centre, 0,5 au bord d'un `Generated` recentre : l'extinction court
    # donc sur toute la moitie exterieure.
    bord.inputs["From Min"].default_value = 0.12
    bord.inputs["From Max"].default_value = 0.48
    bord.inputs["To Min"].default_value = 1.0
    bord.inputs["To Max"].default_value = 0.0
    liens.new(rayon.outputs["Value"], bord.inputs["Value"])

    # LE SEUIL, ET IL FAIT TOUTE LA DIFFERENCE. Sans lui, le bruit rend une
    # valeur partout : la lueur devient un DRAP CONTINU qui noie la resille et
    # detruit le noir dominant -- mesure du 12/08, troisieme calibration, ou
    # l'orange remplissait la moitie basse du cadre.
    # Avec une rampe raide, seuls les SOMMETS du bruit s'allument : on obtient
    # des plaques separees qui affleurent entre les mailles, comme sur la
    # reference.
    seuil = arbre.nodes.new("ShaderNodeValToRGB")
    seuil.color_ramp.interpolation = "EASE"
    seuil.color_ramp.elements[0].position = 0.52
    seuil.color_ramp.elements[0].color = (0, 0, 0, 1)
    seuil.color_ramp.elements[1].position = 0.78
    seuil.color_ramp.elements[1].color = (1, 1, 1, 1)
    liens.new(bruit.outputs["Fac"], seuil.inputs["Fac"])

    masque = arbre.nodes.new("ShaderNodeMath")
    masque.operation = "MULTIPLY"
    liens.new(seuil.outputs["Color"], masque.inputs[0])
    liens.new(bord.outputs["Result"], masque.inputs[1])

    teintes = arbre.nodes.new("ShaderNodeValToRGB")
    teintes.color_ramp.elements[0].position = 0.10
    teintes.color_ramp.elements[0].color = ROUGE
    teintes.color_ramp.elements[1].position = 0.70
    teintes.color_ramp.elements[1].color = ORANGE
    liens.new(masque.outputs["Value"], teintes.inputs["Fac"])

    force = arbre.nodes.new("ShaderNodeMath")
    force.operation = "MULTIPLY"
    force.inputs[1].default_value = 3.2 * chaleur
    liens.new(masque.outputs["Value"], force.inputs[0])

    emission = arbre.nodes.new("ShaderNodeEmission")
    liens.new(teintes.outputs["Color"], emission.inputs["Color"])
    liens.new(force.outputs["Value"], emission.inputs["Strength"])
    sortie = arbre.nodes.new("ShaderNodeOutputMaterial")
    liens.new(emission.outputs["Emission"], sortie.inputs["Surface"])

    lueur.data.materials.append(mat)
    return lueur


# ══ ATMOSPHERE ET CAMERA ═════════════════════════════════════════════════

def nuiter(scene=None):
    """Le noir profond legerement bleu. L'ecran reste majoritairement NOIR :
    c'est le RAPPORT qui fait le premium, pas l'intensite absolue."""
    style.monde_nuit(scene or bpy.context.scene)


def haloter(scene=None, taille: int = 7, exposition: float = -0.6):
    """Halo et etalonnage. L'exposition NEGATIVE ramene l'ecran vers le noir et
    fait ressortir les quelques elements lumineux."""
    style.compositing(scene or bpy.context.scene, taille_halo=taille,
                      exposition=exposition)


def cadrer(vise=(0.0, 2.4, -6.0), depuis=(3.2, 5.4, 16.0), focale: float = 50.0,
           ouverture: float = 2.0, mise_au_point: float = None):
    """Camera 9:16 avec profondeur de champ.

    L'ouverture est le levier du flou : sur la reference, les objets lointains
    sont nettement fondus, ce qui separe le sujet du decor. `mise_au_point` par
    defaut vise la cible.
    """
    bpy.ops.object.camera_add(location=depuis)
    cam = bpy.context.object
    cam.data.lens = focale
    cam.data.dof.use_dof = True
    cam.data.dof.aperture_fstop = ouverture

    cible = bpy.data.objects.new("visee", None)
    bpy.context.collection.objects.link(cible)
    cible.location = vise
    suivi = cam.constraints.new("TRACK_TO")
    suivi.target = cible
    suivi.track_axis = "TRACK_NEGATIVE_Z"
    suivi.up_axis = "UP_Y"

    if mise_au_point is None:
        mise_au_point = math.dist(depuis, vise)
    cam.data.dof.focus_distance = mise_au_point

    bpy.context.scene.camera = cam
    return cam


def cadrer_sur(objets, marge: float = 1.18, focale: float = 50.0,
               ouverture: float = 2.2, direction=(0.18, -1.0, 0.34),
               images: int = 1, balayage: float = 26.0, elevation: float = 0.30):
    """Cadre sur CE QUI A ETE CONSTRUIT, en le mesurant. Rend la camera.

    POURQUOI CETTE FONCTION REMPLACE UNE DISTANCE CHOISIE D'AVANCE.

    `composer_scene` posait la camera a une distance CONSTANTE par intention --
    9 unites pour « objet », 14 pour « comparaison ». Cette distance ne savait
    rien de ce que la description avait fait naitre.

    Mesure du 13/08 sur « Poussee d'Archimede », scene s1 : l'IA avait ecrit un
    becher de rayon 3, soit 6 unites de large. Or une focale de 50 mm sur un
    cadre 9:16 ne montre que 2 * 9 * tan(11,45 deg) = 3,6 unites de large a 9
    unites de distance. L'image rendue ne contenait donc QUE la paroi : quatre
    montants bleus et un fond courbe, la sphere invisible hors champ. Rien
    n'avait echoue -- le style etait juste, la composition etait juste, et
    l'etudiant aurait recu un plan incomprehensible.

    C'est le meme defaut de fond que partout ailleurs dans ce moteur : une
    valeur SUPPOSEE la ou une valeur MESUREE etait disponible.

    On projette la boite englobante sur les axes propres de la camera plutot
    que d'utiliser une sphere englobante : une sphere garantirait aussi que
    tout entre, mais gacherait le cadre vertical d'un objet large et plat --
    or le format est 9:16, ou la hauteur est la ressource rare.
    """
    from mathutils import Vector

    points: list = []
    for o in objets or []:
        if o is None or not hasattr(o, "bound_box"):
            continue
        for coin in o.bound_box:
            points.append(o.matrix_world @ Vector(coin))

    if not points:
        # Rien a mesurer : on garde l'ancien comportement plutot que de rendre
        # une camera sans cible. Le repli en texte a besoin d'un cadre.
        return cadrer(vise=(0.0, 0.0, 0.8), depuis=(1.4, -9.0, 1.6),
                      focale=focale, ouverture=ouverture)

    minima = Vector((min(p.x for p in points), min(p.y for p in points),
                     min(p.z for p in points)))
    maxima = Vector((max(p.x for p in points), max(p.y for p in points),
                     max(p.z for p in points)))
    centre = (minima + maxima) * 0.5

    # Le repere propre de la camera : `avant` va vers le sujet.
    vers_camera = Vector(direction)
    if vers_camera.length < 1e-6:
        vers_camera = Vector((0.18, -1.0, 0.34))
    vers_camera.normalize()
    avant = -vers_camera
    haut_monde = Vector((0.0, 0.0, 1.0))
    droite = avant.cross(haut_monde)
    if droite.length < 1e-6:                      # camera a la verticale
        droite = Vector((1.0, 0.0, 0.0))
    droite.normalize()
    haut = droite.cross(avant)
    haut.normalize()

    demi_l = demi_h = avancee = 0.0
    for p in points:
        local = p - centre
        demi_l = max(demi_l, abs(local.dot(droite)))
        demi_h = max(demi_h, abs(local.dot(haut)))
        avancee = max(avancee, -local.dot(avant))   # ce qui vient vers l'objectif

    # LE CHAMP REEL, lu sur la scene. La resolution DOIT etre posee avant cet
    # appel : Blender ajuste le capteur sur la plus grande dimension (`AUTO`),
    # et un cadre encore en 1920x1080 donnerait un champ vertical faux.
    scene = bpy.context.scene
    rx = max(1, int(scene.render.resolution_x))
    ry = max(1, int(scene.render.resolution_y))
    capteur = 36.0
    if ry >= rx:
        demi_angle_v = math.atan((capteur * 0.5) / focale)
        demi_angle_h = math.atan((capteur * 0.5) * (rx / ry) / focale)
    else:
        demi_angle_h = math.atan((capteur * 0.5) / focale)
        demi_angle_v = math.atan((capteur * 0.5) * (ry / rx) / focale)

    distance = max(demi_l / math.tan(demi_angle_h),
                   demi_h / math.tan(demi_angle_v)) * marge + avancee
    distance = max(distance, 1.5)

    depuis = centre + vers_camera * distance
    cam = cadrer(vise=tuple(centre), depuis=tuple(depuis),
                 focale=focale, ouverture=ouverture, mise_au_point=distance)

    if images and images > 1:
        _orbiter(cam, centre, vers_camera, distance, images,
                 balayage=balayage, hauteur=max(demi_h, 0.5) * elevation)
    return cam


def _orbiter(cam, centre, vers_camera, distance: float, images: int,
             balayage: float = 26.0, hauteur: float = 0.6) -> None:
    """Fait tourner lentement la camera autour du sujet, sur toute la scene.

    POURQUOI CETTE FONCTION EXISTE, ET C'EST UN OUBLI, PAS UNE REGRESSION.

    Le chemin des dix archetypes animait sa camera depuis toujours
    (`generateur_scenes._camera`). En ecrivant le compositeur, j'ai porte la
    geometrie et le style, et j'ai oublie le MOUVEMENT : `cadrer_sur` posait une
    camera fixe, sans la moindre image-cle.

    Mesure du 14/08, travail 8b7c72d0 : les 1 154 images rendues etaient
    IDENTIQUES. La porte d'acceptation a refuse la capsule -- « image figee
    46,17 s » -- ce qui a evite de livrer un diaporama a un etudiant, mais
    apres vingt-cinq minutes de GPU passees a rendre 1 154 fois la meme photo.

    LA GRAMMAIRE EST CELLE DU DEPOT, pas une invention : « travellings lents et
    rotations limitees, jamais de coupe » -- maintenir l'attention sans creer de
    confusion. On garde donc un balayage court (26 degres par defaut) et une
    interpolation LINEAIRE : une courbe d'acceleration donnerait un a-coup au
    raccord entre deux scenes, qui se suivent sans transition.

    La distance ne change pas pendant l'orbite : elle a ete calculee pour que
    tout entre dans le cadre, et la faire varier romprait cette garantie.
    """
    from mathutils import Vector

    # L'angle de depart est celui que `cadrer_sur` a choisi ; on tourne AUTOUR,
    # de -moitie a +moitie, pour que le cadrage vise reste le milieu du plan.
    plan = Vector((vers_camera.x, vers_camera.y, 0.0))
    if plan.length < 1e-6:
        plan = Vector((0.0, -1.0, 0.0))
    rayon = plan.length * distance
    depart = math.atan2(plan.y, plan.x)
    hauteur_depart = vers_camera.z * distance

    demi = math.radians(balayage) * 0.5
    for image in range(1, images + 1):
        t = (image - 1) / max(images - 1, 1)
        angle = depart - demi + math.radians(balayage) * t
        cam.location = (centre.x + rayon * math.cos(angle),
                        centre.y + rayon * math.sin(angle),
                        centre.z + hauteur_depart - hauteur * 0.5 + hauteur * t)
        cam.keyframe_insert("location", frame=image)

    if cam.animation_data and cam.animation_data.action:
        for courbe in cam.animation_data.action.fcurves:
            for point in courbe.keyframe_points:
                point.interpolation = "LINEAR"


def vider():
    """Table rase. A appeler avant de composer une scene."""
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    for bloc in (bpy.data.meshes, bpy.data.materials, bpy.data.curves):
        for item in list(bloc):
            if item.users == 0:
                bloc.remove(item)

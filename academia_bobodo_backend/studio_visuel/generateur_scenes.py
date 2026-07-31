"""Academia Blender Generator — transforme une Scene Definition en scene 3D.

C'est la piece qui manquait au studio. Le reste existait : la file de travaux,
le depot dans Storage, le veilleur, la grammaire visuelle, et cote LWS la
narration, le sound design et le montage.

LE VOCABULAIRE VISUEL. Quatre archetypes, tous PROCEDURAUX -- aucun objet a
modeliser, donc aucune semaine de travail 3D cachee derriere. Chacun repond a
un besoin pedagogique reel du catalogue Academia :

  reseau      un nuage de noeuds relies, un chemin s'allume de proche en proche
              -> orientation, filieres, « trouver sa voie »
  flux        des particules circulent le long d'un parcours
              -> progression, financement, transmission, energie
  strates     des couches s'empilent l'une apres l'autre
              -> niveaux d'etudes, etapes d'un dossier, paliers
  comparaison deux ensembles cote a cote, un seul s'illumine
              -> comparer deux filieres, deux choix, deux methodes

Chaque archetype se decline en couleur d'accent et en mouvement de camera. La
grammaire commune vient de `style_reference.py`, pour que toutes les capsules
se ressemblent d'un episode a l'autre.

Usage : blender -b --python generateur_scenes.py -- capsule.json
"""

from __future__ import annotations

import json
import math
import os
import random
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, "/workspace")

import bpy  # noqa: E402
import academia_scene  # noqa: E402
import style_reference as style  # noqa: E402


# ── Utilitaires ───────────────────────────────────────────────────────────

def _vider():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    for bloc in (bpy.data.meshes, bpy.data.materials, bpy.data.curves,
                 bpy.data.particles):
        for item in list(bloc):
            if item.users == 0:
                bloc.remove(item)


def _pulser(materiau, debut, duree_images, force_max, force_repos=0.5):
    """Fait monter puis redescendre l'emission d'une matiere.

    C'est le geste de base de toute la grammaire : un element s'allume quand
    on en parle, puis reste visible sans voler l'attention. Sans ce retour au
    repos, tous les elements finissent allumes et l'image redevient plate.

    L'ACCROCHE fait exception, voir `_debut_accroche` : 50 a 60 % des abandons
    se produisent dans les trois premieres secondes, une premiere image terne
    a deja perdu la moitie de l'audience.
    """
    noeud = materiau.node_tree.nodes.get("Emission")
    if noeud is None:
        return
    force = noeud.inputs["Strength"]
    montee = max(2, int(duree_images * 0.10))
    tenue = max(3, int(duree_images * 0.22))

    force.default_value = force_repos
    force.keyframe_insert("default_value", frame=max(1, debut))
    force.default_value = force_max
    force.keyframe_insert("default_value", frame=debut + montee)
    force.default_value = force_max * 0.55
    force.keyframe_insert("default_value", frame=debut + montee + tenue)


def _debut_accroche(images, rang, total, proportion_normale):
    """A quelle image un element doit-il s'allumer.

    Regle : la PREMIERE scene n'attend pas. 50 a 60 % des abandons se
    produisent dans les trois premieres secondes, et les plateformes mesurent
    desormais la « retention d'intro » -- le pourcentage de spectateurs encore
    la apres trois secondes. Une capsule qui s'ouvre sur un fondu lent a deja
    perdu la moitie de son audience.

    Sur la scene d'accroche, le premier element est donc allume des l'image 1
    et les suivants s'enchainent vite. Ailleurs, on respire.
    """
    if _EST_ACCROCHE:
        if rang == 0:
            return 1
        return 1 + rang * max(2, int(images * 0.34 / max(total, 1)))
    return int(images * proportion_normale) + rang * int(images * 0.66 / max(total, 1))


# Positionne par `rendre_scene` : seule la premiere scene de la capsule est
# traitee en accroche.
_EST_ACCROCHE = False


# ── Archetype : reseau ────────────────────────────────────────────────────

def _archetype_reseau(scene_def, images, accent, alea):
    p = scene_def["parametres"]
    nb = int(p.get("noeuds", 44))
    etapes = int(p.get("chemin", 6))
    distance = float(p.get("distance_lien", 2.6))

    points = [(alea.uniform(-3.4, 3.4), alea.uniform(-3.4, 3.4),
               alea.uniform(-4.2, 4.2)) for _ in range(nb)]

    aretes = [(i, j) for i in range(nb) for j in range(i + 1, nb)
              if math.dist(points[i], points[j]) < distance]

    maille = bpy.data.meshes.new("reseau")
    maille.from_pydata(points, aretes, [])
    maille.update()
    objet = bpy.data.objects.new("reseau", maille)
    bpy.context.collection.objects.link(objet)
    # La matiere « filaire » sans modeliser un seul lien.
    objet.data.materials.append(style.matiere_emissive("lien", style.BLEU_FROID, 1.0))
    style.filaire(objet, 0.011)

    # Chemin de proche en proche : un parcours qui saute d'un bout a l'autre
    # ne raconterait rien.
    courant = min(range(nb), key=lambda i: points[i][2])
    chemin = [courant]
    while len(chemin) < min(etapes, nb):
        restants = [i for i in range(nb) if i not in chemin]
        courant = min(restants, key=lambda i: math.dist(points[courant], points[i]))
        chemin.append(courant)

    repos = style.matiere_emissive("noeud", style.BLEU_FROID, 2.2)
    for indice, position in enumerate(points):
        bpy.ops.mesh.primitive_ico_sphere_add(radius=0.07, subdivisions=2, location=position)
        sphere = bpy.context.object
        sphere.data.materials.append(repos)

        if indice in chemin:
            rang = chemin.index(indice)
            sphere.data.materials.clear()
            mat = style.matiere_emissive(f"etape_{rang}", accent, 0.5)
            sphere.data.materials.append(mat)
            sphere.scale = (1.9, 1.9, 1.9)
            debut = _debut_accroche(images, rang, len(chemin), 0.10)
            _pulser(mat, debut, images, 24.0)

    return 9.5   # distance de cadrage conseillee


# ── Archetype : flux ──────────────────────────────────────────────────────

def _archetype_flux(scene_def, images, accent, alea):
    p = scene_def["parametres"]
    nb = int(p.get("particules", 55))
    tours = float(p.get("tours", 1.4))
    rayon = float(p.get("rayon", 3.0))
    hauteur = float(p.get("hauteur", 7.0))

    def position(t):
        angle = t * tours * 2 * math.pi
        return (rayon * math.cos(angle), rayon * math.sin(angle), -hauteur / 2 + t * hauteur)

    # Le rail : on voit le chemin AVANT que les particules le parcourent.
    # Sans lui, on ne comprend pas ou elles vont.
    jalons = [position(i / 90) for i in range(91)]
    rail_mesh = bpy.data.meshes.new("rail")
    rail_mesh.from_pydata(jalons, [(i, i + 1) for i in range(90)], [])
    rail_mesh.update()
    rail = bpy.data.objects.new("rail", rail_mesh)
    bpy.context.collection.objects.link(rail)
    rail.data.materials.append(style.matiere_emissive("rail", style.BLEU_FROID, 0.9))
    style.filaire(rail, 0.02)

    mat = style.matiere_emissive("particule", accent, 16.0)
    for indice in range(nb):
        decalage = indice / nb
        bpy.ops.mesh.primitive_ico_sphere_add(radius=0.075, subdivisions=1,
                                              location=position(decalage))
        bille = bpy.context.object
        bille.data.materials.append(mat)
        # Chaque particule parcourt le rail en boucle, decalee des autres :
        # le flux est continu sans qu'aucune particule ne saute.
        for image in range(1, images + 1):
            avance = (decalage + (image - 1) / max(images - 1, 1)) % 1.0
            bille.location = position(avance)
            bille.keyframe_insert("location", frame=image)
        if bille.animation_data:
            for courbe in bille.animation_data.action.fcurves:
                for point in courbe.keyframe_points:
                    point.interpolation = "LINEAR"

    return 11.0


# ── Archetype : strates ───────────────────────────────────────────────────

def _archetype_strates(scene_def, images, accent, alea):
    p = scene_def["parametres"]
    nb = int(p.get("couches", 5))
    ecart = float(p.get("ecart", 1.5))
    rayon = float(p.get("rayon", 3.2))

    for indice in range(nb):
        z = -((nb - 1) * ecart) / 2 + indice * ecart
        bpy.ops.mesh.primitive_circle_add(vertices=64, radius=rayon * (1 - indice * 0.09),
                                          location=(0, 0, z))
        anneau = bpy.context.object

        # La derniere couche porte l'accent : c'est le palier vise. Les autres
        # restent froides -- une seule chose doit attirer l'oeil.
        derniere = indice == nb - 1
        mat = style.matiere_emissive(
            f"strate_{indice}", accent if derniere else style.BLEU_FROID, 0.5)
        anneau.data.materials.append(mat)
        style.filaire(anneau, 0.035)

        debut = _debut_accroche(images, indice, nb, 0.08)
        _pulser(mat, debut, images, 22.0 if derniere else 6.0)

        # Elles montent en place au lieu d'apparaitre : l'empilement se
        # comprend par le mouvement, pas par la legende.
        anneau.location = (0, 0, z - 1.2)
        anneau.keyframe_insert("location", frame=max(1, debut))
        anneau.location = (0, 0, z)
        anneau.keyframe_insert("location", frame=debut + max(3, int(images * 0.12)))

    return 10.0


# ── Archetype : comparaison ───────────────────────────────────────────────

def _archetype_comparaison(scene_def, images, accent, alea):
    p = scene_def["parametres"]
    nb = int(p.get("noeuds_par_groupe", 22))
    ecart = float(p.get("ecart", 4.6))

    for cote, signe in (("gauche", -1), ("droite", 1)):
        centre = (signe * ecart / 2, 0, 0)
        points = [(centre[0] + alea.uniform(-1.5, 1.5),
                   alea.uniform(-1.5, 1.5),
                   alea.uniform(-2.6, 2.6)) for _ in range(nb)]

        aretes = [(i, j) for i in range(nb) for j in range(i + 1, nb)
                  if math.dist(points[i], points[j]) < 1.7]
        maille = bpy.data.meshes.new(f"groupe_{cote}")
        maille.from_pydata(points, aretes, [])
        maille.update()
        objet = bpy.data.objects.new(f"groupe_{cote}", maille)
        bpy.context.collection.objects.link(objet)


        # Le groupe retenu s'allume en second : on montre l'alternative AVANT
        # de designer le choix, sinon la comparaison n'a pas eu lieu.
        retenu = signe > 0
        mat = style.matiere_emissive(
            f"groupe_{cote}", accent if retenu else style.BLEU_FROID, 0.6)
        objet.data.materials.append(mat)
        style.filaire(objet, 0.014)
        debut = int(images * (0.45 if retenu else 0.12))
        _pulser(mat, debut, images, 18.0 if retenu else 5.0)

    return 12.0


# ── Archetype : titre ─────────────────────────────────────────────────────

def _archetype_titre(scene_def, images, accent, alea):
    """Le sujet EST l'objet.

    Lecon tiree des trois references : elles n'illustrent pas leur propos, elles
    rendent le propos lui-meme en geometrie lumineuse. « 0.999… » et « 1 » ne
    sont pas dessines a cote du texte, ils SONT la scene.

    C'est aussi l'archetype qui rend le studio universel : une formule pour les
    mathematiques, un mot pour la litterature, un symbole pour la chimie, une
    note pour la musique. Un seul outil, tous les themes.
    """
    p = scene_def["parametres"]
    principal = str(p.get("texte") or scene_def.get("titre") or "?")
    secondaire = str(p.get("texte_second") or "")
    taille = float(p.get("taille", 1.7))

    sol = style.sol_grille(cote=30.0, pas=54, amplitude=0.6, graine=alea.randint(1, 99))
    sol.location = (0, 0, -3.4)
    sol.data.materials.append(style.matiere_emissive("grille", style.BLEU_FROID, 0.75))
    style.filaire(sol, 0.008)

    ecart = 3.1 if secondaire else 0.0
    objet = style.texte_3d(principal, taille=taille, position=(-ecart, 0, 0.4))
    objet.data.materials.append(
        style.matiere_hologramme("titre_principal", style.BLEU_FROID, 7.0))

    if secondaire:
        second = style.texte_3d(secondaire, taille=taille, position=(ecart, 0, 0.4))
        mat = style.matiere_hologramme("titre_second", accent, 1.0)
        second.data.materials.append(mat)
        # Le second terme s'allume APRES : on pose la question avant de donner
        # la reponse, sinon il n'y a plus de question.
        _pulser(mat, _debut_accroche(images, 1, 2, 0.35), images, 11.0)

    return 12.5


# ── Archetype : terrain ───────────────────────────────────────────────────

def _archetype_terrain(scene_def, images, accent, alea):
    """Le plan d'ambiance : sol quadrille, ondes qui se propagent, brume.

    Sert de respiration entre deux idees, et d'etablissement au debut. C'est le
    plan qui ne dit rien mais qui installe le monde -- toutes les references en
    ont un.
    """
    p = scene_def["parametres"]
    nb_ondes = int(p.get("ondes", 12))

    sol = style.sol_grille(cote=34.0, pas=60, amplitude=0.75, graine=alea.randint(1, 99))
    sol.location = (0, 0, -2.2)
    sol.data.materials.append(style.matiere_emissive("grille", style.BLEU_FROID, 0.8))
    style.filaire(sol, 0.009)

    for rang, cercle in enumerate(style.ondes(nb_ondes, rayon_max=13.0, hauteur=-2.0)):
        mat = style.matiere_emissive(f"onde_{rang}", accent if rang % 3 == 0 else style.BLEU_FROID, 0.4)
        cercle.data.materials.append(mat)
        style.filaire(cercle, 0.014)
        # Les ondes s'allument du centre vers l'exterieur : la propagation se
        # lit dans le temps, pas dans une legende.
        _pulser(mat, _debut_accroche(images, rang, nb_ondes, 0.05), images, 9.0)

    return 15.0


# ── Archetype : silhouette ────────────────────────────────────────────────

def _archetype_silhouette(scene_def, images, accent, alea):
    """Un contour quelconque, en volume et en hologramme.

    C'EST LA BRIQUE QUI OUVRE TOUTES LES DISCIPLINES. Un fichier SVG de
    quelques kilo-octets remplace des semaines de modelisation : un organe pour
    la medecine, un os pour l'archeologie, un pays pour la geographie, un
    instrument pour la musique, une feuille pour l'agroalimentaire, un plan
    pour l'architecture, un symbole pour la religion.

    Le contenu change, le traitement reste -- c'est exactement ce qui fait
    qu'une chaine comme mathoholic garde la meme identite sur des sujets sans
    rapport.

    Sans SVG fourni, on retombe sur du texte en volume : degradation gracieuse,
    la scene existe toujours.
    """
    p = scene_def["parametres"]
    chemin = str(p.get("svg") or "")
    echelle = float(p.get("echelle", 6.0))

    objets = []
    if chemin and os.path.isfile(chemin):
        avant = set(bpy.data.objects)
        try:
            bpy.ops.import_curve.svg(filepath=chemin)
            objets = [o for o in bpy.data.objects if o not in avant]
        except Exception as e:  # noqa: BLE001
            print(f"SVG illisible ({e}) — repli sur le texte", flush=True)

    if not objets:
        # Repli : le sujet en toutes lettres plutot qu'une scene vide.
        secours = str(p.get("texte") or scene_def.get("titre") or "?")
        objets = [style.texte_3d(secours, taille=1.6, extrusion=0.10)]
        echelle = 1.0

    matiere = style.matiere_hologramme("silhouette", style.BLEU_FROID, 6.5)
    accent_mat = style.matiere_hologramme("silhouette_accent", accent, 0.8)

    for indice, objet in enumerate(objets):
        if objet.type == "CURVE":
            objet.data.extrude = 0.05
            objet.data.bevel_depth = 0.008
            objet.data.fill_mode = "BOTH"
        objet.scale = (echelle, echelle, echelle)
        objet.location = (0, 0, 0)
        objet.data.materials.clear()
        # Une piece sur trois prend l'accent : c'est ce qui fait lire un objet
        # comme « compose de parties » plutot que comme une masse uniforme.
        objet.data.materials.append(accent_mat if indice % 3 == 1 else matiere)

    _pulser(accent_mat, _debut_accroche(images, 0, 1, 0.18), images, 9.0)

    sol = style.sol_grille(cote=26.0, pas=46, amplitude=0.5, graine=alea.randint(1, 99))
    sol.location = (0, 0, -3.2)
    sol.data.materials.append(style.matiere_emissive("grille", style.BLEU_FROID, 0.6))
    style.filaire(sol, 0.008)

    return 11.0


# ── Archetype : chronologie ───────────────────────────────────────────────

def _archetype_chronologie(scene_def, images, accent, alea):
    """Une frise dans l'espace : jalons qui s'allument l'un apres l'autre.

    Histoire, archeologie, biographie, etapes d'un dossier, evolution d'une
    reglementation. Le temps se lit dans le TEMPS de la video, pas dans une
    legende -- c'est ce qui distingue une frise animee d'une image fixe.
    """
    p = scene_def["parametres"]
    jalons = p.get("jalons")
    if not isinstance(jalons, list) or not jalons:
        jalons = ["1", "2", "3", "4"]
    jalons = [str(j) for j in jalons][:8]
    longueur = float(p.get("longueur", 14.0))

    # L'axe : on voit la duree entiere avant que les jalons ne s'allument.
    pas = longueur / max(len(jalons) - 1, 1)
    debut_x = -longueur / 2
    axe_points = [(debut_x + longueur * i / 40, 0, 0) for i in range(41)]
    axe_mesh = bpy.data.meshes.new("axe")
    axe_mesh.from_pydata(axe_points, [(i, i + 1) for i in range(40)], [])
    axe_mesh.update()
    axe = bpy.data.objects.new("axe", axe_mesh)
    bpy.context.collection.objects.link(axe)
    axe.data.materials.append(style.matiere_emissive("axe", style.BLEU_FROID, 1.2))
    style.filaire(axe, 0.02)

    for rang, etiquette in enumerate(jalons):
        x = debut_x + rang * pas
        bpy.ops.mesh.primitive_ico_sphere_add(radius=0.16, subdivisions=2, location=(x, 0, 0))
        borne = bpy.context.object
        mat = style.matiere_emissive(f"jalon_{rang}", accent, 0.5)
        borne.data.materials.append(mat)

        # L'etiquette alterne au-dessus et en dessous : sur huit jalons, tout
        # aligner du meme cote rend le texte illisible.
        hauteur = 0.85 if rang % 2 == 0 else -0.95
        texte = style.texte_3d(etiquette, taille=0.42, extrusion=0.03,
                               position=(x, 0, hauteur),
                               rotation=(math.radians(90), 0, 0))
        texte.data.materials.append(style.matiere_hologramme(f"date_{rang}", accent, 5.0))

        debut = _debut_accroche(images, rang, len(jalons), 0.10)
        _pulser(mat, debut, images, 20.0)

    return longueur * 0.95


# ── Archetype : carte ─────────────────────────────────────────────────────

def _archetype_carte(scene_def, images, accent, alea):
    """Un territoire, des points, des routes en arc.

    Geographie, migrations, commerce, propagation d'une epidemie, reseau
    d'etablissements. L'arc plutot que la ligne droite : il se lit comme un
    trajet, quand une droite se lit comme une simple relation.
    """
    p = scene_def["parametres"]
    nb_points = int(p.get("points", 7))
    etendue = float(p.get("etendue", 9.0))

    sol = style.sol_grille(cote=etendue * 2.6, pas=54, amplitude=0.45,
                           graine=alea.randint(1, 99))
    sol.data.materials.append(style.matiere_emissive("territoire", style.BLEU_FROID, 0.7))
    style.filaire(sol, 0.007)

    lieux = [(alea.uniform(-etendue, etendue), alea.uniform(-etendue, etendue), 0.35)
             for _ in range(nb_points)]

    for rang, lieu in enumerate(lieux):
        bpy.ops.mesh.primitive_ico_sphere_add(radius=0.17, subdivisions=2, location=lieu)
        point = bpy.context.object
        mat = style.matiere_emissive(f"lieu_{rang}", accent, 0.5)
        point.data.materials.append(mat)
        _pulser(mat, _debut_accroche(images, rang, nb_points, 0.08), images, 18.0)

    # Les routes relient chaque lieu au suivant, en arc.
    matiere_route = style.matiere_emissive("route", accent, 3.2)
    for rang in range(len(lieux) - 1):
        depart, arrivee = lieux[rang], lieux[rang + 1]
        distance = math.dist(depart[:2], arrivee[:2])
        sommet = 0.35 + distance * 0.28
        points_arc = []
        for i in range(25):
            t = i / 24
            x = depart[0] + (arrivee[0] - depart[0]) * t
            y = depart[1] + (arrivee[1] - depart[1]) * t
            z = 0.35 + math.sin(t * math.pi) * sommet
            points_arc.append((x, y, z))
        maille = bpy.data.meshes.new(f"route_{rang}")
        maille.from_pydata(points_arc, [(i, i + 1) for i in range(24)], [])
        maille.update()
        route = bpy.data.objects.new(f"route_{rang}", maille)
        bpy.context.collection.objects.link(route)
        route.data.materials.append(matiere_route)
        style.filaire(route, 0.012)

    return etendue * 1.9


# ── Archetype : ondes ─────────────────────────────────────────────────────

def _archetype_ondes(scene_def, images, accent, alea):
    """Ce qui se propage depuis une source.

    Un son, une chaleur, une epidemie, une influence, une reputation. La
    troisieme reference l'utilise telle quelle pour le nombre d'or.

    Different de `terrain` : ici la propagation EST le sujet, pas l'ambiance.
    La source est visible, les cercles partent d'elle, et le rythme
    d'allumage donne la vitesse.
    """
    p = scene_def["parametres"]
    nb = int(p.get("cercles", 16))
    rayon_max = float(p.get("rayon", 12.0))
    verticales = bool(p.get("verticales", False))

    # La source : sans elle on voit des cercles, pas une propagation.
    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.34, subdivisions=3, location=(0, 0, 0))
    source = bpy.context.object
    mat_source = style.matiere_emissive("source", accent, 0.6)
    source.data.materials.append(mat_source)
    _pulser(mat_source, _debut_accroche(images, 0, 1, 0.04), images, 30.0)

    for rang in range(nb):
        rayon = rayon_max * (rang + 1) / nb
        rotation = (math.radians(90), 0, 0) if verticales else (0, 0, 0)
        bpy.ops.mesh.primitive_circle_add(vertices=96, radius=rayon,
                                          location=(0, 0, 0), rotation=rotation)
        cercle = bpy.context.object
        mat = style.matiere_emissive(f"onde_{rang}", accent, 0.3)
        cercle.data.materials.append(mat)
        # Plus fin en s'eloignant : l'onde s'attenue, elle ne se contente pas
        # de grandir. C'est ce qui la fait lire comme une energie qui se perd.
        style.filaire(cercle, 0.022 * (1 - 0.6 * rang / max(nb - 1, 1)))

        debut = _debut_accroche(images, rang, nb, 0.06)
        _pulser(mat, debut, images, 14.0 * (1 - 0.55 * rang / max(nb - 1, 1)))

    return rayon_max * 1.35


ARCHETYPES = {
    "ondes": _archetype_ondes,
    "reseau": _archetype_reseau,
    "flux": _archetype_flux,
    "strates": _archetype_strates,
    "comparaison": _archetype_comparaison,
    "titre": _archetype_titre,
    "terrain": _archetype_terrain,
    "silhouette": _archetype_silhouette,
    "chronologie": _archetype_chronologie,
    "carte": _archetype_carte,
}


# ── Camera ────────────────────────────────────────────────────────────────

def _camera(mouvement, distance, images):
    """Travellings lents et rotations limitees, jamais de coupe. C'est la
    regle « maintenir l'attention sans creer de confusion »."""
    cible = bpy.data.objects.new("cible", None)
    bpy.context.collection.objects.link(cible)

    bpy.ops.object.camera_add()
    cam = bpy.context.object
    cam.data.lens = 50
    cam.data.dof.use_dof = True
    cam.data.dof.focus_distance = distance
    cam.data.dof.aperture_fstop = 2.8

    suivi = cam.constraints.new("TRACK_TO")
    suivi.target = cible
    suivi.track_axis = "TRACK_NEGATIVE_Z"
    suivi.up_axis = "UP_Y"

    for image in range(1, images + 1):
        t = (image - 1) / max(images - 1, 1)
        if mouvement == "orbite":
            angle = math.radians(-40 + 26 * t)
            cam.location = (distance * math.cos(angle), distance * math.sin(angle),
                            -1.8 + 4.0 * t)
        elif mouvement == "avance":
            cam.location = (distance * (1.25 - 0.35 * t), -distance * (1.25 - 0.35 * t),
                            1.2 + 0.9 * t)
        elif mouvement == "montee":
            cam.location = (distance * 0.95, -distance * 0.95, -4.0 + 8.5 * t)
        else:  # recul
            cam.location = (distance * (0.75 + 0.5 * t), -distance * (0.75 + 0.5 * t),
                            0.6 + 1.6 * t)
        cam.keyframe_insert("location", frame=image)

    # Interpolation lineaire : une courbe d'accélération donnerait un a-coup
    # au raccord entre deux scenes.
    for courbe in cam.animation_data.action.fcurves:
        for point in courbe.keyframe_points:
            point.interpolation = "LINEAR"

    bpy.context.scene.camera = cam


# ── Rendu d'une scene ─────────────────────────────────────────────────────

def rendre_scene(scene_def, format_capsule, dossier, graine=0, accroche=False):
    global _EST_ACCROCHE
    _EST_ACCROCHE = accroche
    images = max(1, int(round(scene_def["duree_s"] * format_capsule["fps"])))
    accent = academia_scene.ACCENTS[scene_def["accent"]]
    alea = random.Random(graine)

    _vider()
    constructeur = ARCHETYPES[scene_def["archetype"]]
    distance = constructeur(scene_def, images, accent, alea)
    _camera(scene_def["camera"], distance, images)

    scene = bpy.context.scene
    scene.render.resolution_x = format_capsule["largeur"]
    scene.render.resolution_y = format_capsule["hauteur"]
    scene.render.fps = format_capsule["fps"]
    scene.frame_start = 1
    scene.frame_end = images
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = os.path.join(dossier, f"{scene_def['id']}_")

    style.monde_nuit(scene)
    style.cadre_cinema(scene)
    style.compositing(scene)
    style.moteur_eevee(scene)

    debut = time.time()
    bpy.ops.render.render(animation=True)
    ecoule = time.time() - debut
    print(f"SCENE {scene_def['id']} {scene_def['archetype']} "
          f"images={images} secondes={ecoule:.1f}", flush=True)
    return images, ecoule


def main() -> int:
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if not args:
        print("GENERATEUR_ERREUR chemin_json_manquant", flush=True)
        return 1

    with open(args[0], encoding="utf-8") as f:
        capsule = academia_scene.normaliser(json.load(f))

    dossier = args[1] if len(args) > 1 else "/workspace/capsule/frames"
    os.makedirs(dossier, exist_ok=True)

    print("CAPSULE " + academia_scene.resume(capsule), flush=True)
    for avertissement in capsule["avertissements"]:
        print(f"CORRECTION {avertissement}", flush=True)

    total_images = 0
    total_secondes = 0.0
    for rang, scene_def in enumerate(capsule["scenes"]):
        images, ecoule = rendre_scene(scene_def, capsule["format"], dossier,
                                      graine=rang * 7 + 3, accroche=(rang == 0))
        total_images += images
        total_secondes += ecoule

    print(f"GENERATEUR_TERMINE images={total_images} secondes={total_secondes:.1f} "
          f"par_image={total_secondes / max(total_images, 1):.2f}", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())

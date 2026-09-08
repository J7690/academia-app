"""Execute une scene DECRITE, au lieu de choisir une forme dans un catalogue.

CE QUE CE MODULE REMPLACE.
`generateur_scenes.ARCHETYPES` est un dictionnaire de dix fonctions. L'IA en
choisissait une et reglait des nombres : `noeuds`, `couches`, `rayon`. Huit des
dix n'acceptaient que cela, et un nombre de noeuds ne dit rien d'un sujet.
Mesure du 07/08 : « la sociologie » et « la germination » ont produit la MEME
suite de formes.

CE QU'IL FAIT A LA PLACE.
Il execute une COMPOSITION : une liste de gestes, chacun nommant un verbe
d'`academia3d` et ses parametres. La forme n'existe pas avant que la
description l'ecrive.

POURQUOI DU JSON ET NON DU CODE -- revision assumee de la conception du 11/08.
Celle-ci prevoyait que l'IA ecrive du Python restreint, hors ligne, parce
qu'ecrire du code dans la boucle etudiant coute des minutes (LL3M : ~4 min pour
un seul objet). Elle ecartait le JSON comme « isomorphe aux archetypes -- des
noms de formes plus des nombres ».

C'etait vrai des ARCHETYPES. Ce ne l'est plus des VERBES : `silhouetter` prend
des COORDONNEES. Un squelette de corps, c'est vingt triplets de nombres -- une
IA les ecrit en quelques secondes, en JSON, sans generer une ligne de code.
Regler `noeuds=20` sur une forme preexistante ne dit rien du sujet ; poser
vingt points qui dessinent un corps, si.

CE QUE CE CHOIX SUPPRIME : la generation de code hors ligne, la geole
d'execution, le cache de recettes, la boucle de reparation.
CE QU'IL COUTE : pas de boucles ni d'arithmetique relative. `essaimer` devient
un parametre ; « dans le thorax » passe par un point d'ancrage nomme.

DEGRADATION VISIBLE. Un geste inconnu, un parametre absurde, un verbe qui
echoue : on ne remplace pas en silence par une forme generique -- c'etait le
defaut de `validate_capsule.ts:74`, qui substituait `reseau` a toute forme
inconnue. On journalise, et on retombe sur le TEXTE, qui dit au moins le sujet.
"""

from __future__ import annotations

import math
import os
import sys
import traceback

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import academia3d as a3  # noqa: E402
import academia3d_style as st  # noqa: E402
import style_reference as style  # noqa: E402

# Les six intentions. Elles ne changent PAS la forme -- elles disent ce que la
# scene cherche a faire comprendre, et c'est ce qui doit varier avec le sujet.
# Le rendu s'en sert pour le cadrage et le rythme, pas pour choisir un objet.
INTENTIONS = ("objet", "processus", "comparaison", "structure", "echelle", "flux")

# Cadrage par intention. Montrer un OBJET demande de s'en approcher ; montrer
# une STRUCTURE demande de reculer pour voir l'ensemble.
# LE CADRAGE NE CONTIENT PLUS DE DISTANCE, ET C'EST LE FOND DE L'AFFAIRE.
#
# Il en contenait une par intention -- 9 unites pour « objet », 14 pour
# « comparaison ». Cette distance ne savait rien de ce que la description avait
# fait naitre, et une description peut faire naitre n'importe quoi : c'est meme
# toute la raison d'etre du compositeur.
#
# Mesure du 13/08, « Poussee d'Archimede » scene s1 : l'IA avait ecrit un
# becher de 6 unites de large ; a 9 unites, une focale de 50 mm sur un cadre
# 9:16 n'en montre que 3,6. L'image ne contenait que la paroi. Le style etait
# juste, la composition etait juste, et le plan etait illisible.
#
# Ne restent donc ici que des choix d'INTENTION -- d'ou l'on regarde, avec
# quelle profondeur de champ, et combien d'air on laisse autour. La distance,
# elle, est MESUREE sur la boite englobante par `academia3d.cadrer_sur`.
#
# `balayage` : de combien de degres la camera tourne PENDANT la scene. Court par
# principe -- « travellings lents et rotations limitees, jamais de coupe ». Une
# comparaison balaie moins, pour que l'oeil compare au lieu de suivre ; une
# echelle balaie plus, parce que c'est le mouvement qui fait sentir l'etendue.
_CADRAGE = {
    # marge : l'air autour du sujet. direction : d'ou l'on regarde.
    "objet":       dict(marge=1.15, ouverture=2.2, direction=(0.18, -1.0, 0.30), balayage=26.0),
    "processus":   dict(marge=1.25, ouverture=2.8, direction=(0.30, -1.0, 0.34), balayage=22.0),
    "comparaison": dict(marge=1.22, ouverture=3.5, direction=(0.05, -1.0, 0.22), balayage=14.0),
    "structure":   dict(marge=1.20, ouverture=3.0, direction=(0.26, -1.0, 0.42), balayage=24.0),
    "echelle":     dict(marge=1.35, ouverture=4.0, direction=(0.22, -1.0, 0.50), balayage=34.0),
    "flux":        dict(marge=1.28, ouverture=2.6, direction=(0.34, -1.0, 0.30), balayage=30.0),
}


class Journal:
    """Ce qui a ete fait, et ce qui a echoue. Rendu avec la scene.

    Une composition qui degrade DOIT le dire : c'est la difference entre
    « on nettoie, on ne rejette pas » et « on se tait ».
    """

    def __init__(self):
        self.faits: list[str] = []
        self.degradations: list[str] = []

    def fait(self, m: str) -> None:
        self.faits.append(m)

    def degrade(self, m: str) -> None:
        self.degradations.append(m)

    def resume(self) -> dict:
        return {"gestes": len(self.faits), "faits": self.faits,
                "degradations": self.degradations}


# ── Les gestes executables ────────────────────────────────────────────────
# Chaque entree prend (parametres, journal) et rend l'objet cree, ou None.

def _g_convoquer(p, j):
    """Fait venir un objet REEL du sujet, au lieu d'en dessiner une approximation.

    POURQUOI CE VERBE (05/09/2026). Les six autres verbes fabriquent une forme a
    partir de coordonnees. Aucun modele de langue ne dessine un volcan point par
    point : faute de savoir tracer, il produit une forme neutre. Mesure sur la
    capsule « le volcan » — la narration disait « chambre magmatique », puis
    « cone volcanique », et l'image montrait la MEME lentille aplatie.

    `convoquer` prend un NOM et va chercher le maillage dans l'index verifie
    (`contours/index_objets.json`). Il rend `None` si rien ne correspond — et
    c'est une reponse valable : on ne modelise pas « la sociologie », et une
    forme decorative presentee comme le sujet ment a l'etudiant.
    """
    terme = (p.get("terme") or p.get("nom") or "").strip()
    if not terme:
        raise ValueError("convoquer sans terme")
    from convoquer import convoquer as _conv
    # ON PASSE UNE FONCTION, PAS LE JOURNAL.
    #
    # `convoquer` appelle son parametre : `journal(f"...")`. Lui donner `j` --
    # un objet `Journal`, qui n'a que `fait()` et `degrade()` -- levait
    # `TypeError: 'Journal' object is not callable` A CHAQUE APPEL, reussi ou
    # non. Le geste passait donc toujours pour un echec.
    #
    # Mesure du 05/09, travail df934af7 « le volcan » : les cinq scenes
    # employaient `convoquer`, les cinq sont tombees sur le texte de secours --
    # qui ne bouge pas -- et la porte d'acceptation a refuse la capsule pour
    # « image figee 27.31 s ». Le verbe etait juste, l'index etait juste, et
    # rien ne s'affichait : une seule ligne separait les deux.
    return _conv(terme,
                 taille=float(p.get("taille", 2.0)),
                 position=tuple(p.get("position", (0, 0, 0))),
                 nom=p.get("nom"),
                 journal=j.fait)


def _g_silhouetter(p, j):
    segments = p.get("segments") or []
    if not segments:
        raise ValueError("silhouetter sans segments")
    return a3.silhouetter(segments, rayons=p.get("rayons"),
                          lisser=int(p.get("lisser", 1)),
                          position=tuple(p.get("position", (0, 0, 0))),
                          nom=p.get("nom", "silhouette"))


def _g_revolutionner(p, j):
    profil = p.get("profil") or []
    if len(profil) < 2:
        raise ValueError("revolutionner demande un profil d'au moins deux points")
    return a3.revolutionner(profil, tours=int(p.get("tours", 40)),
                            position=tuple(p.get("position", (0, 0, 0))),
                            nom=p.get("nom", "revolution"))


def _g_extruder(p, j):
    contour = p.get("contour") or []
    if len(contour) < 3:
        raise ValueError("extruder demande au moins trois points")
    return a3.extruder(contour, epaisseur=float(p.get("epaisseur", 0.25)),
                       position=tuple(p.get("position", (0, 0, 0))),
                       nom=p.get("nom", "extrude"))


def _g_sculpter(p, j):
    return a3.sculpter(p.get("base", "ovoide"), facettes=int(p.get("facettes", 1)),
                       echelle=float(p.get("echelle", 1.0)),
                       position=tuple(p.get("position", (0, 0, 0))),
                       deformation=float(p.get("deformation", 0.0)),
                       graine=int(p.get("graine", 0)))


def _g_napper(p, j):
    return a3.napper(cote=float(p.get("cote", 190.0)), pas=int(p.get("pas", 46)),
                     amplitude=float(p.get("amplitude", 1.8)))


def _g_ecrire(p, j):
    """LE SECOURS UNIVERSEL. On ne peut pas modeliser un violon ; on peut
    toujours rendre un mot. C'est la brique dite universelle de
    `style_reference.texte_3d`, exposee comme un geste a part entiere."""
    texte = str(p.get("texte", "")).strip()
    if not texte:
        raise ValueError("ecrire sans texte")
    # DEBOUT, FACE A LA CAMERA. Blender cree un texte a plat dans le plan XY,
    # c'est-a-dire couche sur le sol : vu de la camera, un mot devenait une
    # arete. Le secours universel doit etre le geste le plus lisible de tous,
    # pas le moins -- c'est lui qu'on obtient quand tout le reste a echoue.
    objet = style.texte_3d(texte, taille=float(p.get("taille", 1.2)),
                           position=tuple(p.get("position", (0, 0, 0))),
                           rotation=(math.radians(90), 0.0, 0.0))
    style.tenir_dans(objet, float(p.get("largeur_max", 7.0)))
    return objet


GESTES = {
    # `convoquer` en tete : c'est le seul qui fait venir l'OBJET DU SUJET.
    # Les six autres fabriquent une forme a partir de coordonnees, ce qui
    # convient a la structure et jamais au referent.
    "convoquer": _g_convoquer,
    "silhouetter": _g_silhouetter,
    "revolutionner": _g_revolutionner,
    "extruder": _g_extruder,
    "sculpter": _g_sculpter,
    "napper": _g_napper,
    "ecrire": _g_ecrire,
}


def _habiller(objet, geste: dict, j: Journal) -> None:
    """Applique le STYLE. Il ne vient jamais de la description : c'est la
    garantie qu'une capsule ressemble a toutes les autres."""
    if objet is None:
        return
    role = geste.get("role", "structure")
    emission = st.EMISSION_SUJET if role == "sujet" else st.EMISSION_STRUCTURE

    if geste.get("verbe") == "napper":
        # Le terrain REMPLACE sa surface par ses aretes : il ne cache rien, et
        # n'a donc pas besoin d'etre vitre.
        epaisseur = st.arete_grille(float(geste.get("parametres", {}).get("cote", 190.0)),
                                    int(geste.get("parametres", {}).get("pas", 46)))
        a3.filairer(objet, epaisseur=epaisseur, emission=emission)
        return

    # TOUTE SURFACE CONSERVEE DOIT ETRE TRAVERSABLE. C'EST LA REGLE.
    #
    # Le verre n'etait pose que sur le role « sujet ». Or c'est la STRUCTURE qui
    # entoure : un becher, une cuve, une coque, une piece. Declaree `structure`,
    # elle gardait une surface OPAQUE et cachait tout ce qu'elle contenait.
    #
    # Mesure du 14/08, scene s1 de « Poussee d'Archimede » : le becher
    # (`revolutionner`, role structure) s'affichait, et la sphere posee a
    # l'interieur (`sculpter`, role sujet) etait INTROUVABLE sur l'image --
    # zoom et contraste force compris. Rendue seule, la meme sphere est nette,
    # epaisse et lumineuse : le verbe n'a jamais ete en cause, c'est le
    # recipient qui la masquait.
    #
    # Le defaut etait donc invisible a la lecture du code de `sculpter`, et
    # muet : le compositeur declarait le geste FAIT, ce qu'il etait.
    #
    # `verre: false` reste possible dans la description pour une piece qu'on
    # veut franchement opaque, mais ce n'est plus le defaut.
    if geste.get("verre", True):
        a3.vitrer(objet, force=st.VERRE_FORCE, densite_bord=st.VERRE_BORD)

    echelle = float(geste.get("parametres", {}).get("echelle", 1.0))
    a3.filairer(objet, epaisseur=st.arete_objet(max(echelle, 1.0)),
                emission=emission, garder_surface=True)


def composer(scene: dict) -> dict:
    """Execute une scene decrite. Rend le journal de ce qui a ete fait.

    `scene` attend :
        intention   une des six
        gestes      liste de {verbe, parametres, role?}
        sujet       le libelle, pour le secours en texte
    """
    j = Journal()
    a3.vider()
    a3.nuiter()

    intention = str(scene.get("intention") or "objet")
    if intention not in INTENTIONS:
        j.degrade(f"intention inconnue « {intention} » — ramenee a « objet »")
        intention = "objet"

    # ON RETIENT LE VERBE AVEC SON OBJET, PAS DEUX LISTES EN PARALLELE.
    #
    # Le cadrage plus bas excluait le terrain par `zip(produits, verbes)`, ou
    # `verbes` etait relu depuis la description. Les deux listes ne coincident
    # que si CHAQUE geste produit exactement un objet : un seul geste ecarte
    # (verbe inconnu) ou en echec decale tout le reste, et le zip attribue
    # alors le verbe du voisin. Un `napper` ainsi mal etiquete revient a cadrer
    # sur 190 unites de terrain — le defaut mesure le 19/08 sur « le petrole ».
    poses: list[tuple[object, str]] = []
    for rang, geste in enumerate(scene.get("gestes") or []):
        verbe = str(geste.get("verbe") or "")
        parametres = geste.get("parametres") or {}
        if verbe not in GESTES:
            j.degrade(f"geste {rang} : verbe inconnu « {verbe} » — geste ignore")
            continue
        try:
            objet = GESTES[verbe](parametres, j)
            # UN GESTE PEUT LEGITIMEMENT NE RIEN PRODUIRE, SANS ECHOUER.
            #
            # Les six verbes de forme levent quand ils ne peuvent pas tracer.
            # `convoquer` est le premier a rendre `None` comme reponse VALABLE :
            # aucun objet verifie ne correspond au terme. Ajouter ce `None` aux
            # produits aurait deux effets, tous deux muets — le repli sur le
            # texte du sujet ne se declencherait plus (la liste n'est pas vide),
            # et le cadrage recevrait un `None` a mesurer.
            if objet is None:
                j.degrade(f"geste {rang} « {verbe} » n'a produit aucun objet "
                          f"— rien n'est montre plutot qu'une forme decorative")
                continue
            _habiller(objet, geste, j)
            poses.append((objet, verbe))
            j.fait(f"{verbe}({', '.join(sorted(parametres))})")
        except Exception as e:  # noqa: BLE001
            # ON NE REMPLACE PAS EN SILENCE. `validate_capsule.ts:74`
            # substituait `reseau` a toute forme inconnue : c'est ce qui a rendu
            # deux sujets sans rapport visuellement identiques.
            j.degrade(f"geste {rang} « {verbe} » a echoue : {type(e).__name__}: {e}")
            j.degrade(traceback.format_exc().strip().splitlines()[-1])

    if not poses:
        # RIEN N'A TENU. Plutot qu'une image vide, on ecrit le sujet : il dit
        # au moins de quoi parle la scene.
        sujet = str(scene.get("sujet") or "").strip()
        j.degrade(f"aucun geste n'a produit d'objet — repli sur le texte « {sujet} »")
        if sujet:
            objet = style.texte_3d(sujet, taille=1.1)
            style.tenir_dans(objet, 7.0)
            objet.data.materials.clear()
            objet.data.materials.append(style.matiere_hologramme(
                "secours", st.BLEU if hasattr(st, "BLEU") else a3.BLEU,
                st.EMISSION_SUJET))
            poses.append((objet, "ecrire"))

    produits = [o for o, _ in poses]

    cadre = _CADRAGE[intention]
    # ON CADRE SUR CE QUI EXISTE. `produits` porte les objets reellement crees ;
    # `cadrer_sur` mesure leur boite englobante et en deduit la distance.
    #
    # `images` COMMANDE LE MOUVEMENT, et son absence a coute une capsule
    # entiere : sans lui la camera reste fixe, les images sont identiques, et la
    # porte d'acceptation refuse « image figee » apres vingt-cinq minutes de GPU.
    images = int(scene.get("images") or 1)

    # ON CADRE SUR LE SUJET, PAS SUR L'HORIZON.
    #
    # `napper` produit un terrain de 190 unites de cote. Compte dans la boite
    # englobante, il l'ecrase : la camera recule assez pour contenir 190 unites,
    # et un derrick de 3 unites devient un point.
    #
    # Mesure du 19/08 sur la capsule « le petrole » (moteur navigateur, meme
    # calcul de cadrage) : quatre plans sur six ne montraient QUE la grille du
    # sol ; le derrick, l'oleoduc et la coque du navire etaient invisibles. Le
    # defaut existe a l'identique ici, il n'avait simplement jamais ete
    # declenche -- aucune capsule rendue par Blender n'avait utilise `napper`.
    #
    # Le terrain reste dans la scene : il donne l'echelle. Il ne COMMANDE plus
    # le cadrage.
    cadrables = [o for o, v in poses if v != "napper"]
    if len(cadrables) != len(poses):
        j.fait(f"cadrage : {len(poses) - len(cadrables)} terrain(s) exclu(s) de la mesure")
    if not cadrables:
        cadrables = produits

    camera = a3.cadrer_sur(cadrables, marge=cadre["marge"],
                           ouverture=cadre["ouverture"],
                           direction=cadre["direction"],
                           images=images, balayage=cadre["balayage"])
    a3.haloter(taille=st.HALO_TAILLE, exposition=st.EXPOSITION)

    # La distance retenue est INSCRITE au journal. Un plan mal cadre doit se
    # diagnostiquer sur une trace, pas en relouant une machine pour regarder.
    try:
        recul = round(float((camera.location - camera.constraints[0].target.location).length), 2)
        j.fait(f"cadrage « {intention} » a {recul} unites")
    except Exception:  # noqa: BLE001
        j.fait(f"cadrage « {intention} »")
    return j.resume()

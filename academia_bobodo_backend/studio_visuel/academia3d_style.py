"""LE STYLE — une seule source, valable pour TOUTES les capsules.

POURQUOI CE FICHIER EXISTE, ET IL EST NE D'UNE QUESTION DE JOCELYN.
Apres quatre calibrations le 12/08, les huit reglages qui font l'esthetique
etaient dans `scene_oeufs.py` -- le fichier d'UNE scene. La scene suivante
aurait donc du les reinventer, et aurait derive. Or le cahier des charges
demande l'inverse : « grammaire visuelle constante d'un episode a l'autre ».
Des capsules dont chacune a son esthetique, c'est le meme defaut que des
capsules dont chacune a les memes formes -- en miroir.

LA REGLE QUI COMMANDE CE FICHIER :

    Le style s'exprime en RAPPORTS, pas en valeurs absolues.

`ARETE_SOL = 0.045` etait juste pour une grille de 220 unites en 46
divisions. Sur une grille de 60 unites, la meme valeur redonne les « cordes »
du premier essai. Une epaisseur d'arete n'a de sens que RELATIVEMENT a la
maille qu'elle dessine. C'est vrai de toutes les longueurs ; ce n'est vrai
d'aucune couleur ni d'aucune exposition.

CE QUI EST ICI, ET CE QUI N'Y EST PAS.

    ICI      ce qui doit etre IDENTIQUE d'une capsule a l'autre :
             palette, exposition, halo, densite du verre, proportions.

    PAS ICI  ce qui doit CHANGER a chaque sujet : quels objets, ou est la
             camera, combien d'exemplaires, a quel rythme. C'est la mise en
             scene, et c'est precisement ce que l'IA doit ecrire.

Si un jour une capsule a besoin d'une valeur differente de celles-ci, ce n'est
pas la capsule qu'il faut regler : c'est cette table, et alors toutes en
heritent.
"""

from __future__ import annotations

# ══ ABSOLUS — identiques pour toute capsule ══════════════════════════════

# L'ecran reste MAJORITAIREMENT NOIR et seuls quelques elements brillent.
# `style_reference.py` le dit depuis le 30/07 : « c'est le rapport qui fait le
# premium, pas l'intensite absolue ». Mesure du 12/08 : a -0,6 l'ecran restait
# clair et les aretes lisaient comme des cordes pales ; a -1,2 le noir domine
# et les memes aretes deviennent lumineuses.
EXPOSITION = -1.2

# Halo sur les emissifs. C'est lui qui separe « rendu 3D » de « image de
# synthese » a l'oeil.
HALO_TAILLE = 8

# La peau translucide. Trop forte, elle mange ses propres aretes -- et ce sont
# les aretes qui portent le style.
VERRE_FORCE = 1.2
VERRE_BORD = 1.6

# Emission des deux familles. La structure doit se lire ; le sujet doit gagner
# contre elle.
EMISSION_STRUCTURE = 3.2
EMISSION_SUJET = 9.0

# La lueur AFFLEURE, elle n'eclaire pas. A 9,0 elle noyait la moitie basse du
# cadre (troisieme calibration du 12/08).
CHALEUR_AFFLEUREMENT = 0.55


# ══ RAPPORTS — a multiplier par une longueur de la scene ═════════════════

# Epaisseur d'une arete de grille, en fraction du COTE D'UNE MAILLE.
# Mesure du 12/08 : 0,045 sur une maille de 4,8 unites, soit ~1/107. En deca
# l'arete disparait au loin, au-dela elle devient une corde.
ARETE_PAR_MAILLE = 0.0094

# Epaisseur d'une arete d'objet, en fraction de son RAYON. Un objet est petit
# a l'ecran : ses aretes doivent etre plus fines que celles du sol, sinon
# elles le remplissent.
ARETE_PAR_RAYON = 0.006


def arete_grille(cote: float, pas: int) -> float:
    """Epaisseur d'arete pour une grille, quelle que soit sa taille.

    C'est la fonction qui rend le style GENERAL. Elle transforme un rapport en
    longueur, en lisant la scene au lieu de supposer ses dimensions.
    """
    maille = float(cote) / max(int(pas), 1)
    return max(0.008, maille * ARETE_PAR_MAILLE)


def arete_objet(echelle: float) -> float:
    """Epaisseur d'arete pour un objet sculpte, proportionnelle a sa taille."""
    return max(0.004, float(echelle) * ARETE_PAR_RAYON)

#!/usr/bin/env python3
"""Fabrique la bibliotheque de contours SVG du Studio.

POURQUOI LES FABRIQUER PLUTOT QUE LES TELECHARGER. Un contour recupere sur
internet arrive avec sa licence, son auteur, et le doute qui va avec. Pour une
plateforme commerciale, chaque fichier devrait etre trace, verifie, renouvele.
Ceux-ci sont generes par des equations : ils nous appartiennent sans discussion,
ils sont deterministes, et ils pesent quelques kilo-octets.

CE QU'ILS SONT ET NE SONT PAS. Des formes GEOMETRIQUES evocatrices, pas des
planches anatomiques ni des cartes exactes. Un coeur stylise illustre « la
circulation », il n'enseigne pas la cardiologie. Le jour ou une capsule doit
montrer un organe avec exactitude, il faudra un contour valide par un medecin --
exactement comme les cas cliniques attendent leur relecture.

Usage : python3 fabriquer_contours.py [dossier]
"""

from __future__ import annotations

import math
import os
import sys

TAILLE = 512          # boite carree : le generateur met a l'echelle ensuite
EPAISSEUR = 0


def _chemin(points: list[tuple[float, float]]) -> str:
    """Un contour ferme. Les coordonnees SVG ont l'axe Y vers le BAS -- on
    l'inverse ici pour que les formes ne soient pas rendues a l'envers dans
    Blender."""
    d = f"M {points[0][0]:.2f} {TAILLE - points[0][1]:.2f}"
    for x, y in points[1:]:
        d += f" L {x:.2f} {TAILLE - y:.2f}"
    return d + " Z"


def _svg(chemins: list[str]) -> str:
    corps = "\n".join(
        f'  <path d="{d}" fill="none" stroke="#000000" stroke-width="3"/>'
        for d in chemins)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{TAILLE}" '
            f'height="{TAILLE}" viewBox="0 0 {TAILLE} {TAILLE}">\n{corps}\n</svg>\n')


def coeur() -> str:
    """Courbe cardioide classique. Pour la circulation, le rythme, la sante."""
    pts = []
    for i in range(240):
        t = i / 240 * 2 * math.pi
        x = 16 * math.sin(t) ** 3
        y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        pts.append((TAILLE / 2 + x * 13, TAILLE / 2 + y * 13))
    return _svg([_chemin(pts)])


def feuille() -> str:
    """Deux arcs qui se rejoignent, plus la nervure centrale.
    Pour l'agroalimentaire, la croissance, le vivant."""
    haut, bas = TAILLE * 0.90, TAILLE * 0.10
    pts = []
    for i in range(121):
        t = i / 120
        y = bas + (haut - bas) * t
        largeur = math.sin(t * math.pi) ** 0.75 * TAILLE * 0.24
        pts.append((TAILLE / 2 + largeur, y))
    for i in range(121):
        t = 1 - i / 120
        y = bas + (haut - bas) * t
        largeur = math.sin(t * math.pi) ** 0.75 * TAILLE * 0.24
        pts.append((TAILLE / 2 - largeur, y))
    nervure = f"M {TAILLE/2:.1f} {TAILLE - bas:.1f} L {TAILLE/2:.1f} {TAILLE - haut:.1f}"
    return _svg([_chemin(pts), nervure])


def goutte() -> str:
    """Pour l'eau, le carburant, le sang, la ressource."""
    pts = []
    for i in range(240):
        t = i / 240 * 2 * math.pi
        r = TAILLE * 0.26 * (1 - math.sin(t)) ** 0.55 if math.sin(t) < 0.999 else 0
        pts.append((TAILLE / 2 + r * math.cos(t), TAILLE * 0.42 + r * math.sin(t)))
    return _svg([_chemin(pts)])


def spirale() -> str:
    """Spirale logarithmique -- le nombre d'or, la croissance, la coquille.
    Pour l'art, l'architecture, les mathematiques."""
    pts = []
    for i in range(400):
        t = i / 400 * 4.2 * math.pi
        r = 3 * math.exp(0.17 * t)
        pts.append((TAILLE / 2 + r * math.cos(t), TAILLE / 2 + r * math.sin(t)))
    d = f"M {pts[0][0]:.2f} {TAILLE - pts[0][1]:.2f}"
    for x, y in pts[1:]:
        d += f" L {x:.2f} {TAILLE - y:.2f}"
    return _svg([d])


def amphore() -> str:
    """Profil de vase. Pour l'archeologie, l'histoire, le patrimoine."""
    profil = [(0.10, 0.05), (0.12, 0.12), (0.26, 0.30), (0.30, 0.52),
              (0.24, 0.68), (0.14, 0.78), (0.16, 0.88), (0.24, 0.95)]
    pts = [(TAILLE / 2 + w * TAILLE, h * TAILLE) for w, h in profil]
    pts += [(TAILLE / 2 - w * TAILLE, h * TAILLE) for w, h in reversed(profil)]
    return _svg([_chemin(pts)])


FORMES = {
    "coeur": (coeur, "medecine — circulation, rythme, sante"),
    "feuille": (feuille, "agroalimentaire — croissance, vivant"),
    "goutte": (goutte, "geographie, chimie — eau, ressource, fluide"),
    "spirale": (spirale, "art, architecture, mathematiques — nombre d'or"),
    "amphore": (amphore, "archeologie, histoire — patrimoine"),
}


def main() -> int:
    dossier = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.abspath(__file__))
    os.makedirs(dossier, exist_ok=True)
    for nom, (fabrique, usage) in FORMES.items():
        chemin = os.path.join(dossier, f"{nom}.svg")
        with open(chemin, "w", encoding="utf-8") as f:
            f.write(fabrique())
        print(f"{nom:10s} {os.path.getsize(chemin):5d} octets  — {usage}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

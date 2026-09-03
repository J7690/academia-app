#!/usr/bin/env python3
"""Contrôle le CONTENU des reçus PDF produits par `flutter test`.

    cd academia_app
    flutter test test/recu_pdf_test.dart      # produit les PDF
    python ../outils/verifier_recu_pdf.py     # vérifie ce qu'ils contiennent

Pourquoi ce script existe. Le 02/09/2026, une erreur de mise en page a fait
disparaître **tout le corps** du reçu : il ne restait que l'en-tête. Le test
Dart d'alors est passé — il ne regardait que le poids du fichier et les cinq
octets « %PDF- ». Le document était valide, du bon poids, et mutilé.

Le texte d'un PDF produit par le paquet `pdf` est rangé dans des flux
compressés. Dart ne sait pas les lire sans bibliothèque d'extraction ; PyMuPDF,
si. D'où ce complément : le test Dart déclare ce que chaque document DOIT
contenir (build/apercus_recu/controles.json), ce script lit le texte réellement
rendu et compare.

Sortie : 0 si tout est là, 1 sinon.
"""

from __future__ import annotations

import json
import sys
import unicodedata
from pathlib import Path

try:
    import pymupdf
except ImportError:  # pragma: no cover
    print("PyMuPDF est requis :  pip install pymupdf", file=sys.stderr)
    sys.exit(2)


DOSSIER = Path(__file__).resolve().parent.parent / "academia_app" / "build" / "apercus_recu"


def normaliser(t: str) -> str:
    """Le texte extrait d'un PDF n'a pas les mêmes espaces que la source.

    Les espaces fines, insécables et les retours à la ligne de mise en page
    varient ; on les ramène tous à une espace simple. On normalise aussi les
    formes Unicode (é composé vs précomposé), sans quoi une comparaison de
    chaînes échoue sur un texte pourtant identique à l'œil.
    """
    t = unicodedata.normalize("NFC", t)
    for espace in (" ", " ", " ", "\n", "\t"):
        t = t.replace(espace, " ")
    while "  " in t:
        t = t.replace("  ", " ")
    return t.strip()


def main() -> int:
    manifeste = DOSSIER / "controles.json"
    if not manifeste.exists():
        print(f"Aucun contrôle à faire : {manifeste} est absent.")
        print("Lancer d'abord :  flutter test test/recu_pdf_test.dart")
        return 2

    controles = json.loads(manifeste.read_text(encoding="utf-8"))
    fautes: list[str] = []
    verifies = 0

    for c in controles:
        chemin = DOSSIER / c["fichier"]
        if not chemin.exists():
            fautes.append(f"{c['fichier']} : fichier absent")
            continue

        with pymupdf.open(chemin) as doc:
            if doc.page_count != 1:
                fautes.append(f"{c['fichier']} : {doc.page_count} pages, une seule attendue")
            texte = normaliser("\n".join(p.get_text() for p in doc))

        for attendu in c["attendus"]:
            if normaliser(attendu) not in texte:
                fautes.append(f"{c['fichier']} : MANQUE « {attendu} »")
            else:
                verifies += 1

        for absent in c.get("absents", []):
            if normaliser(absent) in texte:
                fautes.append(f"{c['fichier']} : NE DEVRAIT PAS contenir « {absent} »")
            else:
                verifies += 1

    print(f"{len(controles)} document(s), {verifies} contrôle(s) satisfait(s).")
    if fautes:
        print(f"\n{len(fautes)} FAUTE(S) :")
        for f in fautes:
            print(f"  - {f}")
        return 1

    print("Tous les documents contiennent ce qu'ils doivent contenir.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

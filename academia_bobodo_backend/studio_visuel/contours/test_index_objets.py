#!/usr/bin/env python3
"""Banc d'essai de la selection des objets. Il tient en une regle et une liste.

POURQUOI CE FICHIER EXISTE.
L'index a rendu deux fois des objets hors sujet, et les deux fois le defaut
etait invisible a la lecture du code :

  1. (premiere version) on gardait les douze PREMIERS objets contenant le mot.
     « cerveau » rendait « a multicolored protein molecule ».
     Corrige par `score()` — pertinence, pas ordre d'arrivee.

  2. (05/09/2026) la recherche testait `mot in texte`, une sous-chaine :
        foie    -> « Liverpool FC logo »
        dent    -> « Toothless the white dragon »
        feuille -> « leafless, dead trees »
     Les deux derniers proposaient l'exact CONTRAIRE du terme demande.
     Corrige par `motif()` — un mot, pas une suite de lettres.

Une capsule ne dit jamais « je me suis trompe d'objet » : elle s'affiche. Ce
defaut ne peut donc etre attrape qu'ici, avant le rendu.

Usage :
    python test_index_objets.py          # la regle seule, sans l'index
    python test_index_objets.py --index  # verifie AUSSI index_objets.json
"""
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from construire_index_objets import (VOCABULAIRE, motif,  # noqa: E402
                                     normaliser, score)

# (description, mots cherches, doit-on la retenir, ce que le cas defend)
CAS = [
    # CE QUI DOIT ETRE REJETE — tous mesures dans l'index du 05/09.
    ("liverpool fc logo",             ["liver"],               False, "Liverpool n'est pas un foie"),
    ("a delivery truck",              ["liver"],               False, "delivery non plus"),
    ("toothless the white dragon",    ["tooth", "teeth"],      False, "toothless = SANS dent"),
    ("leafless dead trees",           ["leaf", "leaves"],      False, "leafless = SANS feuille"),
    ("rocket model",                  ["rock", "boulder"],     False, "une fusee n'est pas un rocher"),
    ("damascus dagger with a blade",  ["dam"],                 False, "Damascus n'est pas un barrage"),
    ("a toothbrush",                  ["tooth", "teeth"],      False, "une brosse a dents n'est pas une dent"),
    ("bridger wagner in white text",  ["bridge"],              False, "nom propre, pas un pont"),
    ("skullcandy headphones",         ["skull"],               False, "une marque, pas un crane"),
    # CE QUI DOIT PASSER — les flexions sont legitimes et frequentes.
    ("a volcano with fire",           ["volcano"],             True,  "le cas nominal"),
    ("lungs royalty free preview",    ["lung"],                True,  "pluriel regulier"),
    ("green leaves on a branch",      ["leaf", "leaves"],      True,  "pluriel irregulier, declare au vocabulaire"),
    ("coronavirus model",             ["virus", "coronavirus"], True, "compose soude, declare au vocabulaire"),
    ("a plant sprouting from ground", ["sprout"],              True,  "flexion verbale -ing"),
    ("atomic structure with spheres", ["atom"],                True,  "derivation -ic"),
    ("houses on a grassy field",      ["house"],               True,  "pluriel"),
    ("hydroelectric dam at sunset",   ["dam"],                 True,  "dam en mot entier reste legitime"),
    ("human teeth model",             ["tooth", "teeth"],      True,  "pluriel irregulier declare"),
]


def essayer_la_regle() -> int:
    echecs = 0
    for texte, mots, attendu, defend in CAS:
        obtenu = motif(mots).search(texte) is not None
        if obtenu != attendu:
            echecs += 1
            verbe = "RETENU a tort" if obtenu else "REJETE a tort"
            print(f"  ECHEC  {verbe} : « {texte} » pour {mots}\n         {defend}")
    print(f"regle : {len(CAS) - echecs}/{len(CAS)} conformes")
    return echecs


# (description, mots cherches, faut-il la retenir, ce que le cas defend)
# Ici c'est le SCORE qui tranche, pas la seule presence du mot : le referent
# est bien nomme, mais l'objet est de la nourriture, un logo ou un deguisement.
DETOURNES = [
    ("a brain sushi roll",          ["brain"],       False, "un sushi n'est pas un cerveau"),
    ("skull 38 logo",               ["skull"],       False, "un logotype n'est pas un crane"),
    ("a seeded loaf of bread",      ["seed"],        False, "du pain n'est pas une graine"),
    ("brain shaped wall sconce",    ["brain"],       False, "une applique murale non plus"),
    ("skull mask sculpture",        ["skull"],       False, "un masque non plus"),
    ("a brain in a glass jar",      ["brain"],       True,  "un vrai cerveau, meme en bocal"),
    ("a human heart",               ["human heart"], True,  "le cas nominal"),
    ("a volcano with fire",         ["volcano"],     True,  "le cas nominal"),
    # Le vocabulaire contient LUI-MEME des objets de ces categories : la
    # penalite ne doit pas les vider.
    ("a red apple fruit",           ["fruit"],       True,  "un fruit reste un fruit"),
    ("an open book on a table",     ["open book"],   True,  "un livre reste un livre"),
]


def essayer_le_score() -> int:
    echecs = 0
    for texte, mots, attendu, defend in DETOURNES:
        n = score(normaliser(texte), mots)
        if (n > 0) != attendu:
            echecs += 1
            verbe = "RETENU a tort" if n > 0 else "ECARTE a tort"
            print(f"  ECHEC  {verbe} (score {n:.1f}) : « {texte} »\n         {defend}")
    print(f"score : {len(DETOURNES) - echecs}/{len(DETOURNES)} conformes")
    return echecs


def essayer_l_index() -> int:
    """Chaque objet retenu porte-t-il VRAIMENT le mot de son terme ?

    C'est la meme regle, appliquee au fichier reellement embarque dans le
    moteur — parce qu'un index construit par une version anterieure du script
    s'installerait sans rien dire.
    """
    chemin = Path(__file__).parent / "index_objets.json"
    if not chemin.exists():
        print("index : absent — rien a verifier")
        return 0
    termes = json.loads(chemin.read_text(encoding="utf-8"))["termes"]
    echecs, total = 0, 0
    for terme, objets in termes.items():
        mots = VOCABULAIRE.get(terme)
        if not mots:
            print(f"  ECHEC  terme « {terme} » absent du vocabulaire")
            echecs += 1
            continue
        for o in objets:
            total += 1
            texte = normaliser(o["description"])
            if not motif(mots).search(texte):
                echecs += 1
                print(f"  ECHEC  {terme} : mot absent — « {o['description'][:56]} »")
            elif score(texte, mots) <= 0:
                # Le mot est la, mais l'objet est detourne (nourriture, logo,
                # deguisement). Un index construit par une version anterieure
                # du script en contiendrait encore.
                echecs += 1
                print(f"  ECHEC  {terme} : objet detourne — « {o['description'][:56]} »")
            # LE CHEMIN EVITE 60 Mo DE TELECHARGEMENT PAR POD. Son absence est
            # rattrapee au rendu, donc muette : elle se voit seulement ici.
            if not o.get("chemin"):
                echecs += 1
                print(f"  ECHEC  {terme} : sans chemin — {o['uid'][:8]}")
    print(f"index : {total} objets verifies sur {len(termes)} termes "
          f"({echecs} defaut(s))")
    return echecs


def main() -> int:
    echecs = essayer_la_regle() + essayer_le_score()
    if "--index" in sys.argv:
        echecs += essayer_l_index()
    print("TOUT PASSE" if echecs == 0 else f"{echecs} ECHEC(S)")
    return 1 if echecs else 0


if __name__ == "__main__":
    sys.exit(main())

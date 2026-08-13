"""Le preparateur reconnait-il une capsule COMPOSEE ?

POURQUOI CE FICHIER EXISTE.

Le 12/08 a 18h21, le travail 1396f11c « Poussee d'Archimede » est parti en
file avec `archetype = reseau` et AUCUN geste, alors que l'IA avait compose
cinq scenes (revolutionner, sculpter, extruder). La machine etait allumee et
allait rendre la video generique -- celle qu'on obtenait deja pour « la
sociologie » et « la germination ».

Cause : `preparer_un` reconnaissait une capsule au seul champ `archetype`.
Une capsule composee n'en porte pas : elle porte `gestes`. Elle etait donc
prise pour un storyboard de tableau et passee au traducteur, qui, ne trouvant
aucun `blocks`, rendait le repli neutre.

Rien n'avait echoue. Aucun message n'avait ete emis. C'est le SEPTIEME
endroit ou le meme defaut se cachait -- d'ou un test, et non un correctif de
plus. Les six premiers ont ete corriges sans qu'aucun ne laisse de trace
executable derriere lui.

    python test_preparateur.py
"""

from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import academia_scene  # noqa: E402
import depuis_storyboard  # noqa: E402
from studio_preparateur import est_deja_une_capsule  # noqa: E402


# La scene telle que l'Edge Function la produit reellement depuis le 12/08 :
# une intention, un sujet, des verbes en coordonnees. Pas d'archetype.
SCENE_COMPOSEE = {
    "id": "s1",
    "intention": "objet",
    "sujet": "Objet dans l'eau",
    "narration": "Un objet plonge dans l'eau subit une poussee vers le haut.",
    "duree_s": 14,
    "gestes": [
        {"verbe": "revolutionner", "role": "structure",
         "parametres": {"profil": [[1.2, 0], [1.2, 2.4], [1.1, 2.6]], "tours": 32}},
        {"verbe": "sculpter", "role": "sujet",
         "parametres": {"base": "galet", "echelle": 0.8, "facettes": 2,
                        "position": [0, 0, 1.2], "deformation": 0.06}},
    ],
}

SCENE_ARCHETYPE = {"id": "s1", "archetype": "flux", "narration": "Le sang circule."}

SCENE_TABLEAU = {
    "id": "s1", "title": "Definition",
    "blocks": [{"type": "text", "content": "La poussee d'Archimede"}],
}


def cas(nom: str, condition: bool, detail: str = "") -> bool:
    print(f"  {'OK  ' if condition else 'ECHEC'} {nom}" + (f" — {detail}" if detail else ""))
    return condition


def main() -> int:
    print("Reconnaissance d'une capsule par le preparateur\n")
    ok = True

    # 1. LE DEFAUT DU 12/08, EXACTEMENT.
    ok &= cas("une scene composee est reconnue comme capsule",
              est_deja_une_capsule([SCENE_COMPOSEE]) is True,
              "sinon elle part au traducteur et perd ses gestes")

    # 2. Le raccourci historique doit continuer de marcher.
    ok &= cas("une scene a archetype reste reconnue",
              est_deja_une_capsule([SCENE_ARCHETYPE]) is True)

    # 3. Un vrai storyboard de tableau doit ENCORE etre traduit : un etudiant
    #    peut basculer un cours ecrit pour le tableau vers la 3D.
    ok &= cas("un storyboard de tableau n'est PAS pris pour une capsule",
              est_deja_une_capsule([SCENE_TABLEAU]) is False,
              "sinon il ne serait plus jamais traduit")

    # 4. Les cas degenere ne doivent pas lever.
    ok &= cas("absence de scenes = pas une capsule",
              est_deja_une_capsule(None) is False and est_deja_une_capsule([]) is False)
    ok &= cas("scenes illisibles = pas une capsule",
              est_deja_une_capsule(["texte", 42, None]) is False)

    # 5. LA CONSEQUENCE MESUREE : montrer que le mauvais chemin detruit bien la
    #    composition. Sans cela, on corrige une detection sans savoir ce qu'elle
    #    protegeait.
    traduit = depuis_storyboard.convertir(
        {"titre": "Poussee d'Archimede", "scenes": [SCENE_COMPOSEE]},
        discipline="", autoriser_images=False)
    traduit = academia_scene.normaliser(traduit)
    perdus = not traduit["scenes"][0].get("gestes")
    ok &= cas("le traducteur DETRUIT bien les gestes (c'est ce qu'on evite)",
              perdus is True,
              f"archetype obtenu : {traduit['scenes'][0].get('archetype')!r}")

    # 6. LE BON CHEMIN : la composition survit a la normalisation, et y survit
    #    DEUX FOIS (LWS normalise, puis le pod re-normalise).
    droit = academia_scene.normaliser(
        {"titre": "Poussee d'Archimede", "scenes": [SCENE_COMPOSEE]})
    deux_fois = academia_scene.normaliser(droit)
    s = deux_fois["scenes"][0]
    ok &= cas("la composition survit a deux normalisations",
              len(s.get("gestes") or []) == 2,
              f"{len(s.get('gestes') or [])} geste(s) conserve(s)")
    ok &= cas("l'intention et le sujet survivent aussi",
              s.get("intention") == "objet" and s.get("sujet") == "Objet dans l'eau")
    ok &= cas("une scene composee ne porte PAS d'archetype",
              s.get("archetype") == "",
              "un archetype non vide ferait reprendre le raccourci au rendu")

    print("\n" + ("Tous les cas passent." if ok else "AU MOINS UN CAS ECHOUE."))
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())

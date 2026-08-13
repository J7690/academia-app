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
_CADRAGE = {
    # marge : l'air autour du sujet. direction : d'ou l'on regarde.
    "objet":       dict(marge=1.15, ouverture=2.2, direction=(0.18, -1.0, 0.30)),
    "processus":   dict(marge=1.25, ouverture=2.8, direction=(0.30, -1.0, 0.34)),
    "comparaison": dict(marge=1.22, ouverture=3.5, direction=(0.05, -1.0, 0.22)),
    "structure":   dict(marge=1.20, ouverture=3.0, direction=(0.26, -1.0, 0.42)),
    "echelle":     dict(marge=1.35, ouverture=4.0, direction=(0.22, -1.0, 0.50)),
    "flux":        dict(marge=1.28, ouverture=2.6, direction=(0.34, -1.0, 0.30)),
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
    objet = style.texte_3d(texte, taille=float(p.get("taille", 1.2)),
                           position=tuple(p.get("position", (0, 0, 0))))
    style.tenir_dans(objet, float(p.get("largeur_max", 7.0)))
    return objet


GESTES = {
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

    if geste.get("verre", role == "sujet"):
        a3.vitrer(objet, force=st.VERRE_FORCE, densite_bord=st.VERRE_BORD)

    if geste.get("verbe") == "napper":
        epaisseur = st.arete_grille(float(geste.get("parametres", {}).get("cote", 190.0)),
                                    int(geste.get("parametres", {}).get("pas", 46)))
        a3.filairer(objet, epaisseur=epaisseur, emission=emission)
    else:
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

    produits = []
    for rang, geste in enumerate(scene.get("gestes") or []):
        verbe = str(geste.get("verbe") or "")
        parametres = geste.get("parametres") or {}
        if verbe not in GESTES:
            j.degrade(f"geste {rang} : verbe inconnu « {verbe} » — geste ignore")
            continue
        try:
            objet = GESTES[verbe](parametres, j)
            _habiller(objet, geste, j)
            produits.append(objet)
            j.fait(f"{verbe}({', '.join(sorted(parametres))})")
        except Exception as e:  # noqa: BLE001
            # ON NE REMPLACE PAS EN SILENCE. `validate_capsule.ts:74`
            # substituait `reseau` a toute forme inconnue : c'est ce qui a rendu
            # deux sujets sans rapport visuellement identiques.
            j.degrade(f"geste {rang} « {verbe} » a echoue : {type(e).__name__}: {e}")
            j.degrade(traceback.format_exc().strip().splitlines()[-1])

    if not produits:
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
            produits.append(objet)

    cadre = _CADRAGE[intention]
    # ON CADRE SUR CE QUI EXISTE. `produits` porte les objets reellement crees ;
    # `cadrer_sur` mesure leur boite englobante et en deduit la distance.
    camera = a3.cadrer_sur(produits, marge=cadre["marge"],
                           ouverture=cadre["ouverture"],
                           direction=cadre["direction"])
    a3.haloter(taille=st.HALO_TAILLE, exposition=st.EXPOSITION)

    # La distance retenue est INSCRITE au journal. Un plan mal cadre doit se
    # diagnostiquer sur une trace, pas en relouant une machine pour regarder.
    try:
        recul = round(float((camera.location - camera.constraints[0].target.location).length), 2)
        j.fait(f"cadrage « {intention} » a {recul} unites")
    except Exception:  # noqa: BLE001
        j.fait(f"cadrage « {intention} »")
    return j.resume()

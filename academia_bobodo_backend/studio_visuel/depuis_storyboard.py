"""Convertit un storyboard Smart Whiteboard en capsule 3D du Studio visuel.

POURQUOI CE MODULE EXISTE.
Les deux chaines produisent une video verticale a partir d'un cours, mais elles
ne parlent pas la meme langue :

    Smart Whiteboard   scenes -> blocs (title, paragraph, definition, formula,
                       exercise, correction), chacun avec son texte, sa
                       narration, son emphase et ses mots-cles.
    Studio visuel      scenes -> un ARCHETYPE geometrique par scene (reseau,
                       flux, strates, comparaison, titre, terrain, silhouette,
                       chronologie, carte, ondes, genere), une narration, une
                       duree, un accent, un mouvement de camera.

Sans traduction, l'etudiant ne peut pas choisir : la generation par IA ne
produit qu'un seul des deux formats. Ce module est le pont, et il ne demande
aucune generation supplementaire -- donc aucun credit de plus.

CE QU'IL PRESERVE, ET C'EST L'ESSENTIEL.
La NARRATION, mot pour mot. C'est elle qui porte le cours, et c'est elle qui
commandera la duree de chaque scene -- `narration.py` la mesurera sur la voix
reellement synthetisee. Le choix du visuel change la forme, jamais le propos.

CE QU'IL PERD, ET IL FAUT LE SAVOIR.
Le texte ecrit au tableau et ses annotations. Une capsule 3D ne s'ecrit pas :
elle se regarde. Les mots-cles servent donc a nourrir le sujet des scenes
`titre` et `genere`, mais aucun bloc n'est reproduit tel quel.
"""

from __future__ import annotations

import re
from typing import Any, Dict, List, Optional

import academia_scene

# Quel archetype pour quel type de bloc dominant. Ce n'est pas decoratif :
# c'est ce qui fait qu'une scene RACONTE au lieu d'illustrer a cote.
#
#   title       -> `titre`       le sujet EST l'objet
#   definition  -> `titre`       un terme et sa definition, deux lignes
#   formula     -> `titre`       une formule se rend en geometrie lumineuse
#   exercise    -> `comparaison` deux voies, on en designe une
#   correction  -> `flux`        une suite d'etapes qui menent au resultat
#   paragraph   -> depend de la discipline
PAR_TYPE = {
    "title": "titre",
    "definition": "titre",
    "formula": "titre",
    "graph": "ondes",
    "exercise": "comparaison",
    "correction": "flux",
}

# Le rythme d'une capsule : on alterne. Deux `titre` de suite donnent une
# capsule plate, et l'analyse des references montre qu'aucune ne repete deux
# fois la meme forme d'affilee.
ACCENTS = ("or", "vert", "orange", "rouge")
CAMERAS = ("avance", "orbite", "montee", "recul")


def _mots_cles(scene: Dict[str, Any]) -> List[str]:
    mots: List[str] = []
    for bloc in scene.get("blocks") or []:
        if not isinstance(bloc, dict):
            continue
        for m in bloc.get("key_words") or []:
            if isinstance(m, str) and m.strip():
                mots.append(m.strip())
    return mots


def _narration(scene: Dict[str, Any]) -> str:
    """La narration de la scene, recollee A PARTIR DES BLOCS.

    L'ORDRE DE PREFERENCE N'EST PAS ANODIN, ET UNE PREMIERE VERSION L'AVAIT
    INVERSE. Le storyboard v3 porte DEUX narrations :

        `scene.narration`  un resume, court -- 99 mots sur ce cours ;
        `bloc.narration`   le discours reel  -- 206 mots sur le meme cours,
                           ce qui correspond aux 88,1 s de parole mesurees.

    Prendre le champ de scene parce qu'il existe revenait donc a jeter plus de
    la moitie du cours, silencieusement : la capsule 3D aurait dit deux fois
    moins de choses que la version tableau, pour le meme sujet et le meme prix.

    On recolle donc les blocs dans l'ordre, et on ne retombe sur le resume que
    si aucun bloc ne parle.
    """
    morceaux = []
    for bloc in scene.get("blocks") or []:
        if isinstance(bloc, dict):
            t = str(bloc.get("narration") or "").strip()
            if t:
                morceaux.append(t)
    if morceaux:
        return " ".join(morceaux)
    return str(scene.get("narration") or "").strip()


def _type_dominant(scene: Dict[str, Any]) -> str:
    """Le type de bloc qui donne son caractere a la scene.

    On privilegie le titre s'il existe, sinon le type le plus represente : une
    scene avec un exercice et trois paragraphes reste un exercice.
    """
    types = [b.get("type") for b in (scene.get("blocks") or [])
             if isinstance(b, dict) and b.get("type")]
    if not types:
        return "paragraph"
    for prioritaire in ("exercise", "correction", "formula", "definition", "title"):
        if prioritaire in types:
            return prioritaire
    return max(set(types), key=types.count)


def _sujet_visuel(scene: Dict[str, Any], titre_cours: str) -> str:
    """Le sujet d'une image generee, en anglais et en termes de MATIERE.

    Le modele d'images ne comprend pas « la loi normale » ; il comprend des
    textures, des lumieres et des volumes. On lui donne donc les mots-cles de
    la scene, que la grammaire de `generateur_ia.STYLE` habillera.
    """
    mots = _mots_cles(scene)
    base = ", ".join(mots[:4]) if mots else (scene.get("title") or titre_cours)
    return f"{base}, abstract scientific illustration, macro detail"


def convertir(storyboard: Dict[str, Any], discipline: str = "",
              autoriser_images: bool = True) -> Dict[str, Any]:
    """Rend une capsule du Studio a partir d'un storyboard du Whiteboard.

    `discipline` oriente le choix des archetypes via `academia_scene.DISCIPLINES`.
    `autoriser_images` : mettre a False interdit l'archetype `genere`, qui exige
    un GPU et dont la cause d'echec n'est pas encore etablie -- voir
    docs/STUDIO_VISUEL_REPRISE_2026-08-05.md.

    La capsule renvoyee n'est PAS normalisee : `academia_scene.normaliser` s'en
    charge, et `narration.py` remplacera ensuite chaque duree estimee par la
    duree MESUREE sur la voix. C'est la regle d'or du projet : la voix commande
    l'image.
    """
    scenes_source = [s for s in (storyboard.get("scenes") or []) if isinstance(s, dict)]
    titre_cours = str(storyboard.get("title") or storyboard.get("subject") or "Cours").strip()

    conseilles = list(academia_scene.archetypes_pour(discipline))
    if not autoriser_images:
        conseilles = [a for a in conseilles if a not in academia_scene.ARCHETYPES_IA]
    if not conseilles:
        conseilles = ["titre", "reseau", "flux", "strates"]

    scenes: List[Dict[str, Any]] = []
    precedent: Optional[str] = None

    for rang, source in enumerate(scenes_source):
        narration = _narration(source)
        if not narration:
            # Une scene sans narration ne dure rien et ne dit rien : on la
            # laisse tomber plutot que de produire du vide sonore.
            continue

        archetype = PAR_TYPE.get(_type_dominant(source)) or conseilles[rang % len(conseilles)]

        # Jamais deux fois la meme forme d'affilee : c'est ce qui distingue une
        # capsule d'un diaporama.
        if archetype == precedent:
            suivants = [a for a in conseilles if a != archetype] or ["reseau"]
            archetype = suivants[rang % len(suivants)]
        precedent = archetype

        scene: Dict[str, Any] = {
            "id": str(source.get("id") or f"s{rang + 1}"),
            "archetype": archetype,
            "titre": str(source.get("title") or "").strip(),
            "narration": narration,
            "accent": ACCENTS[rang % len(ACCENTS)],
            "camera": CAMERAS[rang % len(CAMERAS)],
            "parametres": {},
        }

        if archetype == "titre":
            mots = _mots_cles(source)
            scene["parametres"] = {
                "texte": (mots[0] if mots else scene["titre"] or titre_cours)[:28],
                "texte_second": (mots[1] if len(mots) > 1 else "")[:36],
            }
        elif archetype == "genere":
            scene["parametres"] = {
                "sujet": _sujet_visuel(source, titre_cours),
                "mode": "mouvement",
                "sens": "zoom",
            }

        scenes.append(scene)

    if not scenes:
        # Degradation gracieuse : plutot une capsule d'une scene qu'un echec.
        scenes = [{
            "id": "s1", "archetype": "titre", "titre": titre_cours,
            "narration": titre_cours, "accent": "or", "camera": "avance",
            "parametres": {"texte": titre_cours[:28], "texte_second": ""},
        }]

    return {
        "capsule_id": re.sub(r"[^a-z0-9_]+", "_", titre_cours.lower())[:40] or "capsule",
        "titre": titre_cours,
        "format": {"largeur": 1080, "hauteur": 1920, "fps": 25},
        "scenes": scenes,
    }

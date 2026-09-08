"""`convoquer` — faire venir l'OBJET DU SUJET dans la scene.

## Le verbe qui manquait

Le moteur savait deja fabriquer des formes : `silhouetter`, `revolutionner`,
`extruder`, `sculpter`, `napper`, `ecrire`. Six verbes, et pas un seul capable
de faire venir un objet qui EXISTE.

Consequence mesuree le 05/09/2026, capsule « le volcan » : la narration disait
« le magma s'accumule dans une chambre magmatique », puis « formant le cone
volcanique » — et l'image montrait **la meme lentille filaire dans les trois
scenes**. Au moment du mot « cone », l'ecran affichait une forme aplatie.

La cause n'etait pas le style : filaire bleu, grille, brume, sous-titres, tout
etait conforme a la reference. C'est que `silhouetter` prend des SEGMENTS —
des coordonnees — et qu'aucun modele de langue ne dessine un volcan point par
point. Faute de savoir tracer, il produit une forme neutre.

La documentation du Studio nommait deja ce manque : « `matiere_feu` ne doit pas
etre branchee tant que `convoquer` n'existe pas ». Le voici.

## Ce qu'il fait, et ce qu'il ne fait pas

Il cherche un terme dans `contours/index_objets.json` — 69 termes, 796 objets
d'Objaverse dont la licence a ete verifiee un par un (`by`, `by-sa`, `cc0` ;
324 candidats ecartes) — telecharge le maillage, l'importe, le normalise a la
taille demandee, et laisse le style du Studio l'habiller.

Il ne genere rien, ne devine rien, et **ne remplace aucun verbe existant**. Un
terme absent de l'index rend `None` : l'appelant retombe alors sur les
archetypes geometriques, qui restent la bonne reponse pour l'abstrait — on ne
modelise pas « la sociologie ».

## Pourquoi le cache est sur LWS et non dans le pod

Un pod vit dix minutes et meurt. Retelecharger le meme cerveau a chaque capsule
serait payer deux fois : en temps d'attente pour l'etudiant, et en bande
passante. Le cache vit donc a cote du preparateur, qui prepare justement la
capsule AVANT que la machine ne soit louee.
"""
from __future__ import annotations

import json
import os
import shutil
import unicodedata
import urllib.request
from pathlib import Path

# Le depot officiel d'Objaverse. Le chemin d'un objet se deduit de son uid,
# via `object-paths.json.gz` — mais ce fichier pese 60 Mo pour 800 000 entrees.
# On ne le charge donc qu'une fois, et seulement si un objet est vraiment
# demande : la plupart des capsules tapent dans le cache.
BASE_HF = "https://huggingface.co/datasets/allenai/objaverse/resolve/main/"
CHEMINS_URL = BASE_HF + "object-paths.json.gz"

DOSSIER_INDEX = Path(__file__).parent / "contours" / "index_objets.json"
CACHE = Path(os.environ.get("STUDIO_CACHE_OBJETS",
                            Path.home() / ".cache" / "academia" / "objets"))

_index = None
_chemins = None


def _sans_accents(t: str) -> str:
    return "".join(c for c in unicodedata.normalize("NFD", t.lower())
                   if unicodedata.category(c) != "Mn")


def _charger_index() -> dict:
    global _index
    if _index is None:
        if not DOSSIER_INDEX.exists():
            _index = {}
        else:
            _index = json.loads(DOSSIER_INDEX.read_text(encoding="utf-8")).get("termes", {})
    return _index


def chercher(terme: str) -> list[dict]:
    """Rend les objets connus pour ce terme, du plus au moins pertinent.

    La recherche est tolerante : « les volcans » trouve « volcan ». Elle
    n'invente rien — pas de synonymes devines, pas de rapprochement flou.
    Un terme inconnu rend une liste vide, et c'est une reponse valable.
    """
    index = _charger_index()
    if not index:
        return []
    cle = _sans_accents(terme).strip()
    if cle in index:
        return index[cle]
    # Un mot du terme suffit : « chambre magmatique » -> « magma » n'existe pas,
    # mais « le volcan en eruption » -> « volcan » oui.
    mots = [m for m in cle.split() if len(m) > 3]
    for m in mots:
        if m in index:
            return index[m]
        singulier = m[:-1] if m.endswith("s") else m
        if singulier in index:
            return index[singulier]
    return []


def _charger_chemins() -> dict:
    global _chemins
    if _chemins is None:
        import gzip
        import io
        with urllib.request.urlopen(CHEMINS_URL, timeout=300) as r:
            _chemins = json.load(gzip.GzipFile(fileobj=io.BytesIO(r.read())))
    return _chemins


def telecharger(uid: str, chemin: str | None = None) -> Path | None:
    """Rend le fichier local du maillage, en le telechargeant si besoin.

    `chemin` est le chemin relatif de l'objet chez Objaverse, tel qu'inscrit
    dans l'index. LE FOURNIR EVITE 60 Mo DE TELECHARGEMENT.

    Sans lui, il faut charger `object-paths.json.gz` — 800 000 entrees, 60 Mo —
    uniquement pour traduire un uid en chemin. Sur le pod, cela tombe dans la
    boucle etudiant : la machine vit une dizaine de minutes et meurt, donc
    aucun cache ne survit, et chaque capsule repaierait le meme transfert.

    Resoudre le chemin est un travail de CONSTRUCTION D'INDEX, fait une fois
    hors ligne (`construire_index_objets.py`, etape 5). Le repli reste en place
    pour un index ancien, ou l'entree n'a pas encore de chemin.

    Ne leve pas : un objet indisponible ne doit pas faire perdre sa capsule a
    l'etudiant. La degradation gracieuse est une regle du depot, pas une
    politesse.
    """
    CACHE.mkdir(parents=True, exist_ok=True)
    local = CACHE / f"{uid}.glb"
    if local.exists() and local.stat().st_size > 0:
        return local
    try:
        rel = chemin
        if not rel:
            print(f"[convoquer] {uid[:8]} sans chemin dans l'index — "
                  f"repli sur object-paths (60 Mo)")
            rel = _charger_chemins().get(uid)
        if not rel:
            return None
        provisoire = local.with_suffix(".part")
        with urllib.request.urlopen(BASE_HF + rel, timeout=300) as r, \
                open(provisoire, "wb") as f:
            shutil.copyfileobj(r, f)
        # Renomme seulement une fois complet : un telechargement interrompu ne
        # doit pas laisser un fichier tronque que le cache croira valide.
        provisoire.replace(local)
        return local
    except Exception as e:  # noqa: BLE001
        print(f"[convoquer] {uid} indisponible : {str(e)[:90]}")
        return None


def convoquer(terme: str, taille: float = 2.0, position=(0.0, 0.0, 0.0),
              nom: str | None = None, journal=None):
    """Fait venir l'objet du sujet dans la scene Blender ouverte.

    Rend l'objet Blender, ou `None` si rien de convenable n'existe — auquel cas
    l'appelant DOIT le dire plutot que de livrer une forme decorative. C'est
    tout le defaut qu'on corrige : la capsule sortait quand meme, et l'image
    affirmait quelque chose de faux.
    """
    candidats = chercher(terme)
    if not candidats:
        if journal:
            journal(f"convoquer: aucun objet connu pour « {terme} »")
        return None

    import bpy  # importe ici : ce module est lisible hors de Blender

    for candidat in candidats[:4]:      # on essaie les meilleurs, pas tous
        fichier = telecharger(candidat["uid"], candidat.get("chemin"))
        if not fichier:
            continue
        avant = set(bpy.data.objects)
        try:
            bpy.ops.import_scene.gltf(filepath=str(fichier))
        except Exception as e:  # noqa: BLE001
            if journal:
                journal(f"convoquer: import impossible ({str(e)[:60]})")
            continue
        nouveaux = [o for o in set(bpy.data.objects) - avant if o.type == "MESH"]
        if not nouveaux:
            continue

        # Un fichier glTF rend souvent plusieurs morceaux : on les reunit pour
        # que le style s'applique a UN objet, pas a une dizaine.
        bpy.ops.object.select_all(action="DESELECT")
        for o in nouveaux:
            o.select_set(True)
        bpy.context.view_layer.objects.active = nouveaux[0]
        if len(nouveaux) > 1:
            bpy.ops.object.join()
        objet = bpy.context.view_layer.objects.active
        objet.name = nom or f"objet_{_sans_accents(terme).replace(' ', '_')}"

        # `dimensions` vaut zero tant que la scene n'est pas reevaluee — piege
        # deja paye, cf. style_reference.py:214.
        bpy.context.view_layer.update()
        plus_grand = max(objet.dimensions) if objet.dimensions else 0.0
        if plus_grand > 0:
            f = taille / plus_grand
            objet.scale = (f, f, f)
        objet.location = tuple(position)
        bpy.context.view_layer.update()

        if journal:
            journal(f"convoquer: « {terme} » -> {candidat['uid'][:8]} "
                    f"({candidat['licence']}) — {candidat['description'][:60]}")
        return objet

    if journal:
        journal(f"convoquer: aucun objet exploitable pour « {terme} »")
    return None


# L'ATTRIBUTION N'EST PAS FACULTATIVE.
#
# 87,8 % des objets sont en `by` : leur licence EXIGE de citer l'auteur. Cette
# fonction rend la mention a incruster au generique — l'oublier ferait d'une
# ressource libre une infraction.
def attribution(termes: list[str]) -> str:
    index = _charger_index()
    uids = []
    for t in termes:
        for c in chercher(t)[:1]:
            uids.append(c["uid"][:8])
    if not uids:
        return ""
    return ("Modeles 3D : Objaverse (CC-BY) — "
            + ", ".join(sorted(set(uids))))

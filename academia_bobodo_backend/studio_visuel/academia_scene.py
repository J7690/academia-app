"""Academia Scene Definition — le contrat entre le storyboard et le moteur 3D.

Le Smart Whiteboard (ou un administrateur) decrit une capsule ; ce module la
valide et la normalise ; le generateur la transforme en scene Blender.

TROIS REGLES HERITEES DU PROJET, et elles ne sont pas negociables.

1. LA VOIX COMMANDE L'IMAGE. C'est la regle d'or du Smart Whiteboard :
   `needed = max(scene_elapsed, narration, MIN_SCENE_SEC)`. Une scene dure au
   moins le temps de sa narration, sinon la phrase est coupee. Ici, une duree
   absente est DEDUITE du nombre de mots, jamais l'inverse.

2. ON NETTOIE, ON NE REJETTE PAS. Meme principe que `validate.ts` cote Edge
   Function : un storyboard imparfait doit produire une video imparfaite, pas
   une erreur. L'etudiant a paye ; le rejeter lui fait perdre ses credits ET
   sa video.

3. AUCUN ASSET. Tous les archetypes sont procedureaux. C'est ce qui permet de
   produire une capsule pour 0,58 $ sans avoir a modeliser quoi que ce soit --
   et ce qui distingue la famille « abstraite » de la famille « mecanique »,
   qui elle demandera des semaines de modelisation.
"""

from __future__ import annotations

# Debit mesure sur la chaine Smart Whiteboard : ~150 mots/minute a
# TTS_SPEED = 0.88. Sert a deduire une duree d'une narration.
MOTS_PAR_SECONDE = 2.5

# Bornes reprises de `validate.ts` cote Edge Function, pour que les deux
# chaines ne divergent pas.
DUREE_MIN_S = 3.0
DUREE_MAX_S = 25.0
SCENES_MAX = 7
DUREE_TOTALE_MAX_S = 150.0

# `titre` et `terrain` viennent de l'analyse des references mathoholic : elles
# ne dessinent pas un schema a cote du propos, elles rendent LE PROPOS en
# geometrie lumineuse. C'est `titre` qui rend le studio universel -- une
# formule, un mot, un symbole, une note : tous les themes passent par la.
ARCHETYPES = ("reseau", "flux", "strates", "comparaison", "titre", "terrain",
              "silhouette", "chronologie", "carte", "ondes")

# Quel archetype pour quelle discipline. Ce n'est pas un catalogue decoratif :
# c'est la reponse a « peu importe le sujet ». Un theme n'est pas une forme,
# c'est un CHOIX DE FORMES parmi les neuf.
#
# `strates` EST la stratigraphie archeologique. `flux` EST la circulation
# sanguine autant que la route de la soie. `silhouette` avale tout le reste :
# un organe, un os, un pays, un instrument, une feuille, un plan, un symbole.
DISCIPLINES = {
    "medecine": ("silhouette", "flux", "comparaison", "ondes"),
    "archeologie": ("strates", "chronologie", "silhouette", "carte"),
    "histoire": ("chronologie", "carte", "comparaison", "reseau"),
    "geographie": ("carte", "terrain", "flux", "strates"),
    "religion": ("silhouette", "chronologie", "reseau", "terrain"),
    "art": ("silhouette", "titre", "comparaison", "strates"),
    "musique": ("ondes", "flux", "silhouette", "titre"),
    "agroalimentaire": ("flux", "silhouette", "strates", "carte"),
    "mathematiques": ("titre", "reseau", "flux", "strates"),
    "physique": ("ondes", "flux", "titre", "comparaison"),
    "chimie": ("reseau", "flux", "silhouette", "titre"),
    "architecture": ("silhouette", "strates", "titre", "terrain"),
    "orientation": ("titre", "reseau", "comparaison", "strates", "flux"),
}


def archetypes_pour(discipline: str) -> tuple[str, ...]:
    """Les formes conseillees pour une discipline. Rien n'interdit les autres :
    c'est une aide a l'ecriture, pas une contrainte."""
    return DISCIPLINES.get(str(discipline or "").strip().lower(), ARCHETYPES[:4])

ACCENTS = {
    "orange": (1.0, 0.32, 0.04, 1.0),
    "rouge": (1.0, 0.09, 0.02, 1.0),
    "vert": (0.16, 0.95, 0.42, 1.0),
    "or": (1.0, 0.72, 0.16, 1.0),
}

CAMERAS = ("orbite", "avance", "montee", "recul")


def _mots(texte: str) -> int:
    return len([m for m in str(texte or "").split() if m.strip()])


def duree_depuis_narration(narration: str) -> float:
    """La narration fixe la duree. Un texte vide retombe sur le minimum plutot
    que sur zero : une scene de duree nulle casse le rendu."""
    secondes = _mots(narration) / MOTS_PAR_SECONDE
    return max(DUREE_MIN_S, min(DUREE_MAX_S, round(secondes + 0.8, 2)))


def _nettoyer_scene(brut: dict, rang: int, alertes: list[str]) -> dict:
    """Nettoie une scene et INSCRIT chaque correction dans `alertes`.

    Une correction silencieuse est pire que la correction elle-meme : l'audit
    du 27/07 a montre qu'un defaut d'affichage d'erreur peut rendre tout
    diagnostic impossible pendant une session entiere.
    """
    identifiant = str(brut.get("id") or f"s{rang + 1}")

    archetype = str(brut.get("archetype") or "").strip().lower()
    if archetype not in ARCHETYPES:
        # On ne rejette pas : le reseau est l'archetype le plus neutre, il
        # illustre a peu pres n'importe quel propos sans mentir.
        alertes.append(f"{identifiant}:archetype_{archetype or 'absent'}_remplace_par_reseau")
        archetype = "reseau"

    narration = str(brut.get("narration") or "").strip()
    if not narration:
        alertes.append(f"{identifiant}:narration_absente_duree_minimale")

    duree = brut.get("duree_s")
    if not isinstance(duree, (int, float)) or duree <= 0:
        duree = duree_depuis_narration(narration)
    else:
        duree = max(DUREE_MIN_S, min(DUREE_MAX_S, float(duree)))

    # Une duree MESUREE sur la voix reellement synthetisee ne se discute pas.
    #
    # PIEGE EVITE DE JUSTESSE : sans ce garde, le pod re-normalisait la capsule
    # calee par LWS et remplacait chaque duree mesuree par mon estimation. Sur
    # `monde`, 3,32 s mesurees seraient redevenues 3,6 s -- et l'ecart, cumule
    # scene apres scene, aurait desynchronise la voix de l'image sur toute la
    # capsule. `normaliser` doit etre idempotente.
    mesuree = bool(brut.get("mesuree"))

    besoin = duree_depuis_narration(narration) if narration else 0.0
    if not mesuree and besoin > duree:
        alertes.append(f"{identifiant}:duree_{duree}s_portee_a_{besoin}s_par_la_narration")
        duree = min(DUREE_MAX_S, besoin)

    accent = str(brut.get("accent") or "orange").strip().lower()
    if accent not in ACCENTS:
        if accent and accent != "orange":
            alertes.append(f"{identifiant}:accent_{accent}_inconnu_remplace_par_orange")
        accent = "orange"

    camera = str(brut.get("camera") or "orbite").strip().lower()
    if camera not in CAMERAS:
        if camera and camera != "orbite":
            alertes.append(f"{identifiant}:camera_{camera}_inconnue_remplacee_par_orbite")
        camera = "orbite"

    parametres = brut.get("parametres")
    if not isinstance(parametres, dict):
        parametres = {}

    return {
        "id": identifiant,
        "archetype": archetype,
        "titre": str(brut.get("titre") or "").strip(),
        "narration": narration,
        "duree_s": round(duree, 2),
        "accent": accent,
        "camera": camera,
        "parametres": parametres,
        "mesuree": mesuree,
    }


def normaliser(capsule: dict) -> dict:
    """Prend une definition brute et en rend une utilisable, toujours.

    Renvoie aussi `avertissements` : ce qui a du etre corrige. Le silence sur
    une correction est pire que la correction elle-meme -- l'audit du 27/07 a
    montre qu'un defaut d'affichage d'erreur peut rendre tout diagnostic
    impossible pendant une session entiere.
    """
    avertissements: list[str] = []

    if not isinstance(capsule, dict):
        capsule = {}
        avertissements.append("definition_illisible_remplacee_par_defaut")

    format_brut = capsule.get("format")
    if not isinstance(format_brut, dict):
        format_brut = {}
    largeur = int(format_brut.get("largeur") or 1080)
    hauteur = int(format_brut.get("hauteur") or 1920)
    fps = int(format_brut.get("fps") or 25)
    if fps not in (24, 25, 30):
        avertissements.append(f"fps_{fps}_ramene_a_25")
        fps = 25

    scenes_brutes = capsule.get("scenes")
    if not isinstance(scenes_brutes, list) or not scenes_brutes:
        scenes_brutes = [{"archetype": "reseau", "narration": ""}]
        avertissements.append("aucune_scene_une_scene_par_defaut")

    if len(scenes_brutes) > SCENES_MAX:
        # Preserve la DERNIERE scene : c'est le recapitulatif, et le perdre
        # laisse la capsule sans conclusion. Meme regle que validate.ts.
        avertissements.append(f"{len(scenes_brutes)}_scenes_ramenees_a_{SCENES_MAX}")
        scenes_brutes = scenes_brutes[: SCENES_MAX - 1] + [scenes_brutes[-1]]

    scenes = [_nettoyer_scene(s if isinstance(s, dict) else {}, i, avertissements)
              for i, s in enumerate(scenes_brutes)]

    total = sum(s["duree_s"] for s in scenes)
    if total > DUREE_TOTALE_MAX_S:
        # Ecretage PROPORTIONNEL : reduire une seule scene deformerait le
        # rythme. On rabote tout le monde du meme facteur.
        facteur = DUREE_TOTALE_MAX_S / total
        for s in scenes:
            s["duree_s"] = max(DUREE_MIN_S, round(s["duree_s"] * facteur, 2))
        avertissements.append(
            f"duree_totale_{round(total)}s_ecretee_a_{int(DUREE_TOTALE_MAX_S)}s")
        total = sum(s["duree_s"] for s in scenes)

    return {
        "capsule_id": str(capsule.get("capsule_id") or "capsule"),
        "titre": str(capsule.get("titre") or "Capsule Academia").strip(),
        "format": {"largeur": largeur, "hauteur": hauteur, "fps": fps},
        "scenes": scenes,
        "duree_totale_s": round(total, 2),
        "images_total": int(round(total * fps)),
        "avertissements": avertissements,
        # Conservee telle quelle : c'est par elle que le pod retrouve la voix.
        "narration_cle": capsule.get("narration_cle"),
    }


def resume(capsule: dict) -> str:
    """Une ligne lisible dans les journaux du worker."""
    parts = [f"{s['archetype']}:{s['duree_s']}s" for s in capsule["scenes"]]
    alerte = f" | corrections={len(capsule['avertissements'])}" if capsule["avertissements"] else ""
    return (f"{capsule['titre']} — {len(parts)} scenes, "
            f"{capsule['duree_totale_s']}s, {capsule['images_total']} images "
            f"[{' '.join(parts)}]{alerte}")

#!/usr/bin/env python3
"""Construit l'index des OBJETS DU SUJET, a partir d'Objaverse + Cap3D.

## Le probleme qu'il resout

Mesure du 05/09/2026, capsule « le volcan » : la narration etait juste — « le
magma s'accumule dans une chambre magmatique », « formant le cone volcanique » —
et l'image montrait **la meme lentille filaire dans les trois scenes**. Au moment
ou le texte disait « cone », l'ecran affichait une forme aplatie.

Ce n'est pas un defaut de style : le filaire bleu, la grille, la brume et les
sous-titres sont conformes a la reference. **C'est l'objet du sujet qui manque.**
Huit archetypes sur dix n'acceptent que des nombres ; seul `silhouette` porte une
forme, et il n'en existait que CINQ (amphore, coeur, feuille, goutte, spirale).

## Ce que cet index apporte

Cap3D decrit **1 006 782 objets** d'Objaverse en langage naturel. Mesure faite :
cerveau 785, neurone 69, anatomie 634, plante 9 145, feuille 5 215, atome 1 886.
Les objets existent ; il manquait le pont entre « le storyboard parle de magma »
et « voici le maillage a montrer ».

## Les licences, verifiees et non supposees

Echantillon de 23 759 objets sur cinq lots repartis :
    by        87,8 %   commercial autorise AVEC attribution
    by-nc-sa   6,4 %   NON commercial
    by-nc      3,2 %   NON commercial
    by-sa      2,0 %   commercial, partage a l'identique
    cc0        0,6 %   domaine public
Soit **90,4 % utilisables**. Les `nc` sont ecartes par defaut : Academia reste
une plateforme ou l'etudiant paie des credits, et le doute ne se plaide pas.
`--inclure-nc` existe pour un usage strictement pedagogique assume.

## Pourquoi un index CIBLE et pas le million d'objets

Telecharger les 160 fichiers de metadonnees represente ~300 Mo pour une
couverture dont on n'utilisera qu'une fraction. On part donc du vocabulaire
scolaire reel, et on ne recupere les licences que des candidats retenus.

Usage :
    python construire_index_objets.py cap3d_captions.json.gz [--inclure-nc]
"""
import gzip
import io
import json
import re
import sys
import urllib.request
from collections import defaultdict
from pathlib import Path

META = "https://huggingface.co/datasets/allenai/objaverse/resolve/main/metadata/000-{:03d}.json.gz"
LICENCES_OK = {"by", "by-sa", "cc0"}
LICENCES_NC = {"by-nc", "by-nc-sa", "by-nc-nd"}

# LE VOCABULAIRE SCOLAIRE, en anglais parce que Cap3D decrit en anglais.
#
# Chaque entree : le terme francais que le storyboard emploiera, et les mots
# anglais a chercher. On ne met QUE des objets qu'un cours montre reellement —
# un index qui ratisse large rend des resultats hors sujet, et un objet hors
# sujet est pire qu'une forme abstraite : il affirme quelque chose de faux.
VOCABULAIRE = {
    # SVT — corps
    "cerveau": ["brain"], "neurone": ["neuron", "nerve cell"],
    "coeur": ["human heart", "anatomical heart"], "poumon": ["lung"],
    "rein": ["kidney"], "estomac": ["stomach"], "foie": ["liver"],
    "squelette": ["skeleton"], "os": ["bone"], "crane": ["skull"],
    "corps humain": ["human body", "anatomical figure", "human anatomy"],
    "oeil": ["eyeball", "human eye"], "dent": ["tooth", "teeth", "molar"],
    # « muscle » seul ramenait « Red muscle car ». Le terme anatomique se dit
    # presque toujours avec son contexte : on le demande ainsi.
    "muscle": ["muscle anatomy", "human muscle", "muscular system"],
    "peau": ["skin layer"], "sang": ["blood cell"],
    # SVT — vivant
    "cellule": ["cell membrane", "animal cell", "plant cell"],
    "adn": ["dna", "double helix"], "virus": ["virus", "coronavirus"],
    "bacterie": ["bacteria", "microbe"], "graine": ["seed"],
    "germination": ["sprout", "seedling", "germinating"],
    "plante": ["potted plant", "plant"], "feuille": ["leaf", "leaves"],
    "fleur": ["flower"], "racine": ["root system", "tree root"],
    "arbre": ["tree"], "fruit": ["fruit"], "insecte": ["insect"],
    "poisson": ["fish"], "oiseau": ["bird"],
    # Physique - chimie
    "atome": ["atom", "atomic model"], "molecule": ["molecule"],
    "aimant": ["magnet"], "pendule": ["pendulum"], "lentille": ["optical lens"],
    "prisme": ["glass prism"], "circuit": ["circuit board"],
    "pile": ["battery"], "engrenage": ["gear"], "ressort": ["spring coil"],
    "thermometre": ["thermometer"], "balance": ["weighing scale", "balance scale"],
    # Terre et espace
    "volcan": ["volcano", "erupting volcano"], "montagne": ["mountain"],
    "riviere": ["river"], "nuage": ["cloud"], "globe": ["globe", "earth"],
    "planete": ["planet"], "roche": ["rock", "boulder"],
    "cristal": ["crystal"], "goutte": ["water drop", "droplet"],
    # Histoire et culture
    "pyramide": ["pyramid"], "chateau": ["castle"], "temple": ["temple"],
    "statue": ["statue"], "piece": ["ancient coin"], "vase": ["amphora", "vase"],
    "livre": ["open book"], "parchemin": ["scroll"],
    # Technique et agriculture
    # « plow » seul ramenait un chasse-neige : c'est le meme mot en anglais.
    "tracteur": ["tractor"], "charrue": ["plough", "farm plow"],
    "puits": ["water well"],
    "panneau solaire": ["solar panel"], "eolienne": ["wind turbine"],
    "pont": ["bridge"], "barrage": ["dam"], "microscope": ["microscope"],
    "maison": ["house"], "outil": ["hammer", "shovel"],
}

MAX_PAR_TERME = 12          # au-dela, on n'ajoute que du bruit a trier
MIN_LONGUEUR_CAPTION = 12   # une description trop courte ne prouve rien

# CE QUI DISQUALIFIE UNE DESCRIPTION.
#
# Premiere version de cet index : on gardait les douze PREMIERS objets trouves.
# Resultat mesure — « cerveau » rendait « a multicolored protein molecule »,
# « graine » rendait « a bag of assorted food items, including pistachios », et
# « goutte » rendait « a crumpled plastic bottle ». Le mot etait bien present,
# l'objet n'avait rien a voir.
#
# Un objet hors sujet est PIRE qu'une forme abstraite : la forme abstraite
# n'affirme rien, l'objet faux affirme quelque chose de faux. On classe donc
# par pertinence, et on ecarte les fourre-tout.
FOURRE_TOUT = re.compile(
    r"\b(collection|assorted|various|set of|bunch of|group of|pack of|"
    r"bag of|pile of|includ\w+|featuring \w+, \w+, \w+)\b")

# L'OBJET DETOURNE — troisieme defaut mesure de cet index (05/09/2026).
#
# La regle du mot entier a supprime les contresens (« Liverpool » pour le foie).
# Restait un cas ou le mot est JUSTE et l'objet faux : le referent existe, mais
# sous forme de nourriture, de logo ou de deguisement. Mesure sur l'index de
# 784 objets, en tete de liste :
#     cerveau -> « a brain sushi roll »        (un sushi)
#     crane   -> « Skull 38 Logo »             (un logotype)
#     graine  -> « a seeded loaf of bread »    (du pain)
# Un cours de SVT qui montre un sushi au mot « cerveau » est plus trompeur
# qu'une forme abstraite : l'etudiant croit voir un cerveau.
#
# On PENALISE au lieu de rejeter, parce que le vocabulaire contient lui-meme
# des objets de ces categories — « fruit », « livre », « vase », « piece »,
# « outil ». Un rejet sec les viderait. La penalite laisse le tri decider, et
# un terme dont tous les candidats sont detournes finit simplement sans objet :
# c'est la bonne reponse, les archetypes geometriques prennent le relais.
DETOURNE = re.compile(
    r"\b(sushi|bread|bagel|cake|candy|cookie|pizza|burger|loaf|granola|"
    r"chocolate|donut|pancake|bun|sandwich|toast|pastry|croissant|muffin|"
    r"cereal|"                                        # nourriture
    r"logo|icon|emblem|sticker|banner|poster|signage|"  # graphisme
    r"mask|helmet|costume|sconce|lamp|pillow|plush|toy|keychain|pendant|"
    r"jewelry|earring|tattoo|"                        # deguisement, decoration
    r"sword|weapon|gun|knife|dagger|blade|"           # armes
    r"mall|hotel|restaurant|cafe|shop|store|"         # enseignes et lieux
    r"car|scooter|motorcycle|"                        # « muscle car » n'est pas un muscle
    r"cartoon|emoji|meme)"
    # LE PLURIEL COMPTE AUTANT QUE LE SINGULIER. Sans ce suffixe, « skeletons
    # with swords » passait : `\bsword\b` ne reconnait pas « swords », et
    # l'index proposait des squelettes armes d'epees pour un cours d'anatomie.
    r"(?:s|es)?\b")

# LE MOT DOIT ETRE UN MOT, PAS UNE SUITE DE LETTRES.
#
# Deuxieme defaut mesure de cet index (05/09/2026). La recherche testait
# `mot in texte` — une sous-chaine. Resultat, sur l'index de 796 objets :
#     foie    -> « Liverpool FC logo »        (liver dans Liverpool)
#     dent    -> « Toothless the white dragon » (tooth dans Toothless)
#     roche   -> « rocket model »             (rock dans rocket)
#     barrage -> « Damascus dagger »          (dam dans Damascus)
#     feuille -> « leafless, dead trees »     (leaf dans leafless)
# Les deux derniers sont les pires : `leafless` et `toothless` disent
# l'ABSENCE de ce qu'on cherche. L'index proposait donc, en tete de liste,
# l'exact contraire du terme demande.
#
# On exige desormais une limite de mot de chaque cote, en tolerant les
# flexions courantes — « lungs » pour *lung*, « sprouting » pour *sprout*,
# « atomic » pour *atom*. La liste est volontairement courte : chaque suffixe
# ajoute est une porte ouverte, et `-less` a montre ce qui passe par la.
#
# Ce que la regle ne peut pas rattraper se corrige dans VOCABULAIRE, terme par
# terme : les pluriels irreguliers (leaf/leaves, tooth/teeth) et les composes
# ou le mot est soude (coronavirus). C'est explicite, donc verifiable.
SUFFIXES = "(?:s|es|ing|ed|ic|al)?"
_motifs: dict[tuple, "re.Pattern"] = {}


def motif(mots) -> "re.Pattern":
    cle = tuple(mots)
    if cle not in _motifs:
        # Les plus longs d'abord : « human heart » doit primer sur « heart ».
        alts = "|".join(re.escape(m) for m in sorted(mots, key=len, reverse=True))
        _motifs[cle] = re.compile(r"\b(?:" + alts + r")" + SUFFIXES + r"\b")
    return _motifs[cle]


def normaliser(texte: str) -> str:
    return re.sub(r"[^a-z0-9 ]+", " ", texte.lower())


def score(texte: str, mots) -> float:
    """Plus c'est haut, plus l'objet EST le sujet plutot que d'en parler.

    Trois signaux, tous verifiables sans modele :
      - le mot apparait TOT : « a volcano with... » vaut mieux que
        « a landscape with a house, a tree and a volcano » ;
      - la description est COURTE : un objet unique se decrit en peu de mots,
        une scene encombree en demande beaucoup ;
      - elle ne ressemble pas a un inventaire (cf. FOURRE_TOUT).
    """
    trouve = motif(mots).search(texte)
    if trouve is None:
        return -1.0
    s = 100.0
    s -= trouve.start() * 1.5        # penalise l'apparition tardive
    s -= len(texte) * 0.10           # penalise la description bavarde
    if FOURRE_TOUT.search(texte):
        s -= 60.0                    # un inventaire n'est pas un objet
    if DETOURNE.search(texte):
        # PLUS QUE LE MAXIMUM ATTEIGNABLE (100) : le score devient negatif, et
        # l'objet sort. Une simple penalite le reléguait en fin de liste, ou il
        # restait le meilleur candidat des termes dont TOUT est detourne --
        # « graine » n'avait que des pains et des bagels au sesame.
        s -= 120.0                   # le mot est juste, l'objet ne l'est pas
    if texte.count(",") >= 3:
        s -= 25.0                    # enumeration : plusieurs objets dans un
    return s


def charger_licences(uids, verbeux=True):
    """Recupere la licence de chaque uid, lot par lot.

    On ne telecharge que les lots qui contiennent au moins un candidat : sur
    160 lots, une recherche ciblee n'en touche qu'une partie.
    """
    restants = set(uids)
    licences = {}
    for i in range(160):
        if not restants:
            break
        try:
            with urllib.request.urlopen(META.format(i), timeout=180) as r:
                lot = json.load(gzip.GzipFile(fileobj=io.BytesIO(r.read())))
        except Exception as e:  # noqa: BLE001
            if verbeux:
                print(f"    lot {i:03d} illisible ({str(e)[:40]}) — ignore")
            continue
        trouves = restants & lot.keys()
        for uid in trouves:
            licences[uid] = str(lot[uid].get("license") or "")
        restants -= trouves
        if verbeux and trouves:
            print(f"    lot 000-{i:03d} : {len(trouves)} licences  "
                  f"({len(restants)} restants)")
    return licences


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    chemin_cap3d = Path(sys.argv[1])
    inclure_nc = "--inclure-nc" in sys.argv
    autorisees = LICENCES_OK | (LICENCES_NC if inclure_nc else set())

    print("[1] Lecture des descriptions Cap3D")
    with gzip.open(chemin_cap3d, "rt", encoding="utf-8") as f:
        captions = json.load(f)
    print(f"    {len(captions)} objets decrits")

    print("[2] Recherche du vocabulaire scolaire")
    candidats = defaultdict(list)
    normalisees = {uid: normaliser(str(c)) for uid, c in captions.items()}
    for terme, mots in VOCABULAIRE.items():
        notes = []
        for uid, texte in normalisees.items():
            if len(texte) < MIN_LONGUEUR_CAPTION:
                continue
            n = score(texte, mots)
            if n > 0:                # en dessous, ce n'est plus le sujet
                notes.append((n, uid))
        # On garde plus large qu'il n'en faut : le filtre des licences en
        # ecartera, et il vaut mieux avoir de la reserve que revenir a zero.
        notes.sort(reverse=True)
        candidats[terme] = [uid for _, uid in notes[:MAX_PAR_TERME * 3]]
    total = sum(len(v) for v in candidats.values())
    manquants = [t for t in VOCABULAIRE if not candidats.get(t)]
    print(f"    {len(candidats)} termes pourvus, {total} candidats")
    if manquants:
        print(f"    SANS AUCUN OBJET : {', '.join(manquants)}")

    print("[3] Verification des licences (aucune supposition)")
    tous = {u for v in candidats.values() for u in v}
    licences = charger_licences(tous)

    print("[4] Filtrage par licence, en conservant l'ordre de pertinence")
    index, refuses = {}, 0
    for terme, uids in candidats.items():
        gardes = []
        for uid in uids:              # deja tries du plus au moins pertinent
            lic = licences.get(uid, "")
            if lic in autorisees:
                if len(gardes) < MAX_PAR_TERME:
                    gardes.append({"uid": uid, "licence": lic,
                                   "description": str(captions[uid])[:110]})
            else:
                refuses += 1
        if gardes:
            index[terme] = gardes
    print(f"    {len(index)} termes retenus, {refuses} objets ecartes")

    print("[5] Resolution des chemins de telechargement")
    resoudre_chemins(index)

    ecrire(index, autorisees)
    vides = [t for t in VOCABULAIRE if t not in index]
    if vides:
        print(f"TERMES SANS OBJET UTILISABLE : {', '.join(vides)}")
        print("  -> pour ceux-la, les archetypes geometriques restent la reponse.")
    return 0


def resoudre_chemins(index: dict) -> int:
    """Inscrit dans l'index le chemin Objaverse de chaque objet.

    POURQUOI ICI ET PAS AU RENDU. Sans ce champ, `convoquer.telecharger` doit
    charger `object-paths.json.gz` — 800 000 entrees, 60 Mo — pour traduire un
    uid en chemin. Ce transfert tomberait dans la boucle etudiant, sur un pod
    qui vit une dizaine de minutes : aucun cache ne lui survit, et chaque
    capsule le repaierait.

    Ici, il est fait UNE FOIS, hors ligne, et le resultat voyage dans l'index
    (quelques dizaines d'octets par objet).
    """
    import io as _io
    print("    telechargement de object-paths.json.gz (~60 Mo, une seule fois)")
    with urllib.request.urlopen(CHEMINS_URL, timeout=600) as r:
        chemins = json.load(gzip.GzipFile(fileobj=_io.BytesIO(r.read())))
    print(f"    {len(chemins)} chemins connus")
    poses, absents = 0, 0
    for objets in index.values():
        for o in objets:
            rel = chemins.get(o["uid"])
            if rel:
                o["chemin"] = rel
                poses += 1
            else:
                absents += 1
    print(f"    {poses} chemins inscrits, {absents} introuvables")
    if absents:
        print("    (ceux-la retomberont sur object-paths au rendu — signale, pas muet)")
    return poses


def ecrire(index: dict, autorisees) -> Path:
    sortie = Path(__file__).parent / "index_objets.json"
    sortie.write_text(json.dumps({
        "source": "Objaverse (ODC-By) + Cap3D — licences verifiees objet par objet",
        "licences_retenues": sorted(autorisees),
        "attribution_requise": True,
        "termes": index,
    }, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"\nEcrit : {sortie}  ({sortie.stat().st_size // 1024} Ko)")
    return sortie


def chemins_seulement() -> int:
    """Enrichit un index DEJA construit, sans refaire la recherche.

    La recherche relit un million de descriptions et retelecharge les licences ;
    quand seul le chemin manque, tout cela serait a repayer pour rien.
    """
    chemin = Path(__file__).parent / "index_objets.json"
    if not chemin.exists():
        return print(f"REFUS : {chemin} absent") or 1
    contenu = json.loads(chemin.read_text(encoding="utf-8"))
    index = contenu["termes"]
    resoudre_chemins(index)
    ecrire(index, contenu.get("licences_retenues", sorted(LICENCES_OK)))
    return 0


CHEMINS_URL = ("https://huggingface.co/datasets/allenai/objaverse/"
               "resolve/main/object-paths.json.gz")


if __name__ == "__main__":
    if "--chemins" in sys.argv:
        sys.exit(chemins_seulement())
    sys.exit(main())

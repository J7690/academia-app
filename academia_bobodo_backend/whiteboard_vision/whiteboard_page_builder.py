"""
Vision v2 — Construction d'UNE page HTML animée pour tout le cours.

Remplace « une page par scène, une capture par page » (qui donnait un diaporama) par
UNE SEULE page contenant toutes les scènes, qui défile comme un vrai cahier, et dont
l'animation est décrite en CSS.

Principe : tout est piloté par des animations CSS avec des délais calculés ici, en
Python. Rien n'est animé en JavaScript. Le navigateur compose donc les animations avec
son moteur graphique — c'est ce pour quoi il est optimisé, et c'est ce qui permet
d'enregistrer en temps réel (voir whiteboard_video_capture.py).

Le chronométrage reprend celui mis au point pour le moteur studio :
    écrire un bloc -> s'arrêter -> annoter -> respirer -> bloc suivant
La caméra ne bouge JAMAIS pendant qu'on écrit ou qu'on annote : le regard doit pouvoir
lire sans poursuivre une cible mobile.
"""

from __future__ import annotations

import html as html_module
import json
import logging
import re
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

logger = logging.getLogger("whiteboard_page_builder")


def _default_katex(latex: str) -> str:
    """
    Rendu des formules via KaTeX (le moteur Vision sait deja le faire).

    Sans cela, les blocs `formula` affichaient le LaTeX BRUT a l'ecran
    (« x = \\frac{-b \\pm \\sqrt{\\Delta}}{2a} »), defaut vu au premier rendu du
    cahier continu. Repli lisible si KaTeX est indisponible.
    """
    try:
        from whiteboard_scene_engine import _render_katex
        html = _render_katex(latex)
        # Sécurité supplémentaire : si la CSS venait à manquer, on retire la couche
        # MathML pour que la formule ne puisse pas s'afficher deux fois.
        # Le motif se termine sur </math></span> — et non sur deux </span>, qui
        # apparaissaient d'abord APRES la couche visuelle : le filtre l'emportait avec
        # lui et la formule disparaissait purement et simplement.
        return re.sub(r"<span class=\"katex-mathml\">.*?</math></span>", "", html, flags=re.S)
    except Exception:  # noqa: BLE001
        return f'<span style="font-family:monospace">{html_module.escape(latex)}</span>' 

# ─── Géométrie (identique au gabarit existant : 1080×1920 vertical) ──────────
# Police manuscrite : chemin ABSOLU, car la page est écrite dans un dossier temporaire
# où un chemin relatif ne résoudrait pas. Si le fichier manque, le navigateur retombe
# sur les polices cursives déclarées ensuite — le rendu reste lisible.
# ─── LA POLICE MANUSCRITE, ET SES MESURES ───────────────────────────────────
#
# Choix de Jocelyn le 08/09 : **Dancing Script**, une vraie cursive liee, en
# remplacement de Caveat -- jugee « generique », et de fait la plus fine des dix
# candidates comparees.
#
# DEUX METRIQUES COMMANDENT LE REGLAGE, et elles ont ete relevees dans les
# fichiers avec `fontTools`, pas estimees a l'oeil :
#
#                    hauteur d'x     largeur d'une phrase type
#   Caveat              0,400              12,12 em
#   Dancing Script      0,332              12,74 em
#
# La hauteur d'x est ce que l'oeil percoit comme « la taille » du texte : celle
# de Dancing Script ne fait que 83 % de celle de Caveat. A taille egale, elle
# paraitrait donc nettement plus petite. On compense par 0,400/0,332 = 1,205.
#
# Mais elle est AUSSI 5 % plus large. En l'agrandissant, une ligne tient donc
# MOINS de caracteres : 24 au lieu de 31. Sans cet ajustement, `_estimate_lines`
# sous-estimerait la hauteur du document, et le defilement -- calcule sur cette
# hauteur -- se decalerait progressivement du contenu reel.
POLICES_MANUSCRITES = {
    "Dancing Script": dict(
        fichier="DancingScript.ttf",
        css="'ManuscritLocal','Dancing Script','Caveat',cursive",
        # 1,28 (le reglage de Caveat) x 1,205 (compensation de hauteur d'x)
        echelle=1.542,
        chars_per_line=24,
    ),
    "Caveat": dict(
        fichier="Caveat.ttf",
        css="'ManuscritLocal','Caveat','Patrick Hand',cursive",
        echelle=1.28,
        chars_per_line=31,
    ),
}
POLICE_MANUSCRITE = "Dancing Script"

FONT_PATHS = [
    Path("/opt/whiteboard-worker/vision_engine/fonts/"
         + POLICES_MANUSCRITES[POLICE_MANUSCRITE]["fichier"]),
    Path(__file__).parent / "fonts"
        / POLICES_MANUSCRITES[POLICE_MANUSCRITE]["fichier"],
    # Repli : l'ancienne police, pour qu'une machine non encore mise a jour
    # rende un texte manuscrit plutot qu'une police systeme.
    Path("/opt/whiteboard-worker/vision_engine/fonts/Caveat.ttf"),
    Path("/opt/whiteboard-engine-remotion/public/fonts/Caveat.ttf"),
]


# Feuille de style KaTeX : sans elle, la couche MathML n'est pas masquée et la formule
# s'affiche EN DOUBLE (version composée + version brute). Défaut déjà rencontré sur le
# moteur studio, reproduit ici faute d'avoir reporté le correctif.
# On la charge depuis le disque : aucune dépendance réseau au moment du rendu.
KATEX_CSS_PATHS = [
    Path("/opt/whiteboard-worker/node_modules/katex/dist/katex.min.css"),
    Path("/opt/whiteboard-worker/vision_engine/node_modules/katex/dist/katex.min.css"),
    Path("/opt/whiteboard-engine-remotion/node_modules/katex/dist/katex.min.css"),
]


def _katex_css_url() -> str:
    for p in KATEX_CSS_PATHS:
        if p.exists():
            return p.resolve().as_uri()
    return ""


def _font_url() -> str:
    for p in FONT_PATHS:
        if p.exists():
            return p.resolve().as_uri()
    return ""


# ─── Le LOGO de la marque ───────────────────────────────────────────────────
#
# Le vrai fichier, pas un dessin approchant. Une premiere version reconstituait
# la toque en SVG et posait « ACADEMIA » en Georgia a cote : deux ecarts avec
# la marque reelle -- la toque du logo porte des losanges entrelaces qu'un
# trace a la main ne rend pas, et le mot est compose dans une serif qui lui est
# propre. On embarque donc le PNG.
#
# Il est recadre sur ses pixels visibles (600x545 utiles sur 600x664 : le
# fichier d'origine porte une marge transparente qui aurait decale le logo dans
# son cadre) et reduit a 240x218 -- le double de la taille d'affichage, pour
# rester net. Quantifie en 32 couleurs : 5 Ko au lieu de 212.
#
# Meme motif que la police et KaTeX : un fichier a cote du moteur, resolu en
# `file://`. S'il manque, `_logo_url()` rend une chaine vide et le filigrane
# n'est tout simplement pas ecrit dans la page -- degradation gracieuse, aucune
# image cassee a l'ecran.
LOGO_PATHS = [
    Path(__file__).parent / "marque" / "academia_logo.png",
    Path("/opt/whiteboard-worker/vision_engine/marque/academia_logo.png"),
    Path("/opt/whiteboard-engine-remotion/public/marque/academia_logo.png"),
]

# Largeur d'affichage du filigrane, sur une page de 1080 px : 11,1 % de la
# largeur. Assez grand pour ne pas passer inapercu, assez petit pour ne pas
# envahir la page. La hauteur suit le rapport du fichier (240x218).
MARQUE_W = 120
MARQUE_H = 109
MARQUE_BAS = 96      # position de repos, mesuree depuis le bas de l'ecran
# MARQUE_HAUT est defini plus bas, apres TOP_SAFE dont il depend.


def _logo_url() -> str:
    for p in LOGO_PATHS:
        if p.exists():
            return p.resolve().as_uri()
    return ""


VIEW_W = 1080
VIEW_H = 1920
# Marge de sécurité horizontale (28/07/2026) : le feed Challenges affiche la vidéo en
# BoxFit.cover façon TikTok (cf. student_challenges_tab.dart) — un téléphone plus
# étiré que le 9:16 de la vidéo (9:19,5 à 9:21, cas courant) rogne alors 8 à 13 % de
# la largeur de CHAQUE côté pour remplir l'écran. Une marge de 150px (~13,9 %) couvre
# ce rognage sur les téléphones les plus étirés du marché. Symétrique : `.blk` se
# centre via `margin:auto` dans #paper (1080px), donc seule la SOMME PAD_LEFT+PAD_RIGHT
# compte pour la marge réelle ; les rendre égaux aligne aussi `.recall` (positionné en
# `left:{pad_left}px`) sur le bloc qu'il annote, ce qui n'était pas le cas avec 120/72.
PAD_LEFT = 150
PAD_RIGHT = 150
CONTENT_W = VIEW_W - PAD_LEFT - PAD_RIGHT
# ZONE HAUTE : le titre ne doit être ni collé au bord, ni dans un angle.
# Elle valait 190 px sur 1920, soit 9,9 % -- le bandeau fixe occupant déjà
# jusqu'à ~90 px, il ne restait qu'une centaine de pixels avant le premier
# bloc. Un titre de chapitre s'y retrouvait tassé contre le haut de l'écran,
# et le cadre décoratif (`#frame`, inset 18 px) passait juste au-dessus.
# 300 px (15,6 %) laissent le titre respirer sans repousser le contenu utile.
TOP_SAFE = 300
BLOCK_GAP = 46

# HAUTEUR DE LA TROISIÈME POSITION DU FILIGRANE — et pourquoi elle n'est pas libre.
#
# Premier essai : le filigrane montait à 335 px. Rendu sur LWS, en file:// et
# en 1080×1920 : IL CHEVAUCHAIT LE TITRE, qui commence à 318 px. Le logo
# passait par-dessus le mot — exactement ce qu'un filigrane ne doit jamais faire.
#
# Il n'existe qu'une bande libre en haut de page : entre le bas du bandeau du
# sujet (~134 px) et le début du contenu (TOP_SAFE). Le logo s'y loge.
# L'assertion below rend le conflit IMPOSSIBLE : changer TOP_SAFE sans y penser
# arrête la construction au lieu de produire une capsule où le logo mange le titre.
MARQUE_HAUT = 162
assert MARQUE_HAUT + MARQUE_H < TOP_SAFE, (
    "le filigrane déborderait sur le contenu : "
    f"{MARQUE_HAUT} + {MARQUE_H} >= {TOP_SAFE}")

# ─── Chronométrage (secondes) ───────────────────────────────────────────────
# Caractères par seconde. Valeurs abaissées le 25/07 au soir : « les écritures sont
# trop rapides ». Repère : un lecteur adulte lit ~15 caractères/seconde à voix haute ;
# un professeur qui écrit AU TABLEAU va plus lentement encore, car l'élève doit suivre
# du regard ET comprendre. On se cale donc sous le rythme de lecture.
CPS = {"slow": 8, "normal": 12, "fast": 17}   # caractères/seconde
BLOCK_GAP_SEC = 0.35
ANNOT_DRAW_SEC = 0.6
ANNOT_HOLD_SEC = 1.6
ANNOT_ERASE_SEC = 0.5
ANNOT_TOTAL_SEC = ANNOT_DRAW_SEC + ANNOT_HOLD_SEC + ANNOT_ERASE_SEC
RECALL_SEC = 4.0
MIN_SCENE_SEC = 3.0
TAIL_SEC = 0.8

# ─── Générique d'ouverture (carte-titre) ────────────────────────────────────
# Toute vidéo commence par une CARTE-TITRE : plaquette pleine page, titre en très
# gros caractères gras qui entre lettre par lettre, puis la carte sort vers le haut
# et le cahier commence. Demandé le 27/07/2026 : « une vidéo doit toujours commencer
# par un titre mis en gras avec une police de titres, sur une plaquette, avec des
# animations en entrée et en sortie ».
#
# La narration est DÉCALÉE d'autant par le worker (silence en tête de piste) : la
# voix ne parle pas pendant le générique. Tout est en CSS, donc compatible avec la
# capture par tranches (les animations s'avancent via l'API Web Animations).
INTRO_SEC = 3.2          # durée totale du générique
INTRO_CARD_IN_SEC = 0.7  # entrée de la plaquette
INTRO_LETTER_FROM = 0.35 # première lettre
INTRO_LETTER_TO = 1.30   # dernière lettre
INTRO_OUT_SEC = 0.6      # sortie (balayage vers le haut)
# Durée d'un mouvement de caméra. Portée de 0,9 à 1,8 s : à 0,9 s le défilement était
# assez rapide pour que l'image capte deux positions du texte, d'où l'impression
# d'écritures superposées et floues signalée sur les captures.
SCROLL_SEC = 1.8

# ─── Rendu du texte ─────────────────────────────────────────────────────────
FONT_SIZE = 52
LINE_H = 1.42
# Estimation du nombre de caracteres par ligne, PAR POLICE : une cursive plus
# large en tient moins. Sert a estimer la hauteur du document, donc le
# defilement -- une valeur trop haute decale la camera du contenu.
CHARS_PER_LINE = POLICES_MANUSCRITES[POLICE_MANUSCRITE]["chars_per_line"]

# ─── LES COULEURS DE LA MARQUE ──────────────────────────────────────────────
#
# Relevees dans `academia_app/assets/marque/academia_logo.png` par comptage des
# pixels, pas estimees a l'oeil : le vert occupe 60,6 % des pixels colores, le
# rouge 12,4 %. Ce sont les couleurs du drapeau burkinabe.
#
# CE QU'ELLES REMPLACENT. La page portait CINQ accents sans rapport avec la
# marque -- bleu #3b6fe0, vert #1aa179, rouge #d4452e, jaune #ffe066, marine
# #0f2c5c -- sur un fond a lignes et marge rouge d'ecolier. Rien ne
# hierarchisait : tout ressortait en meme temps, donc rien ne ressortait.
#
# La regle desormais : UN fond, UNE encre, DEUX accents de marque. Le vert
# porte la structure (titres, filets, definitions) ; le rouge ne sert qu'a ce
# qu'un professeur ecrirait en rouge -- le mot-cle, et rien d'autre.
VERT = "#388840"        # toque et losanges du logo
VERT_SOMBRE = "#2b6a32"  # meme teinte, pour les traits fins sur papier clair
ROUGE = "#e02018"       # le mot ACADEMIA
PAPIER = "#f7f4ec"      # papier chaud, sans lignes d'ecolier
ENCRE = "#1b2430"       # bleu-noir d'encre
ENCRE_PALE = "#3d4653"  # texte secondaire
SURLIGNE = "rgba(56,136,64,.18)"  # le vert de marque, tres dilue

# Le titre de scene doit DOMINER le corps du texte. Il valait exactement
# `font_size` -- soit la taille du corps -- ce qui le rendait indistinct.
TITRE_ECHELLE = 1.45

# Bornes de la duree d'ecriture d'UN mot. En deca de 0,20 s le balayage n'est
# plus percu comme un trace ; au-dela de 0,75 s un mot long donne l'impression
# que la main hesite.
MOT_DUREE_MIN = 0.20
MOT_DUREE_MAX = 0.75

# Largeur du filigrane (toque 52 px + espace 14 px + « ACADEMIA » en Georgia
# 31 px ≈ 200 px). Sert à calculer son déplacement vers le bord droit ; elle
# est VÉRIFIÉE au navigateur par `test_page_builder.py`, car une valeur trop
# petite ferait sortir le logo de la zone sûre du feed.
MARQUE_L = 266


def _speed_of(block: Dict[str, Any]) -> str:
    speed = block.get("write_speed")
    if speed in CPS:
        return speed
    return "slow" if block.get("type") == "definition" else "normal"


def _write_seconds(block: Dict[str, Any]) -> float:
    btype = block.get("type")
    if btype in ("image", "formula", "diagram", "graph"):
        return 0.8
    content = block.get("content") or ""
    return max(0.3, len(content) / CPS[_speed_of(block)])


def _has_emphasis(block: Dict[str, Any]) -> bool:
    return block.get("emphasis") in ("circle", "underline", "highlight")


def _estimate_height(block: Dict[str, Any]) -> int:
    """Hauteur approximative d'un bloc, pour placer le suivant."""
    btype = block.get("type")
    if btype == "title":
        return 210
    if btype in ("formula", "graph"):
        return 240
    if btype in ("image", "diagram"):
        return 380
    content = block.get("content") or ""
    lines = max(1, -(-len(content) // CHARS_PER_LINE))  # division entière par excès
    base = int(lines * FONT_SIZE * LINE_H) + 40
    if btype in ("definition", "exercise", "correction"):
        base += 44  # encadré / puce
    return base


# ═══════════════════════════════════════════════════════════════════════════
# Planification : quand chaque bloc s'écrit, où il se trouve, quand on scrolle
# ═══════════════════════════════════════════════════════════════════════════

class PlannedBlock:
    __slots__ = ("block", "scene_index", "y", "height", "start", "write_end", "annot_end")

    def __init__(self, block, scene_index, y, height, start, write_end, annot_end):
        self.block = block
        self.scene_index = scene_index
        self.y = y
        self.height = height
        self.start = start
        self.write_end = write_end
        self.annot_end = annot_end


def plan(storyboard: Dict[str, Any], narration: Optional[List[Dict[str, Any]]] = None):
    """
    Calcule la chronologie complète et la position de chaque bloc.

    Retourne (blocs planifiés, keyframes de défilement, durée totale, hauteur du document).
    """
    scenes = storyboard.get("scenes") or []
    narration = narration or []

    planned: List[PlannedBlock] = []
    scene_start: List[float] = []
    first_block_of_scene: List[int] = []

    # Le cours ne commence qu'APRÈS le générique d'ouverture.
    t = INTRO_SEC
    y = float(TOP_SAFE)

    for si, scene in enumerate(scenes):
        blocks = [b for b in (scene.get("blocks") or []) if isinstance(b, dict)]
        recall = scene.get("recall") if isinstance(scene.get("recall"), dict) else None
        has_recall = bool(recall) and isinstance(recall.get("target"), int) and 0 <= recall["target"] < si

        scene_start.append(t)
        first_block_of_scene.append(len(planned))

        # Le rappel se joue AVANT d'écrire la scène : on remonte, on ré-annote, on revient.
        if has_recall:
            t += RECALL_SEC

        # ── SYNCHRONISATION VOIX / ÉCRITURE ────────────────────────────────
        # Défaut constaté le 25/07 : la voix et l'écriture n'étaient pas synchrones.
        # L'écriture allait à vitesse fixe et la scène durait le PLUS LONG des deux :
        # soit le texte finissait bien avant la voix (écran figé pendant qu'on parle),
        # soit l'inverse.
        #
        # On étire ou comprime donc la vitesse d'écriture de la scène pour qu'elle
        # occupe EXACTEMENT la durée de sa narration : le professeur écrit pendant
        # qu'il parle, et les deux se terminent ensemble.
        narr = 0.0
        if si < len(narration) and isinstance(narration[si], dict):
            try:
                narr = float(narration[si].get("duration_sec") or 0.0)
            except (TypeError, ValueError):
                narr = 0.0

        # Le temps d'une scène se décompose en deux parts :
        #  - une part FIXE : les annotations (2,7 s chacune) et les respirations, dont
        #    la durée ne doit pas changer, sinon le geste devient illisible ;
        #  - une part ÉTIRABLE : l'écriture elle-même.
        # On ne met à l'échelle que la seconde. Première version : on étirait le tout,
        # d'où des écarts résiduels de 2 à 4 s entre la voix et l'écriture.
        # ── DURÉES DE PAROLE PAR BLOC (contiguïté temporelle) ──────────────
        # Si le module de narration a produit un segment par bloc, la durée
        # d'écriture d'un bloc EST la durée de sa parole : ce qui s'écrit est ce qui
        # se dit, à la seconde près. C'est le principe de Mayer appliqué au tableau.
        block_durs = None
        if si < len(narration) and isinstance(narration[si], dict):
            bd = narration[si].get("block_durations")
            if isinstance(bd, list) and len(bd) == len(blocks) and blocks:
                block_durs = [float(x) for x in bd]

        if block_durs is not None:
            # L'ANNOTATION SE JOUE PENDANT LA PAROLE, PLUS APRES.
            #
            # Le principe d'origine -- « ecrire, s'arreter, annoter, respirer »
            # (voir l'en-tete du module) -- ajoutait ANNOT_TOTAL_SEC APRES la
            # parole de chaque bloc annote. Mesure du 07/08 sur un cours reel :
            #
            #     parole        88,1 s
            #     page a filmer 112,3 s
            #     silence       24,2 s, dont 16,2 s pour 6 annotations muettes
            #
            # L'etudiant entendait donc son professeur se taire, puis regardait
            # un cercle se dessiner sans un mot, six fois. Et la voix finissait
            # vingt secondes avant l'image.
            #
            # Un professeur n'agit pas ainsi : il entoure le mot AU MOMENT ou
            # il le prononce. L'annotation est donc desormais contenue dans la
            # fenetre de parole du bloc, et peut deborder sur le bloc suivant
            # -- ce qui est exactement ce que fait une main qui continue son
            # geste pendant que la phrase suivante commence.
            for b, d in zip(blocks, block_durs):
                h = _estimate_height(b)
                planned.append(PlannedBlock(b, si, y, h, t, t + d, t + d))
                t += d
                y += h + BLOCK_GAP
            t = max(t, scene_start[si] + MIN_SCENE_SEC)
            continue

        writable = sum(_write_seconds(b) for b in blocks)
        fixed = sum(ANNOT_TOTAL_SEC if _has_emphasis(b) else 0.0 for b in blocks) \
            + BLOCK_GAP_SEC * len(blocks)

        pace = 1.0
        if narr > 0 and writable > 0:
            # Bornes : on n'écrit jamais à une vitesse absurde. En deçà de 0,55 la main
            # irait trop vite pour être suivie ; au-delà de 3 elle traînerait.
            pace = min(3.0, max(0.55, (narr - fixed) / writable))

        for b in blocks:
            w = _write_seconds(b) * pace
            a = ANNOT_TOTAL_SEC if _has_emphasis(b) else 0.0
            h = _estimate_height(b)
            planned.append(PlannedBlock(b, si, y, h, t, t + w, t + w + a))
            t += w + a + BLOCK_GAP_SEC
            y += h + BLOCK_GAP

        scene_elapsed = t - scene_start[si]
        needed = max(scene_elapsed, narr if narr > 0 else 0.0, MIN_SCENE_SEC)
        t = scene_start[si] + needed

    total = t + TAIL_SEC
    doc_height = y + 300

    kf, doc_height, recalls = _keyframes(
        planned, scenes, scene_start, first_block_of_scene, doc_height
    )
    return planned, kf, total, doc_height, recalls



def _keyframes(planned, scenes, scene_start, first_block_of_scene, doc_height):
    """
    Mouvements de caméra, calculés à partir des positions des blocs.

    Appelée DEUX FOIS : une première fois sur des positions estimées (pour produire
    la page à mesurer), puis une seconde fois sur les positions RÉELLES relevées dans
    le navigateur. C'est cette seconde passe qui garantit que la caméra vise juste.

    La caméra se pose sur le bloc au début de son écriture et NE BOUGE PLUS jusqu'à la
    fin de son annotation.
    """
    def scroll_for(pb) -> float:
        return max(0.0, pb.y + pb.height - VIEW_H * 0.62)

    kf: List[Tuple[float, float]] = [(0.0, 0.0)]
    for pb in planned:
        target = scroll_for(pb)
        kf.append((max(0.0, pb.start - SCROLL_SEC), kf[-1][1]))
        kf.append((pb.start, target))
        kf.append((pb.annot_end, target))

    recalls: List[Dict[str, Any]] = []
    for si, scene in enumerate(scenes):
        recall = scene.get("recall") if isinstance(scene.get("recall"), dict) else None
        if not recall or not isinstance(recall.get("target"), int):
            continue
        target_scene = recall["target"]
        if not (0 <= target_scene < si):
            continue
        idx = first_block_of_scene[target_scene]
        if idx >= len(planned):
            continue
        tgt = planned[idx]
        rs = scene_start[si]
        base = 0.0
        for pb in planned:
            if pb.start <= rs:
                base = scroll_for(pb)
            else:
                break
        up = max(0.0, tgt.y - VIEW_H * 0.30)
        kf.append((rs, base))
        kf.append((rs + 0.9, up))
        kf.append((rs + 2.9, up))
        kf.append((rs + RECALL_SEC - 0.2, base))
        recalls.append({
            "y": tgt.y, "height": tgt.height, "start": rs + 1.0,
            "kind": recall.get("kind") if recall.get("kind") in ("circle", "underline") else "circle",
        })

    kf.sort(key=lambda p: p[0])
    clean: List[Tuple[float, float]] = []
    for f, v in kf:
        if clean and abs(f - clean[-1][0]) < 1e-3:
            clean[-1] = (clean[-1][0], v)
        else:
            clean.append((f, v))

    # Le document doit être au moins aussi haut que le dernier bloc + une marge.
    if planned:
        doc_height = max(doc_height, planned[-1].y + planned[-1].height + 300)
    return clean, doc_height, recalls


# ═══════════════════════════════════════════════════════════════════════════
# Génération du HTML
# ═══════════════════════════════════════════════════════════════════════════

_WORD_RE = re.compile(r"\S+\s*|\s+")


def _words_html(text: str, start: float, duration: float,
                key_tokens: Optional[set] = None) -> str:
    """
    Texte révélé MOT PAR MOT, chaque mot ayant son propre délai d'animation.

    Tout est en CSS : aucun calcul par image côté navigateur. C'est ce qui permet
    d'enregistrer en temps réel.

    `key_tokens` : mots-clés du bloc (champ `key_words` du storyboard v3). Ces mots
    reçoivent la classe `kw` : typographie cinétique — plus gros, en couleur, avec
    un pop élastique au moment exact où ils s'écrivent. C'est ce qu'un professeur
    écrirait en rouge au tableau.
    """
    words = _WORD_RE.findall(text) or [text]
    total_chars = max(1, sum(len(w) for w in words))
    out = []
    consumed = 0
    for rang, w in enumerate(words):
        delay = start + duration * (consumed / total_chars)
        # LA DURÉE SUIT LA LONGUEUR DU MOT. Elle valait 0,18 s pour tous, ce qui
        # écrivait « où » aussi lentement que « photosynthèse » : rien dans
        # l'image ne disait qu'on en traçait davantage. Elle est désormais
        # proportionnelle, bornée pour qu'un mot d'une lettre reste visible et
        # qu'un mot très long ne traîne pas.
        duree = min(MOT_DUREE_MAX,
                    max(MOT_DUREE_MIN, len(w) * duration / total_chars))
        consumed += len(w)
        bare = w.strip().strip(".,;:!?()«»\"'").lower()
        cls = "w kw" if key_tokens and bare and bare in key_tokens else "w"
        # L'ÉCART À LA RÈGLE, ET POURQUOI IL EST DÉTERMINISTE.
        #
        # Ce qui fait humain n'est pas la vitesse, c'est l'irrégularité : un mot
        # posé deux pixels trop bas, un autre d'un demi-degré de travers. On
        # l'obtient par le RANG du mot, jamais par un tirage au sort.
        #
        # La raison est dans la capture : `record_scene.js` rend la vidéo en
        # TROIS TRANCHES PARALLÈLES, chacune dans son propre navigateur. Un
        # `Math.random()` donnerait trois valeurs différentes pour le même mot,
        # et les tranches ne se raccorderaient pas. Le rang, lui, donne la même
        # valeur partout.
        dy = 1.4 + (rang % 3) * 0.8
        rot = (-1 if rang % 2 else 1) * (0.22 + (rang % 3) * 0.11)
        out.append(
            f'<span class="{cls}" style="animation-delay:{delay:.2f}s;'
            f'--d:{duree:.2f}s;--dy:{dy:.1f}px;--rot:{rot:.2f}deg">'
            f'{html_module.escape(w)}</span>'
        )
    return "".join(out)


def _key_tokens(block: Dict[str, Any]) -> Optional[set]:
    """Tokens en minuscules extraits du champ `key_words` (v3) d'un bloc."""
    kws = block.get("key_words")
    if not isinstance(kws, list):
        return None
    tokens = set()
    for kw in kws:
        if isinstance(kw, str):
            for tok in kw.split():
                tokens.add(tok.strip(".,;:!?()«»\"'").lower())
    return tokens or None


def _instant_prononce(block: Dict[str, Any], cible: str) -> Optional[float]:
    """A quelle fraction de sa narration le bloc PRONONCE-t-il le mot vise ?

    POURQUOI CE CALCUL EXISTE. Le texte ECRIT au tableau et le texte DIT ne
    sont pas la meme chaine. Exemple releve le 07/08 sur un cours reel :

        ecrit : « Le Marketing : Identifier et satisfaire les besoins. »
        dit   : « Le marketing, c'est l'art et la science d'identifier ce que
                  les gens veulent et de leur offrir... »

    « Identifier » se trouve a ~40 % du texte ecrit mais a ~55 % de la
    narration. En declenchant le cercle a l'ecriture seule, il apparaissait
    pendant que la voix disait encore autre chose -- pres d'une seconde de
    decalage sur un bloc de six secondes, largement visible.

    On repere donc le mot dans la narration, en mots et non en caracteres :
    la parole avance a peu pres a mots constants, pas a caracteres constants.
    Renvoie None si le mot n'apparait pas dans la narration.
    """
    narration = str(block.get("narration") or "").strip()
    cible = (cible or "").strip().lower()
    if not narration or not cible:
        return None

    def normaliser(m: str) -> str:
        return m.strip(".,;:!?()«»\"'").lower()

    mots = [normaliser(m) for m in narration.split()]
    if not mots:
        return None

    premier = normaliser(cible.split()[0])
    for rang, mot in enumerate(mots):
        # `startswith` plutot qu'egalite : le francais elide et accorde
        # (« d'identifier », « identifie », « besoins »). Une egalite stricte
        # ratait la majorite des cibles.
        if mot.startswith(premier[:max(4, len(premier) - 2)]):
            # Fin du mot prononce, pas son debut : on entoure ce qui vient
            # d'etre dit.
            return min(1.0, (rang + 1) / len(mots))
    return None


def _annotation_svg(kind: str, start: float) -> str:
    """Cercle / souligné tracés à la main, puis effacés (transitoires)."""
    if kind == "underline":
        return (
            f'<svg class="ann ann-underline" viewBox="0 0 100 20" preserveAspectRatio="none">'
            f'<path pathLength="1" d="M2 11 Q 26 4 50 10 T 98 8" style="animation-delay:{start:.2f}s"/></svg>'
        )
    return (
        f'<svg class="ann ann-circle" viewBox="0 0 100 100" preserveAspectRatio="none">'
        f'<path pathLength="1" d="M50 9 C82 6 95 30 92 52 C89 78 60 95 33 92 C9 89 4 58 11 35 C17 15 41 8 63 11" '
        f'style="animation-delay:{start:.2f}s"/></svg>'
    )


def _block_html(pb: PlannedBlock, index: int, katex_renderer=None,
                recap_scenes: Optional[set] = None) -> str:
    b = pb.block
    btype = b.get("type", "paragraph")
    content = b.get("content") or ""
    write_dur = pb.write_end - pb.start
    target = b.get("emphasis_target")
    kind = b.get("emphasis") if _has_emphasis(b) else None
    ktoks = _key_tokens(b)
    in_recap = bool(recap_scenes) and pb.scene_index in recap_scenes

    # Formules : rendu KaTeX, apparition simple (on n'écrit pas une formule à la main).
    if btype in ("formula", "graph"):
        inner = (katex_renderer or _default_katex)(content)
        return (
            f'<div id="b{index}" class="blk blk-formula" '
            f'style="animation-delay:{pb.start:.2f}s">{inner}</div>'
        )

    # Découpe autour des mots visés par l'annotation, s'ils existent.
    body = ""
    if kind and target and target.strip():
        low, tl = content.lower(), target.strip().lower()
        i = low.find(tl)
        if i >= 0:
            before, hit, after = content[:i], content[i:i + len(target.strip())], content[i + len(target.strip()):]
            ratio_b = len(before) / max(1, len(content))
            ratio_h = len(hit) / max(1, len(content))
            hit_end = pb.start + write_dur * (ratio_b + ratio_h)

            # L'ANNOTATION ATTEND QUE LA VOIX PRONONCE LE MOT.
            # `hit_end` dit quand le mot finit d'etre ECRIT. La voix, elle, le
            # prononce ailleurs dans la phrase -- voir `_instant_prononce`. On
            # prend le PLUS TARD des deux : on n'entoure jamais un mot qui
            # n'est pas encore ecrit, et jamais avant que le professeur l'ait
            # dit.
            frac_dite = _instant_prononce(b, target)
            if frac_dite is not None:
                hit_end = max(hit_end, pb.start + write_dur * frac_dite)
            body = (
                _words_html(before, pb.start, write_dur * ratio_b, ktoks)
                + f'<span class="tgt {"hl" if kind == "highlight" else ""}">'
                + _words_html(hit, pb.start + write_dur * ratio_b, write_dur * ratio_h, ktoks)
                + (f'<span class="hlbar" style="animation-delay:{hit_end:.2f}s"></span>'
                   if kind == "highlight" else _annotation_svg(kind, hit_end))
                + "</span>"
                + _words_html(after, pb.start + write_dur * (ratio_b + ratio_h),
                              write_dur * (1 - ratio_b - ratio_h), ktoks)
            )
    if not body:
        body = _words_html(content, pb.start, write_dur, ktoks)
        # Annotation de repli : sur tout le bloc.
        if kind:
            body += (f'<span class="hlbar full" style="animation-delay:{pb.write_end:.2f}s"></span>'
                     if kind == "highlight" else _annotation_svg(kind, pb.write_end))

    label = {"definition": "Définition", "exercise": "Exercice", "correction": "Correction"}.get(btype)
    label_html = f'<div class="lbl" style="animation-delay:{pb.start:.2f}s">{label}</div>' if label else ""

    # Titre de scène : la plaquette se déploie (avec son numéro de chapitre), puis
    # les mots s'écrivent dessus.
    if btype == "title":
        chap = f'<div class="chap">{pb.scene_index + 1:02d}</div>'
        return (
            f'<div id="b{index}" class="blk blk-title" style="animation-delay:{pb.start:.2f}s">'
            f'{chap}<div class="txt" style="animation-delay:{pb.start:.2f}s">{body}</div></div>'
        )

    # Scène récap (beat v3) : chaque point à retenir est une carte à coche animée.
    if in_recap and btype == "paragraph":
        return (
            f'<div id="b{index}" class="blk blk-recap" style="animation-delay:{pb.start:.2f}s">'
            f'<div class="txt"><span class="chk" style="animation-delay:{pb.start:.2f}s">✓</span>'
            f'{body}</div></div>'
        )

    # Correction : tampon « validé » après le dernier mot (le prof approuve).
    if btype == "correction":
        body += f'<span class="stamp" style="animation-delay:{pb.write_end + 0.25:.2f}s">✓</span>'

    return (
        f'<div id="b{index}" class="blk blk-{btype}" style="animation-delay:{pb.start:.2f}s">'
        f'{label_html}<div class="txt">{body}</div></div>'
    )


# ─── Générique : la taille s'adapte au MOT LE PLUS LONG ─────────────────────
#
# LE DÉFAUT, MESURÉ AU NAVIGATEUR LE 05/09. Le titre était rendu à 88 px fixes,
# et `.iw {{ white-space:nowrap }}` rend les mots insécables -- ce dernier point
# ajouté exprès, parce que le navigateur coupait sinon en plein mot
# (« sec / ond degré », vu à l'image). Les deux ensemble donnent un
# débordement : la largeur utile est de 760 px, et
#     « L'interdépendance »  ->  897 px, soit 137 px HORS de la carte
#     « développement »      ->  736 px, soit 24 px de marge seulement
# Autrement dit : au-delà d'environ 14 caractères, le titre sortait du cadre.
#
# La correction ne consiste pas à retirer l'insécable -- ce serait rouvrir le
# défaut d'origine -- mais à DESCENDRE LA TAILLE jusqu'à ce que le mot le plus
# long tienne. Trois paliers suffisent pour couvrir tous les sujets scolaires.
INTRO_PALIERS = ((14, 88), (18, 68), (99, 54))   # (longueur max du mot, px)
INTRO_LARGEUR_UTILE = 900   # px disponibles pour le titre du générique


def _intro_taille(subject: str) -> int:
    """Taille du titre du générique, choisie sur le mot le plus long."""
    mots = subject.split() or [subject]
    plus_long = max(len(m) for m in mots)
    for limite, px in INTRO_PALIERS:
        if plus_long <= limite:
            return px
    return INTRO_PALIERS[-1][1]


def _intro_html(subject: str) -> str:
    """
    Générique : chaque lettre du titre entre séparément (délais répartis entre
    INTRO_LETTER_FROM et INTRO_LETTER_TO), puis le titre sort vers le haut.
    `subject` est DÉJÀ échappé par l'appelant.
    """
    # Les lettres sont groupées PAR MOT (conteneur insécable) : sans cela, le
    # navigateur coupait le titre en plein mot (« sec / ond degré », vu à l'image).
    words = subject.split()
    n = max(1, sum(len(w) for w in words))
    span = INTRO_LETTER_TO - INTRO_LETTER_FROM
    out, seen = [], 0
    for wi, word in enumerate(words):
        if wi:
            out.append(" ")
        letters = []
        for c in word:
            d = INTRO_LETTER_FROM + span * (seen / n)
            seen += 1
            letters.append(
                f'<span class="il" style="animation-delay:{d:.2f}s">{html_module.escape(c)}</span>')
        out.append(f'<span class="iw">{"".join(letters)}</span>')
    return (
        f'<div id="intro" style="animation-delay:{INTRO_SEC - INTRO_OUT_SEC:.2f}s">'
        f'<div id="intro-card"><div id="intro-kicker">Cours</div>'
        f'<div id="intro-title" style="font-size:{_intro_taille(subject)}px">'
        f'{"".join(out)}</div>'
        f'<div id="intro-rule"></div></div></div>'
    )


def _scene_starts(planned) -> List[float]:
    """Instant de début de chaque scène, déduit des blocs planifiés."""
    starts: Dict[int, float] = {}
    for pb in planned:
        starts.setdefault(pb.scene_index, pb.start)
    return [starts.get(i, 0.0) for i in range(max(starts) + 1)] if starts else []


def _first_blocks(planned) -> List[int]:
    """Index du premier bloc de chaque scène."""
    first: Dict[int, int] = {}
    for i, pb in enumerate(planned):
        first.setdefault(pb.scene_index, i)
    return [first.get(i, 0) for i in range(max(first) + 1)] if first else []


def build_page(
    storyboard: Dict[str, Any],
    narration: Optional[List[Dict[str, Any]]] = None,
    katex_renderer=None,
    measured: Optional[List[Dict[str, int]]] = None,
) -> Tuple[str, float]:
    """
    Construit la page HTML complète du cours et retourne (html, durée_totale_secondes).
    """
    planned, kf, total, doc_height, recalls = plan(storyboard, narration)

    # ── Positions RÉELLES, si elles ont été mesurées ───────────────────────
    # Première passe : `measured` est None -> page sans défilement, uniquement
    # destinée à être mesurée dans le navigateur.
    # Seconde passe : on connaît les vraies positions -> on recalcule les
    # mouvements de caméra dessus, donc la caméra vise juste.
    if measured:
        by_id = {m["id"]: m for m in measured if m.get("id")}
        for i, pb in enumerate(planned):
            m = by_id.get(f"b{i}")
            if m:
                pb.y = float(m["top"])
                pb.height = float(m["height"])
        kf, doc_height, recalls = _keyframes(
            planned, storyboard.get('scenes') or [], _scene_starts(planned),
            _first_blocks(planned), doc_height
        )
    subject = html_module.escape(str(storyboard.get("subject") or "Smart Whiteboard"))
    theme = storyboard.get("theme") or "notebook"
    handwriting = (storyboard.get("writing_style") or "handwriting") != "typed"

    # Keyframes de défilement, exprimées en pourcentage de la durée totale.
    scroll_kf = "\n".join(
        f"  {(f / total * 100):.3f}% {{ transform: translateY(-{v:.0f}px); }}"
        for f, v in kf if f <= total
    )

    # Annotations de rappel (posées sur des notions déjà écrites, plus haut).
    recall_html = "".join(
        f'<div class="recall" style="top:{r["y"]}px;height:{r["height"]}px">'
        f'{_annotation_svg(r["kind"], r["start"])}</div>'
        for r in recalls
    )

    recap_scenes = {si for si, sc in enumerate(storyboard.get("scenes") or [])
                    if isinstance(sc, dict) and sc.get("beat") == "recap"}
    blocks_html = "\n".join(_block_html(pb, i, katex_renderer, recap_scenes)
                            for i, pb in enumerate(planned))

    font_stack = (
        POLICES_MANUSCRITES[POLICE_MANUSCRITE]["css"] if handwriting
        else "'Inter','Noto Sans','Liberation Sans',sans-serif"
    )
    font_scale = (POLICES_MANUSCRITES[POLICE_MANUSCRITE]["echelle"]
                  if handwriting else 1.0)

    return _TEMPLATE.format(
        subject=subject,
        intro=_intro_html(str(storyboard.get("subject") or "Smart Whiteboard")),
        intro_card_in=INTRO_CARD_IN_SEC,
        intro_out=INTRO_OUT_SEC,
        theme=theme,
        total=f"{total:.2f}",
        doc_height=int(doc_height),
        scroll_kf=scroll_kf,
        blocks=blocks_html,
        recalls=recall_html,
        font_stack=font_stack,
        font_url=_font_url(),
        katex_css=(f'<link rel="stylesheet" href="{_katex_css_url()}">'
                   if _katex_css_url() else ""),
        font_size=int(FONT_SIZE * font_scale),
        line_h=LINE_H,
        pad_left=PAD_LEFT,
        pad_right=PAD_RIGHT,
        content_w=CONTENT_W,
        top_safe=TOP_SAFE,
        block_gap=BLOCK_GAP,
        # ── Marque et titre ────────────────────────────────────────────────
        vert=VERT,
        vert_sombre=VERT_SOMBRE,
        rouge=ROUGE,
        papier=PAPIER,
        encre=ENCRE,
        encre_pale=ENCRE_PALE,
        surligne=SURLIGNE,
        titre_echelle=TITRE_ECHELLE,
        titre_px=int(FONT_SIZE * font_scale * TITRE_ECHELLE),
        # Le trait vit sous le titre : il lui faut sa propre place, sans quoi
        # il chevaucherait la premiere ligne du corps.
        titre_trait=int(FONT_SIZE * font_scale * 0.11),
        titre_soulign_bas=int(FONT_SIZE * font_scale * 0.38),
        titre_trait_max=int(CONTENT_W * 0.78),
        intro_utile=INTRO_LARGEUR_UTILE,
        # Déplacements du filigrane, calculés sur la géométrie réelle : il part
        # en bas à gauche de la zone sûre, va au bas droit, puis remonte.
        # `MARQUE_L` est la largeur mesurée de l'ensemble toque + mot.
        marque_dx=CONTENT_W - MARQUE_W,
        # Du repos (bas de l'écran) jusqu'à la bande libre du haut. Calculé,
        # pas choisi : une valeur en dur se désynchroniserait du jour où
        # MARQUE_BAS, MARQUE_H ou MARQUE_HAUT bougeraient.
        marque_dy=MARQUE_HAUT - (VIEW_H - MARQUE_BAS - MARQUE_H),
        marque_w=MARQUE_W,
        marque_bas=MARQUE_BAS,
        marque_h=MARQUE_H,
        logo_url=_logo_url(),
        # SANS LE FICHIER, PAS DE FILIGRANE DU TOUT. Un `background-image`
        # pointant sur une URL vide laisserait un rectangle de 120 px collé
        # dans la page ; mieux vaut que la marque soit absente que fausse.
        marque=('  <div id="marque"></div>' if _logo_url() else
                "  <!-- filigrane omis : logo introuvable dans LOGO_PATHS -->"),
        annot_total=ANNOT_TOTAL_SEC,
        # Le tracé, le maintien et l'effacement sont exprimés en pourcentage de la
        # durée totale de l'annotation, puisque les keyframes CSS sont en pourcentage.
        draw_pct=ANNOT_DRAW_SEC / ANNOT_TOTAL_SEC * 100,
        hold_pct=(ANNOT_DRAW_SEC + ANNOT_HOLD_SEC) / ANNOT_TOTAL_SEC * 100,
    ), total


_TEMPLATE = """<!DOCTYPE html>
<html lang="fr"><head><meta charset="UTF-8">
<title>{subject}</title>
{katex_css}
<style>
* {{ margin:0; padding:0; box-sizing:border-box; }}
@font-face {{
  font-family:'ManuscritLocal';
  src:url('{font_url}') format('truetype');
  font-weight:400 700; font-display:block;
}}
body {{
  width:1080px; height:1920px; overflow:hidden;
  background:{papier}; color:{encre};
  font-family:{font_stack};
}}

/* ── La feuille ─────────────────────────────────────────────────────────
   ON QUITTE LE CAHIER D'ÉCOLIER SANS QUITTER LE CAHIER.
   Le fond portait des lignes bleues tous les 48 px et une marge rouge à
   76 px : la page d'un enfant qui apprend à écrire. Le texte manuscrit ne
   suit d'ailleurs PAS ces lignes -- il est posé dessus, ce qui se voit.
   Un quadrillage large et pâle donne le même repère de papier sans le
   registre scolaire, et n'entre jamais en concurrence avec l'écriture. */
#paper {{
  position:absolute; top:0; left:0; width:1080px; height:{doc_height}px;
  /* LE PLAN LE SUPPOSAIT, LE RENDU NE LE FAISAIT PAS.
     `_plan()` démarre son calcul de défilement à `y = TOP_SAFE`, mais la
     feuille n'avait aucune marge haute : les blocs commençaient à 0. Le
     premier titre d'une page se retrouvait donc collé à 18 px du bord
     supérieur -- sous le cadre décoratif et le bandeau du sujet -- alors que
     le défilement, lui, était calculé comme s'il démarrait 300 px plus bas.
     Mesuré au navigateur en 1080×1920 : `top` du titre = 18 px.
     Le padding réconcilie les deux, et donne au titre l'air qu'il lui faut. */
  padding-top:{top_safe}px;
  background-color:{papier};
  background-image:
    linear-gradient(rgba(27,36,48,.055) 1px, transparent 1px),
    linear-gradient(90deg, rgba(27,36,48,.055) 1px, transparent 1px);
  background-size:72px 72px;
  will-change:transform;
}}
/* Le défilement : une seule animation, pilotée par les keyframes calculées. */
/* `linear` faisait un défilement mécanique et brutal. La courbe ci-dessous démarre et
   s'arrête en douceur : le mouvement est plus lisible et ne laisse plus de traînée. */
body.recording #paper {{ animation:scroll {total}s cubic-bezier(.33,0,.15,1) forwards; }}
@keyframes scroll {{
{scroll_kf}
}}

/* ── Blocs ─────────────────────────────────────────────────────────── */
/* FLUX NATUREL : les blocs s'empilent, ils ne peuvent donc PAS se chevaucher.
   Avant, ils étaient placés à une hauteur estimée en Python — et sur du contenu
   réel (diagramme, définition longue) l'estimation était fausse : les textes se
   superposaient. Les positions réelles sont désormais mesurées dans le navigateur. */
.blk {{
  position:relative; margin:0 auto {block_gap}px auto;
  width:{content_w}px;
}}
/* Le bloc n'apparaît PLUS d'un coup : seuls les mots se révèlent, l'un après
   l'autre, pour donner l'impression d'une main qui écrit en continu. */

.txt {{ font-size:{font_size}px; line-height:{line_h}; font-weight:600; white-space:pre-wrap; }}

/* Révélation MOT PAR MOT : chaque mot a son propre délai. Tout en CSS. */
/* ── LE MOT S'ÉCRIT, IL N'APPARAÎT PLUS ──────────────────────────────────
   TROIS CAUSES faisaient le « robotique » signalé par Jocelyn le 08/09, et
   aucune n'était le rythme -- celui-ci est correct depuis toujours,
   `_words_html()` répartissant le délai au prorata des caractères écrits :

     1. la DURÉE était fixe : `.18s`, que le mot fasse deux lettres ou douze.
        « où » et « photosynthèse » s'affichaient à la même vitesse.
     2. la COURBE était `linear` -- la seule qu'aucune main n'a jamais eue.
     3. le mot n'avait AUCUN SENS DE LECTURE : il surgissait d'un bloc, par
        opacité, alors que le stylo, lui, avance de gauche à droite.

   COMMENT ON RÉPARE. On peint derrière le mot un dégradé mi-encre mi-vide, et
   on demande au navigateur de ne l'afficher QUE dans la forme des lettres
   (`background-clip:text`). Faire glisser ce dégradé remplit le mot de gauche
   à droite. C'est la technique des plateformes -- Doodly la nomme
   « standard wipe reveal ».

   ÉPROUVÉ DANS LES CONDITIONS DE LA CAPTURE, pas seulement à l'écran : rendu
   sur LWS le 08/09 avec les mêmes drapeaux Chromium (rendu logiciel, sans
   carte), la progression des pixels d'encre est régulière et monotone --
   0, 3 475, 6 561, 9 906, 12 901 aux cinq positions. Ni texte invisible, ni
   texte plein d'un coup : les deux façons dont cette propriété peut échouer
   en rendu logiciel.

   `--d` (durée) et `--dy` / `--rot` (l'écart de la main) sont posés EN LIGNE
   par `_words_html`, mot par mot. */
/* LE DÉGRADÉ PREND `currentColor`, ET NON UNE COULEUR FIGÉE.
   Un dégradé en encre en dur aurait écrit EN NOIR les blocs qui ont leur
   propre couleur — la définition, en vert, s'affichait en encre.
   `currentColor` fait suivre la couleur héritée du bloc.

   ET C'EST POURQUOI `color` N'EST PAS MIS À `transparent` : ce serait rendre
   `currentColor` transparent, donc effacer le dégradé lui-même. Seul
   `-webkit-text-fill-color` est neutralisé — il rend le glyphe transparent
   tout en laissant `color` porter sa vraie valeur. */
.w {{
  display:inline-block; position:relative;
  background-image:linear-gradient(90deg,currentColor 50%,rgba(0,0,0,0) 50%);
  background-size:200% 100%;
  background-position:100% 0;
  -webkit-background-clip:text; background-clip:text;
  -webkit-text-fill-color:transparent;
  transform:translateY(var(--dy,0)) rotate(var(--rot,0deg));
}}
body.recording .w {{
  animation:wIn var(--d,.28s) cubic-bezier(.32,.06,.28,1) forwards;
}}
@keyframes wIn {{
  0%   {{ background-position:100% 0;
          transform:translateY(var(--dy,0)) rotate(var(--rot,0deg)); }}
  100% {{ background-position:0 0; transform:translateY(0) rotate(0deg); }}
}}

/* ── La MAIN qui écrit ─────────────────────────────────────────── */
/* Une main tenant un stylo apparaît au bout de CHAQUE mot pendant qu'il s'écrit,
   puis disparaît quand le mot suivant prend le relais : à 25 images/seconde, l'œil
   perçoit une main qui avance le long de la ligne (technique VideoScribe).
   Le délai est hérité du mot (`animation-delay:inherit`) : aucun calcul de position
   n'est nécessaire, la main est portée par le mot lui-même. Tout reste en CSS, donc
   compatible avec la capture par tranches. */
/* LE STYLO SEUL, PAS UNE MAIN.
   La main était faite de six primitives -- un cercle beige pour la paume, deux
   traits pour le stylo, un triangle pour la pointe, un petit cercle pour le
   pouce. À l'échelle où elle passe (118 px sur 1080), cela se lisait comme une
   tache, pas comme une main.

   Trois formes suffisent, et elles disent la même chose : un corps, un
   capuchon, une pointe. Le stylo est en outre NEUTRE -- il ne pose aucune
   question de teinte de peau devant un public à qui la capsule s'adresse.
   Les couleurs sont celles de la marque : encre pour le corps, vert pour le
   capuchon. */
body.recording .w::after {{
  content:""; position:absolute; left:100%; top:.34em; margin-left:-6px;
  width:92px; height:92px; z-index:6; opacity:0; pointer-events:none;
  background:url("data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 132 132'><path d='M18 18 66 66' stroke='%231b2430' stroke-width='15' stroke-linecap='round'/><path d='M60 60 92 92' stroke='%23388840' stroke-width='17' stroke-linecap='round'/><path d='M5 5 26 13 13 26 Z' fill='%231b2430'/></svg>") no-repeat;
  background-size:contain;
  animation:penHop .38s linear forwards;
  animation-delay:inherit;
}}
@keyframes penHop {{
  0%   {{ opacity:0; transform:translateY(3px) rotate(-2deg); }}
  12%  {{ opacity:1; }}
  80%  {{ opacity:1; transform:translateY(0) rotate(1.5deg); }}
  100% {{ opacity:0; }}
}}
/* Pas de main sur les mots du générique ni des annotations. */
body.recording #intro .w::after, body.recording .il::after {{ content:none; }}

/* ── TYPOGRAPHIE CINÉTIQUE (v3) : les mots-clés ressortent ──────────────── */
/* Ce qu'un prof écrirait en rouge : plus gros, en couleur, pop élastique au
   moment exact où le mot s'écrit (synchronisé avec la voix). */
/* LE MOT-CLÉ ANNULE LE MASQUE, ET C'EST NÉCESSAIRE.
   `.w` peint le texte via un dégradé découpé dans les lettres et met
   `-webkit-text-fill-color:transparent`. Or cette propriété PRIME sur `color` :
   sans la remettre ici, le mot-clé héritait du dégradé d'encre et s'affichait
   en NOIR, perdant le rouge — vu à l'image le 08/09 sur « magma ».
   Le mot-clé ne se balaie donc pas : il surgit en rouge, d'un coup. C'est
   voulu — c'est le geste du professeur qui change de stylo, et le contraste
   avec les mots balayés autour est précisément ce qui le fait ressortir. */
.w.kw {{
  display:inline-block; font-weight:800; font-size:1.12em;
  background-image:none;
  color:{rouge}; -webkit-text-fill-color:{rouge};
}}
body.recording .w.kw {{ animation:kwIn .55s cubic-bezier(.2,1.6,.4,1) forwards; }}
@keyframes kwIn {{
  0%   {{ opacity:0; transform:scale(1.55) rotate(-3deg); }}
  55%  {{ opacity:1; transform:scale(1.14) rotate(1deg); }}
  100% {{ opacity:1; transform:scale(1) rotate(0); }}
}}

/* ── Numéro de chapitre sur la plaquette de titre ────────────────────── */
.chap {{
  position:absolute; top:-22px; left:-14px; z-index:2;
  font-family:'Inter','Noto Sans',sans-serif; font-size:26px; font-weight:800;
  color:#fff; background:{encre}; padding:8px 18px; border-radius:14px;
  box-shadow:0 8px 18px rgba(15,44,92,.35); opacity:0;
}}
body.recording .chap {{ animation:popIn .5s cubic-bezier(.2,1.6,.35,1) forwards; animation-delay:inherit; }}

/* ── Carte récap : point à retenir avec coche animée ──────────────────── */
.blk-recap .txt {{
  position:relative; background:#fff; border:2px solid rgba(56,136,64,.28); border-radius:18px;
  padding:20px 24px 20px 74px; box-shadow:0 10px 24px rgba(24,64,130,.10);
}}
.chk {{
  position:absolute; left:20px; top:18px; width:38px; height:38px; border-radius:50%;
  background:{vert}; color:#fff; text-align:center;
  font:800 24px/38px 'Inter','Noto Sans',sans-serif; opacity:0;
}}
body.recording .chk {{ animation:popIn .5s cubic-bezier(.2,1.6,.35,1) forwards; }}

/* ── Tampon « validé » du professeur sur les corrections ───────────────── */
.stamp {{
  display:inline-block; margin-left:16px; width:46px; height:46px; vertical-align:middle;
  border:3px solid {vert}; border-radius:50%; color:{vert}; text-align:center;
  font:800 26px/40px 'Inter','Noto Sans',sans-serif; opacity:0; transform:rotate(-12deg);
}}
body.recording .stamp {{ animation:stampIn .45s cubic-bezier(.2,1.8,.4,1) forwards; }}
@keyframes stampIn {{
  0%   {{ opacity:0; transform:scale(2.4) rotate(-30deg); }}
  100% {{ opacity:1; transform:scale(1) rotate(-12deg); }}
}}

/* Badge de bloc : entre en « pop » (surgit, dépasse légèrement, se pose). */
.lbl {{
  font-family:'Inter','Noto Sans',sans-serif; font-size:24px; font-weight:800;
  letter-spacing:.08em; text-transform:uppercase; color:#fff; margin-bottom:10px;
  background:{vert}; display:inline-block; padding:6px 18px; border-radius:22px;
  box-shadow:0 6px 16px rgba(26,161,121,.35);
  opacity:0; transform-origin:left center;
}}
body.recording .lbl {{ animation:popIn .5s cubic-bezier(.2,1.6,.35,1) forwards; }}
@keyframes popIn {{
  0%   {{ opacity:0; transform:scale(.4) translateY(14px); }}
  60%  {{ opacity:1; transform:scale(1.08) translateY(-2px); }}
  100% {{ opacity:1; transform:scale(1) translateY(0); }}
}}

/* Le liseré de définition apparaît AVEC le premier mot (délai hérité du bloc),
   et non dès la première image — défaut vu à l'image : barre verte orpheline. */
.blk-definition .txt {{ color:{vert}; padding-left:28px; }}
.blk-definition::before {{
  content:""; position:absolute; left:0; top:4px; bottom:4px; width:6px;
  border-radius:4px; background:{vert}; opacity:0;
}}
body.recording .blk-definition::before {{
  animation:wIn .4s ease-out forwards; animation-delay:inherit;
}}
.blk-exercise   {{ }}
.blk-exercise .txt   {{ background:rgba(76,154,255,.10); padding:20px 24px; border-radius:14px; }}
.blk-correction .txt {{ background:rgba(26,161,121,.10); padding:20px 24px; border-radius:14px; }}
/* Les encadrés se teintent PROGRESSIVEMENT pendant que le texte s'écrit, au lieu
   d'apparaître d'un coup — sinon l'oeil perçoit « un bloc », pas une main. */
.blk-exercise .txt, .blk-correction .txt {{ opacity:.001; }}
body.recording .blk-exercise .txt,
body.recording .blk-correction .txt {{ animation:wIn 1.2s ease-out forwards; }}
/* ── TITRE DE SCÈNE : ce qu'on écrit en haut d'une page de cahier ────────
   CE QUI N'ALLAIT PAS, et c'est mesurable : `.blk-title .txt` portait
   `font-size:{font_size}px` -- EXACTEMENT la taille du corps du texte. Le
   titre d'un chapitre avait donc la même taille que la phrase qui le suit.
   Il était en outre enfermé dans une plaquette à dégradé bleu-vert, arrondie
   à 24 px : une pastille collée en haut de page, pas un titre.

   CE QU'ON FAIT À LA PLACE -- ce qu'un professeur fait réellement au tableau :
   il écrit le titre PLUS GROS, au milieu, et il le SOULIGNE. Trois gestes,
   aucun décor.
     · {titre_px} px contre {font_size} px pour le corps ({titre_echelle}×) ;
     · centré, sans fond ni cadre : le papier reste le papier ;
     · souligné d'un trait de marque qui SE TIRE de gauche à droite, comme un
       trait de règle -- l'animation dure le temps que le titre s'installe.
   Le trait est un pseudo-élément : aucun nœud supplémentaire, et tout reste
   en CSS pur, condition de la capture par tranches. */
.blk-title {{ margin-top:18px; }}
.blk-title .txt {{
  font-size:{titre_px}px; line-height:1.16; text-align:center; font-weight:700;
  color:{encre}; position:relative; display:block;
  padding:0 10px {titre_soulign_bas}px;
  opacity:0; transform-origin:center;
}}
.blk-title .txt::after {{
  content:""; position:absolute; left:50%; bottom:0; height:{titre_trait}px;
  width:0; border-radius:{titre_trait}px; background:{vert};
  transform:translateX(-50%);
}}
body.recording .blk-title .txt {{ animation:titreIn .55s cubic-bezier(.2,1.3,.35,1) forwards; }}
body.recording .blk-title .txt::after {{
  animation:soulignIn .62s cubic-bezier(.35,.9,.3,1) forwards;
  animation-delay:inherit;
}}
@keyframes titreIn {{
  0%   {{ opacity:0; transform:translateY(26px); }}
  100% {{ opacity:1; transform:translateY(0); }}
}}
/* Le trait part du centre et s'ouvre vers les deux bords : c'est le geste de
   la règle posée au milieu du mot, pas un balayage d'écran. */
@keyframes soulignIn {{
  0%   {{ width:0; }}
  100% {{ width:min(78%, {titre_trait_max}px); }}
}}
/* Formule : surgit en « pop » centré (on n'écrit pas une formule à la main). */
.blk-formula {{ text-align:center; padding:26px; background:rgba(56,136,64,.07); border:1px solid rgba(56,136,64,.24); border-radius:16px; font-size:44px; opacity:0; }}
body.recording .blk-formula {{ animation:formulaIn .8s cubic-bezier(.2,1.4,.4,1) forwards; }}
@keyframes formulaIn {{
  0%   {{ opacity:0; transform:scale(.82) translateY(18px); }}
  70%  {{ opacity:1; transform:scale(1.03) translateY(-3px); }}
  100% {{ opacity:1; transform:scale(1) translateY(0); }}
}}

/* ── Annotations manuscrites ──────────────────────────────────────── */
.tgt {{ position:relative; display:inline-block; }}
.ann {{ position:absolute; overflow:visible; pointer-events:none; }}
.ann-underline {{ left:-6px; right:-6px; bottom:-18px; width:calc(100% + 12px); height:38px; }}
.ann-circle    {{ left:-18px; top:-20px; width:calc(100% + 36px); height:calc(100% + 40px); }}
.ann path {{
  fill:none; stroke:{vert}; stroke-width:2.6; stroke-linecap:round;
  stroke-dasharray:1; stroke-dashoffset:1; opacity:0;
}}
body.recording .ann path {{ animation:draw {annot_total}s linear forwards; }}
@keyframes draw {{
  0%   {{ stroke-dashoffset:1; opacity:0; }}
  1%   {{ opacity:1; }}
  {draw_pct:.1f}%  {{ stroke-dashoffset:0; opacity:1; }}
  {hold_pct:.1f}%  {{ stroke-dashoffset:0; opacity:1; }}
  100% {{ stroke-dashoffset:1; opacity:0; }}
}}

/* Surlignage : reste en place (c'est un marqueur). */
.hlbar {{
  position:absolute; left:-6px; top:8%; height:84%; width:0;
  background:{surligne}; opacity:1; border-radius:4px; transform:skewX(-3deg); z-index:-1;
}}
body.recording .hlbar {{ animation:sweep .45s ease-out forwards; }}
@keyframes sweep {{ from {{ width:0 }} to {{ width:calc(100% + 12px) }} }}

/* Annotation de RAPPEL : posée sur une notion écrite plus haut. */
.recall {{ position:absolute; left:{pad_left}px; width:{content_w}px; pointer-events:none; }}

/* ── Bandeau fixe + masque ────────────────────────────────────────── */
#veil {{
  position:fixed; top:0; left:0; right:0; height:{top_safe}px;
  background:linear-gradient({papier} 62%, rgba(247,244,236,0) 100%);
  z-index:8; pointer-events:none;
}}
#bar {{
  /* Meme marge de securite horizontale que le contenu (cf. PAD_LEFT/PAD_RIGHT) :
     sans elle, le badge du sujet se faisait rogner par le crop TikTok du feed. */
  position:fixed; top:44px; left:{pad_left}px; right:{pad_right}px; z-index:9;
  display:flex; justify-content:space-between; align-items:center;
  font-family:'Inter','Noto Sans',sans-serif;
}}
#bar .subject {{
  font-size:26px; font-weight:800; color:#fff; background:{vert};
  padding:8px 22px; border-radius:30px;
  /* Le badge grandit avec le sujet, et rien ne le bornait. Mesure au
     navigateur : 565 px pour 33 caractères, soit ~17 px par caractère --
     au-delà d'environ 45 caractères il sortait de la zone sûre du feed.
     On borne, et on coupe proprement plutôt que de laisser filer. */
  max-width:{content_w}px; overflow:hidden; text-overflow:ellipsis;
  white-space:nowrap;
}}
#frame {{
  position:fixed; inset:18px; border-radius:26px;
  border:4px solid rgba(59,111,224,.30); z-index:10; pointer-events:none;
}}

/* ── Barre de progression du cours (fine, en bas, sur toute la vidéo) ─────── */
#prog {{
  position:fixed; left:34px; right:34px; bottom:30px; height:7px; z-index:11;
  border-radius:6px; background:rgba(59,111,224,.14); overflow:hidden;
}}
#prog i {{
  display:block; height:100%; border-radius:6px;
  background:linear-gradient(90deg,{vert},{rouge});
  transform:scaleX(0); transform-origin:left center;
}}
body.recording #prog i {{ animation:progGrow {total}s linear forwards; }}
@keyframes progGrow {{ to {{ transform:scaleX(1); }} }}

/* ── GÉNÉRIQUE D'OUVERTURE ───────────────────────────────────────────────
   LA CARTE A DISPARU, ET C'EST LE FOND DE L'AFFAIRE.
   Le titre était posé sur un rectangle en dégradé bleu-vert de 880 px, arrondi
   à 44 px, avec ombre portée. Ce rectangle ne disait rien du cours : il
   occupait 880 px de large pour encadrer du texte, et ne laissait que 760 px
   utiles -- d'où le débordement mesuré (cf. INTRO_PALIERS).

   En le retirant, le titre gagne 140 px de largeur, et le générique devient
   LA PREMIÈRE PAGE DU CAHIER plutôt qu'une diapositive collée devant. La
   sortie n'est plus une transition entre deux mondes : c'est la même feuille
   qui remonte et sur laquelle le cours s'écrit. */
#intro {{
  position:fixed; inset:0; z-index:30; display:flex; align-items:center;
  justify-content:center;
  background-color:{papier};
  background-image:
    linear-gradient(rgba(27,36,48,.055) 1px, transparent 1px),
    linear-gradient(90deg, rgba(27,36,48,.055) 1px, transparent 1px);
  background-size:72px 72px;
}}
body.recording #intro {{ animation:introOut {intro_out}s cubic-bezier(.5,0,.75,.2) forwards; }}
@keyframes introOut {{
  0%   {{ opacity:1; transform:translateY(0); }}
  100% {{ opacity:0; transform:translateY(-120px); visibility:hidden; }}
}}
#intro-card {{
  width:{intro_utile}px; padding:0 40px; text-align:center;
  opacity:0; transform:translateY(52px);
}}
body.recording #intro-card {{ animation:introCard {intro_card_in}s cubic-bezier(.18,1.3,.35,1) forwards; }}
@keyframes introCard {{
  0%   {{ opacity:0; transform:translateY(52px); }}
  100% {{ opacity:1; transform:translateY(0); }}
}}
#intro-kicker {{
  font-family:'Inter','Noto Sans',sans-serif; font-size:28px; font-weight:700;
  letter-spacing:.38em; text-transform:uppercase; color:{vert};
  margin-bottom:38px;
}}
/* La taille est posée EN LIGNE par `_intro_taille()`, palier par palier :
   elle dépend du titre, elle ne peut donc pas vivre dans la feuille de style. */
#intro-title {{
  font-family:{font_stack}; font-weight:700;
  line-height:1.08; color:{encre}; text-wrap:balance;
}}
/* Chaque lettre du titre surgit séparément, en cascade — les mots restent insécables. */
.iw {{ display:inline-block; white-space:nowrap; }}
.il {{ display:inline-block; opacity:0; }}
body.recording .il {{ animation:letterIn .45s cubic-bezier(.2,1.5,.4,1) forwards; }}
@keyframes letterIn {{
  0%   {{ opacity:0; transform:translateY(58px) scale(.6) rotate(6deg); }}
  100% {{ opacity:1; transform:translateY(0) scale(1) rotate(0); }}
}}
#intro-rule {{
  width:220px; height:9px; margin:46px auto 0; border-radius:5px;
  background:{rouge}; transform:scaleX(0);
}}

/* ── LA MARQUE QUI SE DÉPLACE ────────────────────────────────────────────
   POURQUOI ELLE BOUGE. C'est la mécanique du filigrane TikTok, et elle a une
   raison précise : un logo fixe se recadre, se floute ou se masque en un
   geste. Un logo qui change de coin doit être suivi image par image — il
   survit donc au repartage, qui est exactement ce qu'on veut d'une marque.

   POURQUOI C'EST COMPATIBLE AVEC LA CAPTURE. `record_scene.js:102` avance
   chaque animation par `a.currentTime = ms`. Sur une animation INFINIE, le
   navigateur ramène ce temps modulo la durée du cycle : la position du logo à
   l'instant t est donc la même quelle que soit la tranche qui la calcule.
   Le rendu reste déterministe, condition de la capture en trois tranches
   parallèles. Tout est en CSS, aucune ligne de JavaScript.

   POURQUOI IL SAUTE AU LIEU DE GLISSER. Un logo qui traverse la page en
   glissant passe SUR le texte pendant tout son trajet. Il s'efface donc,
   se replace, et revient : on ne le voit jamais en travers d'un mot.

   Trois positions seulement, toutes hors de la colonne de lecture : bas
   gauche, bas droite, haut droite. Le haut gauche est pris par le badge du
   sujet (`#bar`). Cycle de 18 s, soit 6 s par coin. */
#marque {{
  position:fixed; left:{pad_left}px; bottom:{marque_bas}px; z-index:11;
  width:{marque_w}px; height:{marque_h}px;
  background:url("{logo_url}") no-repeat center;
  background-size:contain;
  pointer-events:none; opacity:0;
}}
body.recording #marque {{
  animation:marqueRonde 18s steps(1, end) infinite,
            marqueFondu 18s ease-in-out infinite;
}}
/* Le déplacement est en marches (`steps`) : la position ne change qu'aux
   instants où le fondu est à zéro. Les deux animations partagent la même
   durée, donc les marches tombent toujours dans les creux. */
@keyframes marqueRonde {{
  0%   {{ transform:translate(0,0); }}
  33%  {{ transform:translate({marque_dx}px, 0); }}
  66%  {{ transform:translate({marque_dx}px, {marque_dy}px); }}
  100% {{ transform:translate(0,0); }}
}}
@keyframes marqueFondu {{
  0%,2%     {{ opacity:0; }}
  6%,29%    {{ opacity:.55; }}
  33%       {{ opacity:0; }}
  39%,62%   {{ opacity:.55; }}
  66%       {{ opacity:0; }}
  72%,95%   {{ opacity:.55; }}
  100%      {{ opacity:0; }}
}}
body.recording #intro-rule {{ animation:ruleIn .5s ease-out 1.35s forwards; }}
@keyframes ruleIn {{ to {{ transform:scaleX(1); }} }}
</style></head>
<body class="theme-{theme}">
  <div id="paper">
{blocks}
{recalls}
  </div>
  <div id="veil"></div>
{marque}
  <div id="bar"><span class="subject">{subject}</span></div>
  <div id="frame"></div>
  <div id="prog"><i></i></div>
{intro}
</body></html>
"""


def write_page(
    storyboard: Dict[str, Any],
    output_html: Path,
    narration: Optional[List[Dict[str, Any]]] = None,
    katex_renderer=None,
    measured: Optional[List[Dict[str, int]]] = None,
) -> Tuple[Path, float]:
    """
    Écrit la page et retourne (chemin, durée totale en secondes).

    `measured` : positions réelles des blocs relevées dans le navigateur. Sans elles,
    la page est produite avec des positions estimées — c'est la passe de mesure.
    """
    html, total = build_page(storyboard, narration, katex_renderer, measured)
    output_html = Path(output_html)
    output_html.parent.mkdir(parents=True, exist_ok=True)
    output_html.write_text(html, encoding="utf-8")
    logger.info("[page] %s scenes -> %.1f s, page %s",
                len(storyboard.get("scenes") or []), total, output_html.name)
    return output_html, total


if __name__ == "__main__":
    import sys
    logging.basicConfig(level=logging.INFO)
    if len(sys.argv) < 3:
        print("Usage: python whiteboard_page_builder.py <storyboard.json> <sortie.html>")
        sys.exit(1)
    sb = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    p, d = write_page(sb, Path(sys.argv[2]))
    print(f"OK -> {p} ({d:.1f} s)")

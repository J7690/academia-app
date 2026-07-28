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
FONT_PATHS = [
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
TOP_SAFE = 190       # zone réservée au bandeau fixe
BLOCK_GAP = 46

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
CHARS_PER_LINE = 30   # approximation pour estimer la hauteur


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
            for b, d in zip(blocks, block_durs):
                a = ANNOT_TOTAL_SEC if _has_emphasis(b) else 0.0
                h = _estimate_height(b)
                planned.append(PlannedBlock(b, si, y, h, t, t + d, t + d + a))
                t += d + a
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
    for w in words:
        delay = start + duration * (consumed / total_chars)
        consumed += len(w)
        bare = w.strip().strip(".,;:!?()«»\"'").lower()
        cls = "w kw" if key_tokens and bare and bare in key_tokens else "w"
        out.append(
            f'<span class="{cls}" style="animation-delay:{delay:.2f}s">'
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


def _intro_html(subject: str) -> str:
    """
    Carte-titre du générique : chaque lettre du titre entre séparément (délais
    répartis entre INTRO_LETTER_FROM et INTRO_LETTER_TO), la carte sort ensuite.
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
        f'<div id="intro-title">{"".join(out)}</div>'
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
        "'CaveatLocal','Caveat','Patrick Hand',cursive" if handwriting
        else "'Inter','Noto Sans','Liberation Sans',sans-serif"
    )
    font_scale = 1.28 if handwriting else 1.0

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
  font-family:'CaveatLocal';
  src:url('{font_url}') format('truetype');
  font-weight:400 700; font-display:block;
}}
body {{
  width:1080px; height:1920px; overflow:hidden;
  background:#fffdf7; color:#20303f;
  font-family:{font_stack};
}}

/* ── La feuille : lignes de cahier + marge rouge, sur toute la hauteur ── */
#paper {{
  position:absolute; top:0; left:0; width:1080px; height:{doc_height}px;
  background-color:#fffdf7;
  background-image:
    linear-gradient(90deg, transparent 76px, #e8896b 76px, #e8896b 80px, transparent 80px),
    linear-gradient(#a9c7e8 2px, transparent 2px);
  background-size:100% 48px;
  background-position:0 100px;
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
.w {{ opacity:0; display:inline; position:relative; }}
body.recording .w {{ animation:wIn .18s linear forwards; }}
@keyframes wIn {{ from {{ opacity:0 }} to {{ opacity:1 }} }}

/* ── La MAIN qui écrit ─────────────────────────────────────────── */
/* Une main tenant un stylo apparaît au bout de CHAQUE mot pendant qu'il s'écrit,
   puis disparaît quand le mot suivant prend le relais : à 25 images/seconde, l'œil
   perçoit une main qui avance le long de la ligne (technique VideoScribe).
   Le délai est hérité du mot (`animation-delay:inherit`) : aucun calcul de position
   n'est nécessaire, la main est portée par le mot lui-même. Tout reste en CSS, donc
   compatible avec la capture par tranches. */
body.recording .w::after {{
  content:""; position:absolute; left:100%; top:.34em; margin-left:-8px;
  width:118px; height:118px; z-index:6; opacity:0; pointer-events:none;
  background:url("data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 132 132'><circle cx='92' cy='92' r='34' fill='%23f2c29b'/><path d='M14 14 62 62' stroke='%232f4160' stroke-width='15' stroke-linecap='round'/><path d='M56 56 78 78' stroke='%23d9a05f' stroke-width='17' stroke-linecap='round'/><path d='M5 5 24 12 12 24 Z' fill='%231f2d3f'/><circle cx='70' cy='99' r='13' fill='%23e5b088'/></svg>") no-repeat;
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
.w.kw {{ display:inline-block; color:#d4452e; font-weight:800; font-size:1.12em; }}
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
  color:#fff; background:#0f2c5c; padding:8px 18px; border-radius:14px;
  box-shadow:0 8px 18px rgba(15,44,92,.35); opacity:0;
}}
body.recording .chap {{ animation:popIn .5s cubic-bezier(.2,1.6,.35,1) forwards; animation-delay:inherit; }}

/* ── Carte récap : point à retenir avec coche animée ──────────────────── */
.blk-recap .txt {{
  position:relative; background:#fff; border:2px solid #d9e6f7; border-radius:18px;
  padding:20px 24px 20px 74px; box-shadow:0 10px 24px rgba(24,64,130,.10);
}}
.chk {{
  position:absolute; left:20px; top:18px; width:38px; height:38px; border-radius:50%;
  background:#1aa179; color:#fff; text-align:center;
  font:800 24px/38px 'Inter','Noto Sans',sans-serif; opacity:0;
}}
body.recording .chk {{ animation:popIn .5s cubic-bezier(.2,1.6,.35,1) forwards; }}

/* ── Tampon « validé » du professeur sur les corrections ───────────────── */
.stamp {{
  display:inline-block; margin-left:16px; width:46px; height:46px; vertical-align:middle;
  border:3px solid #1aa179; border-radius:50%; color:#1aa179; text-align:center;
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
  background:#1aa179; display:inline-block; padding:6px 18px; border-radius:22px;
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
.blk-definition .txt {{ color:#1aa179; padding-left:28px; }}
.blk-definition::before {{
  content:""; position:absolute; left:0; top:4px; bottom:4px; width:6px;
  border-radius:4px; background:#1aa179; opacity:0;
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
/* Plaquette de titre de scène : se DÉPLOIE (glisse + grossit) avant que les mots
   ne s'écrivent dessus — l'entrée « spot publicitaire » demandée. */
.blk-title .txt {{
  font-size:{font_size}px; text-align:center; font-weight:800; color:#fff;
  background:linear-gradient(135deg,#3b6fe0,#1aa179);
  padding:26px 38px; border-radius:24px; box-shadow:0 14px 34px rgba(0,0,0,.18);
  opacity:0; transform-origin:center;
}}
body.recording .blk-title .txt {{ animation:plaqueIn .65s cubic-bezier(.2,1.4,.35,1) forwards; }}
@keyframes plaqueIn {{
  0%   {{ opacity:0; transform:translateX(-46px) scale(.88); }}
  100% {{ opacity:1; transform:translateX(0) scale(1); }}
}}
/* Formule : surgit en « pop » centré (on n'écrit pas une formule à la main). */
.blk-formula {{ text-align:center; padding:26px; background:#eef5ff; border:1px solid #cfe0fb; border-radius:16px; font-size:44px; opacity:0; }}
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
  fill:none; stroke:#1aa179; stroke-width:2.6; stroke-linecap:round;
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
  background:#ffe066; opacity:.55; border-radius:4px; transform:skewX(-3deg); z-index:-1;
}}
body.recording .hlbar {{ animation:sweep .45s ease-out forwards; }}
@keyframes sweep {{ from {{ width:0 }} to {{ width:calc(100% + 12px) }} }}

/* Annotation de RAPPEL : posée sur une notion écrite plus haut. */
.recall {{ position:absolute; left:{pad_left}px; width:{content_w}px; pointer-events:none; }}

/* ── Bandeau fixe + masque ────────────────────────────────────────── */
#veil {{
  position:fixed; top:0; left:0; right:0; height:{top_safe}px;
  background:linear-gradient(#fffdf7 62%, rgba(255,253,247,0) 100%);
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
  font-size:26px; font-weight:800; color:#fff; background:#3b6fe0;
  padding:8px 22px; border-radius:30px;
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
  background:linear-gradient(90deg,#3b6fe0,#1aa179);
  transform:scaleX(0); transform-origin:left center;
}}
body.recording #prog i {{ animation:progGrow {total}s linear forwards; }}
@keyframes progGrow {{ to {{ transform:scaleX(1); }} }}

/* ── GÉNÉRIQUE D'OUVERTURE : carte-titre pleine page ──────────────────── */
#intro {{
  position:fixed; inset:0; z-index:30; display:flex; align-items:center;
  justify-content:center;
  background:radial-gradient(circle at 30% 20%, #f4f9ff 0%, #e8f1fb 55%, #dcebf6 100%);
}}
body.recording #intro {{ animation:introOut {intro_out}s cubic-bezier(.5,0,.75,.2) forwards; }}
@keyframes introOut {{
  0%   {{ opacity:1; transform:translateY(0); }}
  100% {{ opacity:0; transform:translateY(-120px); visibility:hidden; }}
}}
#intro-card {{
  width:880px; padding:90px 60px; text-align:center; border-radius:44px;
  background:linear-gradient(140deg,#3b6fe0 0%,#2d8fd6 55%,#1aa179 100%);
  box-shadow:0 40px 90px rgba(24,64,130,.35), inset 0 2px 0 rgba(255,255,255,.25);
  opacity:0; transform:scale(.7) translateY(90px);
}}
body.recording #intro-card {{ animation:introCard {intro_card_in}s cubic-bezier(.18,1.3,.35,1) forwards; }}
@keyframes introCard {{
  0%   {{ opacity:0; transform:scale(.7) translateY(90px); }}
  100% {{ opacity:1; transform:scale(1) translateY(0); }}
}}
#intro-kicker {{
  font-family:'Inter','Noto Sans',sans-serif; font-size:30px; font-weight:800;
  letter-spacing:.42em; text-transform:uppercase; color:rgba(255,255,255,.85);
  margin-bottom:34px;
}}
#intro-title {{
  font-family:'Inter','Noto Sans',sans-serif; font-size:88px; font-weight:900;
  line-height:1.14; color:#fff; text-shadow:0 6px 22px rgba(0,0,0,.25);
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
  width:220px; height:8px; margin:44px auto 0; border-radius:6px;
  background:rgba(255,255,255,.9); transform:scaleX(0);
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

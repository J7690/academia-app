"""
math_speech_sre — Verbalisation française des maths via Speech Rule Engine (SRE).

POURQUOI CE MODULE
------------------
`math_speech_fr` (regex maison) couvre les cas courants mais ne couvrira jamais
toutes les mathématiques. SRE est LE moteur de verbalisation utilisé par MathJax
et ChromeVox : localisé en français, règles ClearSpeak (lecture naturelle de
professeur), il sait dire fractions imbriquées, matrices, intégrales multiples...

CHAÎNE : LaTeX -> MathML (KaTeX, déjà présent pour l'affichage) -> parole (SRE),
exécutée par `latex_speech.js` (Node, déjà présent pour Playwright).

STRATÉGIE DE ROBUSTESSE
-----------------------
- Chaque appel Node traite un LOT d'expressions (un cours entier = 1 à 2 appels).
- Cache mémoire par expression : une formule répétée n'est verbalisée qu'une fois.
- Si Node ou SRE est indisponible, ou qu'UNE expression échoue, on retombe sur
  `math_speech_fr.verbalize` — jamais de silence, jamais de LaTeX lu à voix haute.

UTILISATION
-----------
    from math_speech_sre import verbalize_text, verbalize_formula
    verbalize_text("On pose $x^2 + 1 = 0$ et on résout.")   # prose + maths
    verbalize_formula(r"x = \\frac{-b \\pm \\sqrt{\\Delta}}{2a}")  # LaTeX pur
"""

from __future__ import annotations

import json
import logging
import re
import subprocess
from pathlib import Path
from typing import Dict, List, Optional

from math_speech_fr import verbalize as _verbalize_regex

logger = logging.getLogger("math_speech_sre")

__all__ = ["verbalize_text", "verbalize_formula", "is_available"]

# Le script Node : à côté du worker en production, dans le dépôt en développement.
_SCRIPT_PATHS = [
    Path("/opt/whiteboard-worker/vision_engine/latex_speech.js"),
    Path(__file__).with_name("whiteboard_vision") / "latex_speech.js",
]

# Segments mathématiques DÉLIMITÉS dans de la prose : $...$, \(...\), \[...\].
_MATH_SEG_RE = re.compile(r"\$([^$]+)\$|\\\((.+?)\\\)|\\\[(.+?)\\\]", re.S)

_TIMEOUT_SEC = 60
_cache: Dict[str, str] = {}
_broken = False  # passe à True au premier échec d'infrastructure : plus d'appels Node

# ─── Corrections françaises de la sortie SRE ──────────────────────────────
# La locale fr de SRE a des défauts entendus au banc d'essai du 27/07/2026 :
#   \Delta      -> « triangle en normal »   (un professeur dit « delta »)
#   \int        -> « le intégrale »          (élision manquante)
#   \sum        -> « le sommation »          (genre et usage : « la somme »)
#   \to         -> « flèche droite »         (« tend vers »)
#   0^+ / 0^-   -> « à la puissance plus »   (« par valeurs supérieures »)
#   \vec{F}     -> « F ⃗ »                   (caractère combinant illisible au TTS)
_FIXES = [
    (re.compile(r"\s+en normal\b"), ""),
    (re.compile(r"\btriangle\b"), "delta"),
    (re.compile(r"\ble sommation\b"), "la somme"),
    (re.compile(r"\bflèche droite\b"), "tend vers"),
    (re.compile(r"\blimite sur (\w+) tend vers\b"), r"la limite quand \1 tend vers"),
    (re.compile(r"\bà la puissance plus\b"), "par valeurs supérieures"),
    (re.compile(r"\bà la puissance moins\b"), "par valeurs inférieures"),
    (re.compile(r"(\S+)\s*\u20d7"), r"vecteur \1"),
    # Élision : « le intégrale » -> « l'intégrale », « de exposant » -> « d'exposant ».
    # Uniquement devant un VRAI mot (3 lettres et plus) : « de a à b » doit rester
    # « de a à b », jamais « d'a à b » — a est une variable, pas un mot.
    (re.compile(r"\b[Ll]e (?=[aeéèêiouâîôûh][a-zà-ÿ]{2,})"), "l'"),
    (re.compile(r"\b[Dd]e (?=[aeéèêiouâîôûh][a-zà-ÿ]{2,})"), "d'"),
    (re.compile(r"\s{2,}"), " "),
]


def _fix_fr(t: str) -> str:
    for rx, rep in _FIXES:
        t = rx.sub(rep, t)
    return t.strip()


def _script() -> Optional[Path]:
    for p in _SCRIPT_PATHS:
        if p.exists():
            return p
    return None


def is_available() -> bool:
    return not _broken and _script() is not None


def _sre_batch(exprs: List[str]) -> List[Optional[str]]:
    """
    Verbalise un lot d'expressions LaTeX. Retourne un élément par expression,
    `None` pour celles que SRE n'a pas su traiter (repli regex par l'appelant).
    """
    global _broken
    todo = [e for e in exprs if e not in _cache]
    if todo and not _broken:
        script = _script()
        if script is None:
            _broken = True
        else:
            try:
                out = subprocess.run(
                    ["node", str(script)],
                    input=json.dumps(todo),
                    capture_output=True, text=True,
                    timeout=_TIMEOUT_SEC, cwd=str(script.parent),
                )
                data = json.loads(out.stdout.strip() or "{}")
                if data.get("status") == "ok":
                    for e, s in zip(todo, data.get("speech") or []):
                        if isinstance(s, str) and s:
                            _cache[e] = _fix_fr(s)
                else:
                    logger.warning("[sre] echec moteur : %s", data.get("message"))
                    _broken = True
            except Exception as exc:  # noqa: BLE001
                logger.warning("[sre] indisponible (%s) — repli regex definitif", exc)
                _broken = True
    return [_cache.get(e) for e in exprs]


def verbalize_formula(latex: str) -> str:
    """LaTeX PUR (bloc formule) -> parole française. Repli : regex maison."""
    if not latex or not latex.strip():
        return ""
    expr = latex.strip().strip("$")
    got = _sre_batch([expr])[0]
    return got if got else _verbalize_regex(latex)


def verbalize_text(text: str) -> str:
    """
    Prose pouvant contenir des maths DÉLIMITÉES ($...$, \\(...\\), \\[...\\]).

    Les segments délimités passent par SRE ; le reste du texte (et tout LaTeX
    non délimité) passe par les regex maison, qui gèrent aussi la typographie
    française (« 0,6 » -> « zéro virgule six », etc.).
    """
    if not text or not text.strip():
        return ""

    segments: List[str] = []

    def _stash(m: re.Match) -> str:
        expr = next(g for g in m.groups() if g is not None)
        segments.append(expr.strip())
        return f"⟦{len(segments) - 1}⟧"

    stripped = _MATH_SEG_RE.sub(_stash, text)
    if not segments:
        return _verbalize_regex(text)

    speech = _sre_batch(segments)
    prose = _verbalize_regex(stripped)
    for i, (expr, s) in enumerate(zip(segments, speech)):
        prose = prose.replace(f"⟦{i}⟧", s if s else _verbalize_regex(expr))
    return re.sub(r"\s{2,}", " ", prose).strip()


if __name__ == "__main__":  # petit banc d'essai manuel
    logging.basicConfig(level=logging.INFO)
    exemples_formules = [
        r"x = \frac{-b \pm \sqrt{\Delta}}{2a}",
        r"\int_{a}^{b} f(x)\,dx",
        r"\sum_{i=1}^{n} i = \frac{n(n+1)}{2}",
        r"\lim_{x \to 0^+} \frac{\sin x}{x} = 1",
        r"E = mc^2",
        r"\vec{F} = m\vec{a}",
    ]
    for e in exemples_formules:
        print(f"{e}\n  -> {verbalize_formula(e)}\n")
    print(verbalize_text(
        "On pose $x^2 - 5x + 6 = 0$ puis on calcule $\\Delta = b^2 - 4ac$."
    ))

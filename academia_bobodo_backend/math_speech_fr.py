"""
math_speech_fr — Verbalisation française des mathématiques pour la synthèse vocale.

POURQUOI CE MODULE
------------------
Aucun moteur TTS du marché (OpenRouter, ElevenLabs, Kokoro, Google...) ne sait lire du
LaTeX. Envoyer « \\int_a^b f(x)\\,dx » à une voix produit du charabia. La solution
standard (cf. Speech Rule Engine, SSML `domain="Math"`) est de **traduire les maths en
langue parlée AVANT le TTS**. C'est exactement ce que fait ce module, pour le français.

Objectif de qualité : ce qu'un professeur dirait à voix haute au tableau.
  f(x)                     -> « f de x »
  \\int_{a}^{b} f(x) dx     -> « l'intégrale, de a à b, de f de x d x »
  \\lim_{x \\to 1^-} f(x)    -> « la limite, quand x tend vers 1 par valeurs inférieures,
                                de f de x »
  \\frac{a}{b}              -> « a sur b »
  x^2                      -> « x au carré »
  \\alpha, \\pi, \\theta      -> « alpha », « pi », « thêta »

UTILISATION
-----------
    from math_speech_fr import verbalize
    texte_parlable = verbalize(texte_contenant_du_latex)

Le module est **sans dépendance** (regex uniquement) pour pouvoir être copié tel quel
sur le VPS, à côté du worker comme du moteur Remotion.
"""

from __future__ import annotations

import re
from typing import Dict

__all__ = ["verbalize"]


# ─────────────────────────────────────────────────────────────────────────────
# 1. Symboles simples (lettres grecques, opérateurs, ensembles)
# ─────────────────────────────────────────────────────────────────────────────

_GREEK: Dict[str, str] = {
    r"\alpha": "alpha", r"\beta": "bêta", r"\gamma": "gamma", r"\delta": "delta",
    r"\epsilon": "epsilon", r"\varepsilon": "epsilon", r"\zeta": "zêta",
    r"\eta": "êta", r"\theta": "thêta", r"\vartheta": "thêta", r"\iota": "iota",
    r"\kappa": "kappa", r"\lambda": "lambda", r"\mu": "mu", r"\nu": "nu",
    r"\xi": "ksi", r"\pi": "pi", r"\rho": "rhô", r"\sigma": "sigma",
    r"\tau": "tau", r"\upsilon": "upsilon", r"\phi": "phi", r"\varphi": "phi",
    r"\chi": "khi", r"\psi": "psi", r"\omega": "oméga",
    r"\Gamma": "Gamma", r"\Delta": "Delta", r"\Theta": "Thêta",
    r"\Lambda": "Lambda", r"\Xi": "Ksi", r"\Pi": "Pi", r"\Sigma": "Sigma",
    r"\Phi": "Phi", r"\Psi": "Psi", r"\Omega": "Oméga",
}

_OPERATORS: Dict[str, str] = {
    # Comparaison
    r"\neq": " différent de ", r"\ne": " différent de ",
    r"\leq": " inférieur ou égal à ", r"\le": " inférieur ou égal à ",
    r"\geq": " supérieur ou égal à ", r"\ge": " supérieur ou égal à ",
    r"\approx": " environ égal à ", r"\simeq": " équivalent à ",
    r"\equiv": " équivaut à ", r"\propto": " proportionnel à ",
    # Arithmétique
    r"\times": " fois ", r"\cdot": " fois ", r"\div": " divisé par ",
    r"\pm": " plus ou moins ", r"\mp": " moins ou plus ",
    # Ensembles et logique
    r"\in": " appartient à ", r"\notin": " n'appartient pas à ",
    r"\subset": " est inclus dans ", r"\subseteq": " est inclus ou égal à ",
    r"\cup": " union ", r"\cap": " inter ", r"\emptyset": " l'ensemble vide ",
    r"\forall": " pour tout ", r"\exists": " il existe ",
    r"\Rightarrow": " donc ", r"\Leftrightarrow": " équivaut à ",
    r"\implies": " implique ", r"\iff": " si et seulement si ",
    # Ensembles usuels
    r"\mathbb{R}": " l'ensemble des réels ", r"\R": " l'ensemble des réels ",
    r"\mathbb{N}": " l'ensemble des entiers naturels ", r"\N": " l'ensemble des entiers naturels ",
    r"\mathbb{Z}": " l'ensemble des entiers relatifs ", r"\Z": " l'ensemble des entiers relatifs ",
    r"\mathbb{Q}": " l'ensemble des rationnels ", r"\Q": " l'ensemble des rationnels ",
    r"\mathbb{C}": " l'ensemble des complexes ", r"\C": " l'ensemble des complexes ",
    # Divers
    r"\infty": " l'infini ", r"\partial": " d rond ", r"\nabla": " nabla ",
    r"\ldots": " et cetera ", r"\dots": " et cetera ", r"\cdots": " et cetera ",
    r"\quad": " ", r"\qquad": " ", r"\,": " ", r"\;": " ", r"\!": "",
    r"\left": "", r"\right": "", r"\displaystyle": "",
    # Fonctions usuelles (le nom se dit tel quel, mais sans la barre oblique)
    r"\sin": " sinus ", r"\cos": " cosinus ", r"\tan": " tangente ",
    r"\ln": " logarithme népérien ", r"\log": " logarithme ", r"\exp": " exponentielle ",
}


# ─────────────────────────────────────────────────────────────────────────────
# 2. Outils : remplacement des accolades les plus internes, de façon répétée
# ─────────────────────────────────────────────────────────────────────────────

_INNER = r"\{([^{}]*)\}"   # une accolade SANS accolade imbriquée
_MAX_PASSES = 12           # garde-fou contre toute boucle infinie


def _repeat(pattern: str, repl, text: str) -> str:
    """Applique une substitution jusqu'à stabilisation (traite l'imbrication de l'intérieur)."""
    for _ in range(_MAX_PASSES):
        new = re.sub(pattern, repl, text)
        if new == text:
            return new
        text = new
    return text


def _side(marker: str) -> str:
    """1^- -> par valeurs inférieures ; 1^+ -> par valeurs supérieures."""
    return " par valeurs inférieures" if marker == "-" else " par valeurs supérieures"


# ─────────────────────────────────────────────────────────────────────────────
# 3. Constructions mathématiques (ordre important : du plus spécifique au plus général)
# ─────────────────────────────────────────────────────────────────────────────

def _constructs(t: str) -> str:
    # ── Limites ────────────────────────────────────────────────────────────
    # Un professeur dit « LA LIMITE DE f de x QUAND x tend vers a » : l'objet d'abord,
    # la condition ensuite. On capture donc l'opérande qui SUIT le \lim (jusqu'au signe
    # « = » ou la fin de l'expression) pour le replacer avant la condition.
    #   \lim_{x \to a} f(x) = f(a)
    #     -> « la limite de f de x quand x tend vers a égale f de a »
    def _lim_parts(inner: str):
        mm = re.match(r"\s*(.+?)\s*\\?to\s*(.+?)\s*$", inner.replace("\\to", "to"))
        if not mm:
            return None, None
        var, dest = mm.group(1).strip(), mm.group(2).strip()
        ms = re.match(r"^(.*?)\^\s*\{?([+-])\}?$", dest)
        if ms:
            dest = ms.group(1).strip() + _side(ms.group(2))
        return var, dest

    def _lim_with_operand(m: re.Match) -> str:
        var, dest = _lim_parts(m.group(1))
        operand = (m.group(2) or "").strip()
        if var is None:
            return f" la limite de {operand} "
        if not operand:
            return f" la limite, quand {var} tend vers {dest}, "
        return f" la limite de {operand} quand {var} tend vers {dest} "

    # Opérande = ce qui suit, jusqu'à un « = », un « ? », un « , » ou la fin.
    t = _repeat(
        r"\\lim\s*_\s*" + _INNER + r"\s*([^=?,;.]{0,40}?)(?=\s*(?:=|\?|,|;|\.|$))",
        _lim_with_operand,
        t,
    )
    # Repli : \lim_{...} sans opérande identifiable
    t = _repeat(r"\\lim\s*_\s*" + _INNER,
                lambda m: (lambda v, d: f" la limite, quand {v} tend vers {d}, "
                           if v else " la limite ")(*_lim_parts(m.group(1))), t)
    t = t.replace("\\lim", " la limite ")

    # ── Intégrales ─────────────────────────────────────────────────────────
    # \int_{a}^{b} ... dx   -> « l'intégrale, de a à b, de ... d x »
    t = _repeat(r"\\int\s*_\s*" + _INNER + r"\s*\^\s*" + _INNER,
                lambda m: f" l'intégrale, de {m.group(1)} à {m.group(2)}, de ", t)
    t = re.sub(r"\\int\s*_\s*([A-Za-z0-9])\s*\^\s*([A-Za-z0-9])",
               lambda m: f" l'intégrale, de {m.group(1)} à {m.group(2)}, de ", t)
    t = t.replace("\\iint", " l'intégrale double ").replace("\\int", " l'intégrale de ")
    # « dx » en fin d'intégrande se dit « d x »
    t = re.sub(r"(?<![A-Za-z])d\s*([xytuvz])(?![A-Za-z])", r" d \1", t)

    # ── Sommes et produits ─────────────────────────────────────────────────
    t = _repeat(r"\\sum\s*_\s*" + _INNER + r"\s*\^\s*" + _INNER,
                lambda m: f" la somme, pour {m.group(1)} allant à {m.group(2)}, de ", t)
    t = t.replace("\\sum", " la somme de ")
    t = _repeat(r"\\prod\s*_\s*" + _INNER + r"\s*\^\s*" + _INNER,
                lambda m: f" le produit, pour {m.group(1)} allant à {m.group(2)}, de ", t)
    t = t.replace("\\prod", " le produit de ")

    # ── Fractions et racines ───────────────────────────────────────────────
    t = _repeat(r"\\frac\s*" + _INNER + r"\s*" + _INNER,
                lambda m: f" {m.group(1)} sur {m.group(2)} ", t)
    t = _repeat(r"\\d?frac\s*(\d)\s*(\d)", lambda m: f" {m.group(1)} sur {m.group(2)} ", t)
    t = _repeat(r"\\sqrt\s*\[\s*([^\]]*)\s*\]\s*" + _INNER,
                lambda m: f" racine {m.group(1)}-ième de {m.group(2)} ", t)
    t = _repeat(r"\\sqrt\s*" + _INNER, lambda m: f" racine carrée de {m.group(1)} ", t)

    # ── Dérivées ───────────────────────────────────────────────────────────
    # On absorbe l'argument tout de suite : sinon « f'(x) » donnerait « f prime de (x) »
    # que l'étape suivante ne saurait plus nettoyer (« de » n'est pas une fonction).
    # Le lookbehind (?<!') évite de prendre une apostrophe de citation pour une dérivée :
    # dans « tend vers 'a' », le a est entre guillemets simples, ce n'est pas « a prime ».
    t = re.sub(r"(?<![A-Za-zÀ-ÿ'])([A-Za-z])''\s*\(\s*([^()]{1,25}?)\s*\)", r"\1 seconde de \2", t)
    t = re.sub(r"(?<![A-Za-zÀ-ÿ'])([A-Za-z])'\s*\(\s*([^()]{1,25}?)\s*\)", r"\1 prime de \2", t)
    t = re.sub(r"(?<![A-Za-zÀ-ÿ'])([A-Za-z])''(?![A-Za-z])", r"\1 seconde ", t)
    t = re.sub(r"(?<![A-Za-zÀ-ÿ'])([A-Za-z])'(?![A-Za-z'])", r"\1 prime ", t)

    # ── Vecteurs, valeur absolue ───────────────────────────────────────────
    t = _repeat(r"\\(?:vec|overrightarrow)\s*" + _INNER,
                lambda m: f" vecteur {m.group(1)} ", t)
    t = _repeat(r"\|\s*([^|]{1,30})\s*\|", lambda m: f" valeur absolue de {m.group(1)} ", t)

    return t


def _powers_and_indices(t: str) -> str:
    """Exposants et indices — après les constructions, avant le nettoyage."""
    t = re.sub(r"\^\s*\{\s*2\s*\}|\^\s*2(?![0-9])", " au carré ", t)
    t = re.sub(r"\^\s*\{\s*3\s*\}|\^\s*3(?![0-9])", " au cube ", t)
    t = re.sub(r"\^\s*\{\s*-\s*1\s*\}", " puissance moins un ", t)
    t = _repeat(r"\^\s*" + _INNER, lambda m: f" puissance {m.group(1)} ", t)
    t = re.sub(r"\^\s*([A-Za-z0-9]+)", r" puissance \1 ", t)
    t = _repeat(r"_\s*" + _INNER, lambda m: f" indice {m.group(1)} ", t)
    t = re.sub(r"_\s*([A-Za-z0-9]+)", r" indice \1 ", t)
    return t


# Noms admis comme FONCTIONS. Liste blanche volontaire : « n(n+1) » est un produit,
# pas une fonction, et « de (x) » ne doit évidemment pas devenir « de de x ».
_FUNCTION_NAMES = {
    "f", "g", "h", "u", "v", "w", "p", "q", "r", "s", "P", "Q", "F", "G", "H", "U", "V",
    "sin", "cos", "tan", "cot", "ln", "log", "exp", "abs", "det", "min", "max",
}


def _function_calls(t: str) -> str:
    """
    f(x) -> « f de x ». C'est LE cas le plus fréquent et le plus mal lu par les TTS.

    Seuls les noms de la liste blanche sont convertis, pour ne pas transformer un
    produit (« n(n+1) ») en application de fonction, ni abîmer le français normal
    (« continue (en x = 1) », « de (x) »).
    """
    def _repl(m: re.Match) -> str:
        name, arg = m.group(1), m.group(2)
        if name not in _FUNCTION_NAMES:
            return m.group(0)
        return f"{name} de {arg}"

    return re.sub(
        r"(?<![A-Za-zÀ-ÿ0-9])([A-Za-z]{1,3})\s*\(\s*([^()]{1,25}?)\s*\)",
        _repl,
        t,
    )


def _numbers_fr(t: str) -> str:
    """
    Nombres et énumérations à la française.

    Deux défauts entendus le 25/07 :
      - « 0.6 » lu « zéro point six » au lieu de « zéro virgule six ». En français, le
        séparateur décimal SE PRONONCE « virgule » — c'est une règle, pas une préférence.
      - les puces numérotées (« 1. », « 2. ») lues comme des nombres nus, sans annoncer
        qu'il s'agit d'une étape. Un professeur dit « étape un », « étape deux ».
    """
    # Décimales : 0.6 et 0,6 -> « zéro virgule six ». On épelle la partie décimale
    # chiffre par chiffre, comme le fait un professeur (« pi vaut 3 virgule 1 4 »).
    def _dec(m: re.Match) -> str:
        entier, frac = m.group(1), m.group(2)
        return f"{entier} virgule {' '.join(frac)}"

    t = re.sub(r"(?<![\w])(\d+)[.,](\d+)(?![\w])", _dec, t)

    # Énumérations en début de ligne : « 1. » -> « étape un, »
    ordinaux = {
        "1": "étape un", "2": "étape deux", "3": "étape trois", "4": "étape quatre",
        "5": "étape cinq", "6": "étape six", "7": "étape sept", "8": "étape huit",
        "9": "étape neuf", "10": "étape dix",
    }
    def _enum(m: re.Match) -> str:
        n = m.group(1)
        return f"{ordinaux.get(n, 'point ' + n)}, "

    t = re.sub(r"(?m)^\s*(\d{1,2})\s*[.)]\s+", _enum, t)
    # Puces : « - » ou « • » en début de ligne -> une simple respiration.
    t = re.sub(r"(?m)^\s*[-–—•*]\s+", "", t)
    return t


def _arithmetic(t: str) -> str:
    """
    Opérateurs écrits en symboles -> mots. Les TTS lisent « = » et « + » de façon
    aléatoire (parfois muets). On les verbalise, en restant prudent sur le tiret,
    qui sert aussi de puce de liste et de trait d'union en français.
    """
    t = re.sub(r"\s*=\s*", " égale ", t)
    t = re.sub(r"\s*\+\s*", " plus ", t)
    t = re.sub(r"\s*<\s*", " inférieur à ", t)
    t = re.sub(r"\s*>\s*", " supérieur à ", t)
    # Soustraction : uniquement « nombre/lettre - nombre/lettre », jamais en début de
    # ligne (puce) ni dans un mot composé (« au-dessus »).
    t = re.sub(r"(?<=[A-Za-z0-9\)])\s+-\s+(?=[A-Za-z0-9\(])", " moins ", t)
    # « 2x » -> « 2 x » (sinon la voix dit « deux-ix »)
    t = re.sub(r"(?<=\d)(?=[A-Za-z])", " ", t)
    return t


def _symbols(t: str) -> str:
    # Ordre décroissant de longueur ET frontière de mot : sinon « \in » mangeait le
    # début de « \infty » et produisait « plus appartient à fty ».
    for src, dst in sorted(_OPERATORS.items(), key=lambda kv: -len(kv[0])):
        t = re.sub(re.escape(src) + r"(?![A-Za-z])", dst, t)
    for src, dst in sorted(_GREEK.items(), key=lambda kv: -len(kv[0])):
        # \alpha ne doit pas manger \alphabet : on exige une fin de mot
        t = re.sub(re.escape(src) + r"(?![A-Za-z])", dst, t)
    t = t.replace("\\to", " tend vers ").replace("\\mapsto", " a pour image ")
    t = t.replace("\\rightarrow", " tend vers ").replace("\\leftarrow", " vient de ")
    return t


def _cleanup(t: str) -> str:
    """Retire ce qui resterait de syntaxe LaTeX et normalise les espaces."""
    t = re.sub(r"\\[a-zA-Z]+", " ", t)      # commande inconnue -> on l'efface
    t = t.replace("$", " ")
    t = re.sub(r"[{}\\^_]", " ", t)
    t = t.replace("&", " ").replace("~", " ")
    # Ponctuation : en français, pas d'espace avant « , » et « . », mais on conserve
    # une espace avant « ? ! ; : » (typographie française, et respiration pour la voix).
    t = re.sub(r"\s+([,.])", r"\1", t)
    t = re.sub(r"\s*([;:?!])", r" \1", t)
    t = re.sub(r"\s{2,}", " ", t)
    return t.strip()


# ─────────────────────────────────────────────────────────────────────────────
# 4. Point d'entrée
# ─────────────────────────────────────────────────────────────────────────────

def verbalize(text: str) -> str:
    """
    Transforme un texte pouvant contenir du LaTeX en texte prononçable en français.

    Sûr par construction : un texte sans mathématiques ressort inchangé (aux espaces
    près). En cas d'échec d'une règle, on dégrade en retirant la syntaxe LaTeX plutôt
    que de la faire lire à voix haute.
    """
    if not text or not text.strip():
        return ""
    t = text
    t = _constructs(t)
    t = _powers_and_indices(t)
    t = _symbols(t)
    t = _function_calls(t)
    t = _numbers_fr(t)
    t = _arithmetic(t)
    t = _cleanup(t)
    return t


if __name__ == "__main__":  # petit banc d'essai manuel
    exemples = [
        r"f(x) = x^2 + 1",
        r"\int_{a}^{b} f(x) dx",
        r"\lim_{x \to 1^-} (x + 1) = 2",
        r"\lim_{x \to 1} f(x) = f(1) ? Non ! 2 \neq 3",
        r"\frac{a+b}{2} \geq \sqrt{ab}",
        r"\sum_{i=1}^{n} i = \frac{n(n+1)}{2}",
        r"Soit \alpha \in \mathbb{R} et f'(x) = 2x",
        r"La fonction f n'est PAS continue en x = 1.",
    ]
    for e in exemples:
        print(f"{e}\n  -> {verbalize(e)}\n")

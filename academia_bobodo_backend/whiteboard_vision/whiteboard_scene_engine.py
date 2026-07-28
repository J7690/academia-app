"""
Whiteboard Scene Engine — Phase B.5
Orchestrateur principal du Vision Engine.

Pipeline pour chaque scène :
  1. Pré-rend les formules LaTeX via KaTeX (appel Node.js)
  2. Pré-génère les diagrammes Mermaid (appel Node.js)
  3. Construit le HTML final en injectant dans le template
  4. Capture les frames via Playwright
  5. Retourne les PNGs (ou segment vidéo) pour l'assembleur FFmpeg

Remplace whiteboard_png_renderer.py (Pillow) avec un feature flag.
"""

from __future__ import annotations

import html as html_module
import json
import logging
import re
import subprocess
import tempfile
from pathlib import Path
from typing import Any, Dict, List, Optional, Sequence

logger = logging.getLogger("whiteboard_scene_engine")

# Chemins sur le VPS Kamatera
VISION_DIR = Path("/opt/whiteboard-worker/vision_engine")
TEMPLATE_PATH = VISION_DIR / "scene_template.html"
KATEX_RENDERER = VISION_DIR / "katex_renderer.js"
DIAGRAM_RENDERER = VISION_DIR / "diagram_renderer.js"
NODE_MODULES = VISION_DIR / "node_modules"

# Fallback : chemins locaux (dev)
if not VISION_DIR.exists():
    VISION_DIR = Path(__file__).parent
    TEMPLATE_PATH = VISION_DIR / "scene_template.html"
    KATEX_RENDERER = VISION_DIR / "katex_renderer.js"
    DIAGRAM_RENDERER = VISION_DIR / "diagram_renderer.js"
    NODE_MODULES = VISION_DIR / "node_modules"


def _call_node(script: Path, arg: str, timeout: int = 15) -> str:
    """Appelle un script Node.js et retourne stdout."""
    try:
        result = subprocess.run(
            ["node", str(script), arg],
            capture_output=True,
            text=True,
            timeout=timeout,
            env={"NODE_PATH": str(NODE_MODULES), "PATH": "/usr/local/bin:/usr/bin:/bin"},
        )
        if result.returncode == 0:
            return result.stdout.strip()
        logger.warning(f"[node] {script.name} error: {result.stderr[:200]}")
        return ""
    except Exception as e:
        logger.warning(f"[node] {script.name} exception: {e}")
        return ""


def _render_katex(latex: str) -> str:
    """Rend une formule LaTeX en HTML via KaTeX."""
    if not latex or not latex.strip():
        return ""
    html_out = _call_node(KATEX_RENDERER, latex)
    if html_out:
        return html_out
    # Fallback : afficher le LaTeX brut dans un span
    return f'<span class="katex-fallback" style="font-family:monospace;font-size:40px;">{html_module.escape(latex)}</span>'


# ─── MATHS EN LIGNE (correctif 25/07/2026) ─────────────────────────────────────
# Constat : les blocs `correction` / `paragraph` / `definition` contiennent souvent du
# LaTeX au milieu d'une phrase (ex. "Limite à gauche : \lim_{x \to 1^-} (x+1) = 2").
# Jusqu'ici seuls les blocs `type=formula` passaient par KaTeX : tout le reste était
# échappé en texte, et l'étudiant voyait « \lim_{x \to 1^-} » à l'écran.
# On rend désormais les atomes LaTeX partout, sans toucher au texte français autour.

# 1) Segment explicitement délimité par des $...$ (forme préférée, à privilégier
#    côté générateur).
_MATH_DOLLAR = re.compile(r"\$([^$]{1,400})\$")

# 2) Commande LaTeX suivie de ses arguments immédiats : \lim_{x \to 1^-}, \neq,
#    \frac{a}{b}, \alpha... On s'arrête volontairement aux arguments collés à la
#    commande pour ne JAMAIS avaler le texte français qui suit.
_MATH_COMMAND = re.compile(
    r"\\[a-zA-Z]+"                                  # \lim, \neq, \frac...
    r"(?:\s*(?:\{[^{}]{0,200}\}|\^\{[^{}]{0,80}\}|_\{[^{}]{0,80}\}|\^[^\s{]|_[^\s{]))*"
)

# 3) Puissances écrites en clair hors commande : x^2, 1^2, n^{k+1}
_MATH_POWER = re.compile(r"(?<![\\A-Za-z0-9])([A-Za-z0-9])\^(\{[^{}]{1,40}\}|[A-Za-z0-9]+)")

# Cache : une même formule revient souvent dans une correction, et chaque rendu
# KaTeX coûte un lancement de process Node.
_katex_cache: Dict[str, str] = {}

# Une ligne de correction porte-t-elle déjà sa propre numérotation / puce ?
# Ex. « 3. Est-ce que... », « - Limite à gauche », « • ... », « a) ... », « 1) ... »
_ALREADY_NUMBERED = re.compile(r"^\s*(?:\d+\s*[\.\)]|[a-zA-Z]\s*\)|[-–—•*])\s+")


def _render_katex_inline(latex: str) -> str:
    """Rend un atome LaTeX en HTML inline (pas de displayMode), avec cache."""
    key = latex.strip()
    if not key:
        return ""
    if key in _katex_cache:
        return _katex_cache[key]
    html_out = _call_node(KATEX_RENDERER, key)
    if not html_out:
        # Repli lisible : on n'affiche pas la syntaxe LaTeX brute à l'étudiant.
        html_out = f'<span class="math-fallback">{html_module.escape(key)}</span>'
    else:
        # Le renderer est en displayMode (bloc) : on le repasse en ligne pour ne pas
        # casser la phrase qui l'entoure.
        html_out = html_out.replace('class="katex-display"', 'class="katex-inline"')
        html_out = f'<span class="math-inline">{html_out}</span>'
    _katex_cache[key] = html_out
    return html_out


def _escape_with_math(text: str) -> str:
    """
    Échappe le texte pour le HTML **tout en rendant les maths via KaTeX**.

    Le texte français est échappé normalement ; seuls les atomes mathématiques
    détectés sont remplacés par du HTML KaTeX. Ordre : $...$, puis commandes, puis
    puissances en clair.
    """
    if not text:
        return ""

    placeholders: Dict[str, str] = {}

    def _stash(latex: str) -> str:
        token = f"\x00MATH{len(placeholders)}\x00"
        placeholders[token] = _render_katex_inline(latex)
        return token

    working = text
    working = _MATH_DOLLAR.sub(lambda m: _stash(m.group(1)), working)
    working = _MATH_COMMAND.sub(lambda m: _stash(m.group(0)), working)
    working = _MATH_POWER.sub(lambda m: _stash(f"{m.group(1)}^{m.group(2)}"), working)

    escaped = html_module.escape(working)
    for token, html_frag in placeholders.items():
        escaped = escaped.replace(token, html_frag)
    return escaped


def _render_diagram(mermaid_def: str) -> str:
    """Rend un diagramme Mermaid en SVG."""
    if not mermaid_def or not mermaid_def.strip():
        return ""
    svg_out = _call_node(DIAGRAM_RENDERER, mermaid_def)
    return svg_out if svg_out else f'<pre>{html_module.escape(mermaid_def)}</pre>'


def _build_block_html(block: Dict[str, Any], block_index: int) -> str:
    """Construit le HTML d'un bloc individuel."""
    block_type = block.get("type", "paragraph")
    content = block.get("content", "") or ""
    # Correctif 25/07/2026 : on échappe ET on rend les maths en ligne (KaTeX), au lieu
    # d'échapper bêtement le LaTeX qui s'affichait alors en clair à l'écran.
    escaped = _escape_with_math(content)

    if block_type == "title":
        return f'<div class="block block-title">{escaped}</div>'

    elif block_type == "paragraph":
        # Convertir les retours à la ligne
        formatted = escaped.replace("\n", "<br>")
        return f'<div class="block block-paragraph">{formatted}</div>'

    elif block_type == "formula":
        katex_html = _render_katex(content)
        return f'<div class="block block-formula">{katex_html}</div>'

    elif block_type == "definition":
        formatted = escaped.replace("\n", "<br>")
        return (
            f'<div class="block block-definition">'
            f'<div class="def-label">Définition</div>'
            f'<div class="def-content">{formatted}</div>'
            f'</div>'
        )

    elif block_type == "exercise":
        formatted = escaped.replace("\n", "<br>")
        return (
            f'<div class="block block-exercise">'
            f'<div class="exo-label">Exercice</div>'
            f'<div class="exo-content">{formatted}</div>'
            f'</div>'
        )

    elif block_type == "correction":
        # Découper en étapes (par ligne)
        lines = content.split("\n")
        steps_html = ""
        # Correctif 25/07/2026 (numérotation en double) : on préfixait systématiquement
        # un compteur `{i}. ` calculé SUR LES LIGNES DU BLOC. Or chaque bloc ne contient
        # qu'une ligne -> i valait toujours 1, et le contenu de l'IA porte déjà sa propre
        # numérotation. Résultat à l'écran : « 11. f(1) existe », « 1Conclusion : ... ».
        # On ne numérote donc que si le bloc a plusieurs étapes ET que la ligne ne porte
        # pas déjà un marqueur (« 3. », « - », « • », « a) »...).
        real_lines = [ln for ln in (l.strip() for l in lines) if ln]
        multi_step = len(real_lines) > 1
        for i, line in enumerate(real_lines, 1):
            already_marked = bool(_ALREADY_NUMBERED.match(line))
            step_attr = f' data-step="{i}. "' if (multi_step and not already_marked) else ""
            steps_html += f'<div class="corr-step"{step_attr}>{_escape_with_math(line)}</div>'
        return (
            f'<div class="block block-correction">'
            f'<div class="corr-label">Correction</div>'
            f'<div class="corr-content">{steps_html}</div>'
            f'</div>'
        )

    elif block_type == "diagram":
        svg_html = _render_diagram(content)
        return f'<div class="block block-diagram">{svg_html}</div>'

    elif block_type == "graph":
        # Graph de fonction — pour l'instant, affichage comme formule + placeholder
        katex_html = _render_katex(content)
        return (
            f'<div class="block block-graph">'
            f'{katex_html}'
            f'</div>'
        )

    else:
        # Type inconnu → paragraphe
        formatted = escaped.replace("\n", "<br>")
        return f'<div class="block block-paragraph">{formatted}</div>'


def build_scene_html(
    scene: Dict[str, Any],
    scene_index: int,
    theme: str = "scientific",
    subject: str = "",
    total_scenes: int = 1,
) -> str:
    """
    Construit le HTML complet d'une scène en injectant les blocs
    dans le template HTML.
    """
    # Lire le template
    template = TEMPLATE_PATH.read_text(encoding="utf-8")

    # Construire le HTML des blocs
    blocks = scene.get("blocks", [])
    blocks_html_parts = []
    for i, block in enumerate(blocks):
        if not isinstance(block, dict):
            continue
        if not block.get("visible", True):
            continue
        blocks_html_parts.append(_build_block_html(block, i))

    blocks_html = "\n    ".join(blocks_html_parts)

    # Injecter dans le template
    html_out = template.replace("{{THEME}}", theme)
    html_out = html_out.replace("{{SUBJECT}}", html_module.escape(subject))
    html_out = html_out.replace("{{BLOCKS_HTML}}", blocks_html)
    html_out = html_out.replace("{{SCENE_NUMBER}}", f"{scene_index + 1}/{total_scenes}")

    return html_out


def render_scene_to_png(
    scene: Dict[str, Any],
    scene_index: int,
    output_dir: Path,
    theme: str = "scientific",
    subject: str = "",
    total_scenes: int = 1,
    duration_s: float = 5.0,
) -> Path:
    """
    Rend une scène complète en PNG via le Vision Engine :
    1. Construit le HTML
    2. Capture le frame final via Playwright (Node.js subprocess)

    Returns:
        Path du PNG de la scène
    """
    try:
        from whiteboard_vision.whiteboard_playwright_capture import capture_final_frame
    except ImportError:
        from whiteboard_playwright_capture import capture_final_frame

    # Construire le HTML
    scene_html = build_scene_html(scene, scene_index, theme, subject, total_scenes)

    # Écrire le HTML temporaire
    html_path = output_dir / f"scene_{scene_index + 1:03d}.html"
    html_path.write_text(scene_html, encoding="utf-8")

    # Capturer le frame final (après animations)
    png_path = output_dir / f"scene_{scene_index + 1:03d}.png"
    wait_ms = min(int(duration_s * 800), 5000)  # 80% de la durée, max 5s
    capture_final_frame(html_path, png_path, wait_ms=wait_ms)

    return png_path


def render_scene_to_frames(
    scene: Dict[str, Any],
    scene_index: int,
    output_dir: Path,
    theme: str = "scientific",
    subject: str = "",
    total_scenes: int = 1,
    duration_s: float = 5.0,
    fps: int = 30,
) -> List[Path]:
    """
    Rend une scène en séquence de frames PNG (pour les animations).
    Note: Phase E implémentera la capture frame-par-frame.
    Pour l'instant, capture un seul frame final par scène.
    """
    # Pour l'instant, un seul frame par scène (Phase E ajoutera le multi-frame)
    png = render_scene_to_png(
        scene, scene_index, output_dir, theme, subject, total_scenes, duration_s
    )
    return [png]


def render_storyboard_to_pngs_vision(
    storyboard_json: Any,
    output_dir: Path,
) -> List[Path]:
    """
    Point d'entrée principal — Remplace render_storyboard_to_pngs() de Pillow.
    Génère un PNG par scène via le Vision Engine HTML/Playwright/KaTeX.

    Compatible avec le worker existant (même signature de retour).
    Entièrement synchrone (Node.js subprocess).
    """
    if isinstance(storyboard_json, str):
        storyboard = json.loads(storyboard_json)
    else:
        storyboard = storyboard_json

    theme = storyboard.get("theme", "scientific")
    subject = storyboard.get("subject", "")
    scenes = storyboard.get("scenes", [])

    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    png_paths: List[Path] = []

    for scene_index, scene in enumerate(scenes):
        if not isinstance(scene, dict):
            continue

        duration_ms = scene.get("duration_ms", 5000)
        try:
            duration_s = max(1.0, float(duration_ms) / 1000.0)
        except (TypeError, ValueError):
            duration_s = 5.0

        png_path = render_scene_to_png(
            scene=scene,
            scene_index=scene_index,
            output_dir=output_dir,
            theme=theme,
            subject=subject,
            total_scenes=len(scenes),
            duration_s=duration_s,
        )
        png_paths.append(png_path)

    logger.info(f"[vision_engine] Rendered {len(png_paths)} scenes -> {output_dir}")
    return png_paths


if __name__ == "__main__":
    import sys

    if len(sys.argv) < 3:
        print("Usage: python whiteboard_scene_engine.py <storyboard.json> <output_dir>")
        sys.exit(1)

    storyboard_file = Path(sys.argv[1])
    out_dir = Path(sys.argv[2])

    with open(storyboard_file, "r", encoding="utf-8") as f:
        storyboard = json.load(f)

    pngs = render_storyboard_to_pngs_vision(storyboard, out_dir)
    print(f"Generated {len(pngs)} PNGs:")
    for p in pngs:
        print(f"  {p}")

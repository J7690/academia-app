"""
Whiteboard PNG Renderer - v2 (V1 QUALITE)

Corrections vs v1 :
  - Police : ne depend plus de "arial.ttf" (absent du VPS Linux -> fallback
    bitmap minuscule). Charge DejaVuSans / DejaVuSans-Bold par chemins connus.
  - Retour a la ligne (word wrap) : le texte ne deborde plus de l'ecran.
  - Formules : rendu mathematique reel via matplotlib (mathtext) avec repli
    texte si matplotlib absent. Pour activer : `pip install matplotlib` sur le VPS.
  - Marges, interlignage et gestion du debordement vertical.

Les PNG sont generes en 1080x1920 ; l'assembleur ffmpeg downscale ensuite
vers la resolution de sortie (voir whiteboard_ffmpeg_assembler.py).
"""

from pathlib import Path
from typing import Any, Dict, List
import json

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    print("Pillow not installed. Install with: pip install Pillow")
    raise

# --- Rendu math optionnel (matplotlib) -------------------------------------
try:
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    _HAS_MPL = True
except Exception:
    _HAS_MPL = False

# Configuration
WIDTH = 1080
HEIGHT = 1920
MARGIN_X = 70
MARGIN_TOP = 120
MARGIN_BOTTOM = 90
LINE_SPACING = 1.35  # multiplicateur d'interligne

# Chemins de polices candidats (Linux d'abord, puis fallback)
_FONT_REGULAR_CANDIDATES = [
    "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
    "DejaVuSans.ttf",
    "arial.ttf",
]
_FONT_BOLD_CANDIDATES = [
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
    "DejaVuSans-Bold.ttf",
    "arialbd.ttf",
]

# Themes
THEMES = {
    "scientific": {
        "background": "#0a192f",
        "text_color": "#ffffff",
        "accent_color": "#69f0ae",
        "muted_color": "#9fb3c8",
        "title_font_size": 60,
        "paragraph_font_size": 42,
        "definition_font_size": 40,
        "exercise_font_size": 42,
        "correction_font_size": 40,
    },
    "notebook": {
        "background": "#ffffff",
        "text_color": "#1a1a1a",
        "accent_color": "#2e7d32",
        "muted_color": "#555555",
        "title_font_size": 60,
        "paragraph_font_size": 42,
        "definition_font_size": 40,
        "exercise_font_size": 42,
        "correction_font_size": 40,
    },
}


def _load_font(paths: List[str], size: int) -> Any:
    for path in paths:
        try:
            return ImageFont.truetype(path, size)
        except Exception:
            continue
    # Dernier recours : bitmap (petit, mais evite un crash)
    return ImageFont.load_default()


def _get_font(size: int, bold: bool = False) -> Any:
    return _load_font(_FONT_BOLD_CANDIDATES if bold else _FONT_REGULAR_CANDIDATES, size)


def _text_width(draw: Any, text: str, font: Any) -> int:
    bbox = draw.textbbox((0, 0), text, font=font)
    return bbox[2] - bbox[0]


def _line_height(size: int) -> int:
    return int(size * LINE_SPACING)


def _wrap_lines(draw: Any, text: str, font: Any, max_width: int) -> List[str]:
    """Decoupe un texte en lignes qui tiennent dans max_width (par mots)."""
    lines: List[str] = []
    for raw_line in (text or "").split("\n"):
        words = raw_line.split(" ")
        current = ""
        for word in words:
            candidate = word if not current else f"{current} {word}"
            if _text_width(draw, candidate, font) <= max_width or not current:
                current = candidate
            else:
                lines.append(current)
                current = word
        lines.append(current)
    return lines


def _draw_wrapped(
    draw: Any, text: str, font: Any, size: int, color: str,
    x: int, y: int, max_width: int, center: bool = False,
) -> int:
    """Dessine un texte multi-lignes et renvoie la nouvelle position y."""
    for line in _wrap_lines(draw, text, font, max_width):
        lx = x
        if center:
            lx = x + (max_width - _text_width(draw, line, font)) // 2
        draw.text((lx, y), line, fill=color, font=font)
        y += _line_height(size)
    return y


def _render_formula_block(
    img: Any, draw: Any, content: str, theme: Dict[str, Any], y: int,
) -> int:
    """Rend une formule. matplotlib mathtext si dispo, sinon texte centre."""
    max_width = WIDTH - 2 * MARGIN_X
    if _HAS_MPL and content.strip():
        try:
            import io
            fig = plt.figure(figsize=(8, 2), dpi=200)
            fig.patch.set_alpha(0.0)
            expr = content.strip()
            if not (expr.startswith("$") and expr.endswith("$")):
                expr = f"${expr}$"
            fig.text(0.5, 0.5, expr, fontsize=28, ha="center", va="center",
                     color=theme["text_color"])
            buf = io.BytesIO()
            fig.savefig(buf, format="png", transparent=True, bbox_inches="tight",
                        pad_inches=0.1)
            plt.close(fig)
            buf.seek(0)
            formula_img = Image.open(buf).convert("RGBA")
            if formula_img.width > max_width:
                ratio = max_width / formula_img.width
                formula_img = formula_img.resize(
                    (max_width, int(formula_img.height * ratio)), Image.LANCZOS)
            px = (WIDTH - formula_img.width) // 2
            img.paste(formula_img, (px, y), formula_img)
            return y + formula_img.height + 24
        except Exception:
            pass  # repli texte ci-dessous
    font = _get_font(46, bold=True)
    return _draw_wrapped(draw, content, font, 46, theme["text_color"],
                         MARGIN_X, y, max_width, center=True) + 12


def _render_block(img: Any, draw: Any, block: Dict[str, Any],
                  theme: Dict[str, Any], y: int) -> int:
    block_type = block.get("type")
    content = block.get("content", "") or ""
    max_width = WIDTH - 2 * MARGIN_X

    if block_type == "title":
        font = _get_font(theme["title_font_size"], bold=True)
        y = _draw_wrapped(draw, content, font, theme["title_font_size"],
                          theme["text_color"], MARGIN_X, y, max_width, center=True)
        return y + 30

    if block_type == "formula":
        return _render_formula_block(img, draw, content, theme, y)

    if block_type == "correction":
        font = _get_font(theme["correction_font_size"])
        y = _draw_wrapped(draw, content, font, theme["correction_font_size"],
                          theme["accent_color"], MARGIN_X, y, max_width)
        return y + 20

    if block_type == "definition":
        font = _get_font(theme["definition_font_size"])
        y = _draw_wrapped(draw, content, font, theme["definition_font_size"],
                          theme["accent_color"], MARGIN_X, y, max_width)
        return y + 20

    # paragraph, exercise, et types inconnus
    size = theme.get(f"{block_type}_font_size", theme["paragraph_font_size"])
    font = _get_font(size)
    y = _draw_wrapped(draw, content, font, size, theme["text_color"],
                      MARGIN_X, y, max_width)
    return y + 20


def render_storyboard_to_pngs(storyboard_json: Any, output_dir: Path) -> List[Path]:
    """Genere un PNG par scene a partir d'un storyboard."""
    if isinstance(storyboard_json, str):
        storyboard = json.loads(storyboard_json)
    else:
        storyboard = storyboard_json

    theme_name = storyboard.get("theme", "scientific")
    theme = THEMES.get(theme_name, THEMES["scientific"])
    scenes = storyboard.get("scenes", [])

    png_paths: List[Path] = []

    for scene_index, scene in enumerate(scenes):
        img = Image.new("RGB", (WIDTH, HEIGHT), theme["background"])
        draw = ImageDraw.Draw(img)

        y = MARGIN_TOP
        for block in scene.get("blocks", []):
            if y > HEIGHT - MARGIN_BOTTOM:
                break  # evite de dessiner hors ecran
            y = _render_block(img, draw, block, theme, y)

        png_path = output_dir / f"scene_{scene_index + 1:03d}.png"
        img.save(png_path, "PNG")
        png_paths.append(png_path)

    return png_paths

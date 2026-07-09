"""
Whiteboard PNG Renderer - Phase C.3
Génération de PNGs à partir d'un storyboard
"""

from pathlib import Path
from typing import Any, Dict, List
import json

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    print("Pillow not installed. Install with: pip install Pillow")
    raise

# Configuration
WIDTH = 1080
HEIGHT = 1920
DPI = 72

# Thèmes
THEMES = {
    "scientific": {
        "background": "#0a192f",
        "text_color": "#ffffff",
        "accent_color": "#69f0ae",
        "title_font_size": 32,
        "paragraph_font_size": 24,
        "definition_font_size": 20,
        "exercise_font_size": 24,
        "correction_font_size": 20,
    },
    "notebook": {
        "background": "#ffffff",
        "text_color": "#000000",
        "accent_color": "#2e7d32",
        "title_font_size": 32,
        "paragraph_font_size": 24,
        "definition_font_size": 20,
        "exercise_font_size": 24,
        "correction_font_size": 20,
    },
}


def _get_font(size: int) -> Any:
    """Récupère une police avec la taille spécifiée"""
    try:
        # Essayer d'utiliser Arial
        return ImageFont.truetype("arial.ttf", size)
    except:
        # Fallback sur la police par défaut
        return ImageFont.load_default()


def _render_title_block(content: str, theme: Dict[str, Any], draw: Any, y_position: int) -> int:
    """Rend un bloc de titre"""
    font = _get_font(theme["title_font_size"])
    text_color = theme["text_color"]
    
    # Dessiner le titre centré
    bbox = draw.textbbox((0, 0), content, font=font)
    text_width = bbox[2] - bbox[0]
    x_position = (WIDTH - text_width) // 2
    
    draw.text((x_position, y_position), content, fill=text_color, font=font)
    
    return y_position + theme["title_font_size"] + 20


def _render_paragraph_block(content: str, theme: Dict[str, Any], draw: Any, y_position: int) -> int:
    """Rend un bloc de paragraphe"""
    font = _get_font(theme["paragraph_font_size"])
    text_color = theme["text_color"]
    
    # Dessiner le paragraphe justifié (simplifié)
    margin = 50
    max_width = WIDTH - 2 * margin
    
    # Pour V1, on dessine simplement le texte sans wrapping complexe
    draw.text((margin, y_position), content, fill=text_color, font=font)
    
    return y_position + theme["paragraph_font_size"] * 2 + 20


def _render_definition_block(content: str, theme: Dict[str, Any], draw: Any, y_position: int) -> int:
    """Rend un bloc de définition"""
    font = _get_font(theme["definition_font_size"])
    text_color = theme["text_color"]
    
    margin = 50
    draw.text((margin, y_position), content, fill=text_color, font=font)
    
    return y_position + theme["definition_font_size"] * 2 + 20


def _render_exercise_block(content: str, theme: Dict[str, Any], draw: Any, y_position: int) -> int:
    """Rend un bloc d'exercice"""
    font = _get_font(theme["exercise_font_size"])
    text_color = theme["text_color"]
    
    margin = 50
    draw.text((margin, y_position), content, fill=text_color, font=font)
    
    return y_position + theme["exercise_font_size"] * 2 + 20


def _render_correction_block(content: str, theme: Dict[str, Any], draw: Any, y_position: int) -> int:
    """Rend un bloc de correction"""
    font = _get_font(theme["correction_font_size"])
    text_color = theme["accent_color"]  # Vert
    
    margin = 50
    draw.text((margin, y_position), content, fill=text_color, font=font)
    
    return y_position + theme["correction_font_size"] * 2 + 20


def _render_formula_block(content: str, theme: Dict[str, Any], draw: Any, y_position: int) -> int:
    """Rend un bloc de formule"""
    # Pour V1, on utilise le rendu texte brut comme fallback
    # Matplotlib sera implémenté dans une version ultérieure
    font = _get_font(28)
    text_color = theme["text_color"]
    
    # Centrer la formule
    bbox = draw.textbbox((0, 0), content, font=font)
    text_width = bbox[2] - bbox[0]
    x_position = (WIDTH - text_width) // 2
    
    draw.text((x_position, y_position), content, fill=text_color, font=font)
    
    return y_position + 28 + 20


def _render_block(block: Dict[str, Any], theme: Dict[str, Any], draw: Any, y_position: int) -> int:
    """Rend un bloc selon son type"""
    block_type = block.get("type")
    content = block.get("content", "")
    
    if block_type == "title":
        return _render_title_block(content, theme, draw, y_position)
    elif block_type == "paragraph":
        return _render_paragraph_block(content, theme, draw, y_position)
    elif block_type == "definition":
        return _render_definition_block(content, theme, draw, y_position)
    elif block_type == "exercise":
        return _render_exercise_block(content, theme, draw, y_position)
    elif block_type == "correction":
        return _render_correction_block(content, theme, draw, y_position)
    elif block_type == "formula":
        return _render_formula_block(content, theme, draw, y_position)
    else:
        # Type inconnu, rendu par défaut
        return _render_paragraph_block(content, theme, draw, y_position)


def render_storyboard_to_pngs(storyboard_json: Any, output_dir: Path) -> List[Path]:
    """
    Génère des PNGs à partir d'un storyboard
    
    Args:
        storyboard_json: Storyboard (dict ou JSON string)
        output_dir: Répertoire de sortie
        
    Returns:
        Liste des chemins des PNGs générés
    """
    # Parser le storyboard si c'est une string
    if isinstance(storyboard_json, str):
        storyboard = json.loads(storyboard_json)
    else:
        storyboard = storyboard_json
    
    # Récupérer le thème
    theme_name = storyboard.get("theme", "scientific")
    theme = THEMES.get(theme_name, THEMES["scientific"])
    
    # Récupérer les scènes
    scenes = storyboard.get("scenes", [])
    
    png_paths = []
    
    for scene_index, scene in enumerate(scenes):
        # Créer une nouvelle image
        img = Image.new("RGB", (WIDTH, HEIGHT), theme["background"])
        draw = ImageDraw.Draw(img)
        
        # Rendre les blocs
        y_position = 100  # Marge supérieure
        blocks = scene.get("blocks", [])
        
        for block in blocks:
            y_position = _render_block(block, theme, draw, y_position)
        
        # Sauvegarder l'image
        png_path = output_dir / f"scene_{scene_index + 1:03d}.png"
        img.save(png_path, "PNG", dpi=(DPI, DPI))
        png_paths.append(png_path)
    
    return png_paths

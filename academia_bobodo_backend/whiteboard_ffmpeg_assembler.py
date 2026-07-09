"""
Whiteboard FFmpeg Assembler - Phase C.3
Assemblage de PNGs en MP4
"""

from pathlib import Path
from typing import List
import subprocess


def assemble_pngs_to_mp4(png_paths: List[Path], output_dir: Path) -> Path:
    """
    Assemble des PNGs en MP4
    
    Args:
        png_paths: Liste des chemins des PNGs (ordonnés)
        output_dir: Répertoire de sortie
        
    Returns:
        Chemin du MP4 généré
    """
    if not png_paths:
        raise ValueError("No PNGs provided")
    
    # Vérifier que les PNGs existent
    for png_path in png_paths:
        if not png_path.exists():
            raise FileNotFoundError(f"PNG not found: {png_path}")
    
    # Chemin de sortie
    mp4_path = output_dir / "output.mp4"
    
    # Construire la commande FFmpeg
    # Les PNGs doivent être nommés scene_001.png, scene_002.png, etc.
    # On utilise le pattern scene_%03d.png
    first_png = png_paths[0]
    pattern = first_png.parent / "scene_%03d.png"
    
    cmd = [
        "ffmpeg",
        "-y",  # Écraser si existe
        "-f", "image2",  # Format image
        "-framerate", "30",  # 30 fps
        "-i", str(pattern),  # Pattern d'entrée
        "-c:v", "libx264",  # Codec vidéo
        "-pix_fmt", "yuv420p",  # Format pixel
        "-r", "30",  # Framerate de sortie
        "-preset", "medium",  # Preset d'encodage
        "-crf", "23",  # Quality (lower = better, 18-28 range)
        str(mp4_path),
    ]
    
    # Exécuter la commande
    result = subprocess.run(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    
    if result.returncode != 0:
        stderr_text = result.stderr.decode("utf-8", errors="ignore")
        raise RuntimeError(f"FFmpeg error (code {result.returncode}): {stderr_text[:4000]}")
    
    # Vérifier que le MP4 a été créé
    if not mp4_path.exists():
        raise RuntimeError(f"MP4 not created: {mp4_path}")
    
    return mp4_path

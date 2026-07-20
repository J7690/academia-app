"""
Whiteboard Playwright Capture — Phase B.2 (v2 - Node.js subprocess)
Capture de frames PNG depuis un HTML de scene via Playwright Chromium headless.

Utilise le script Node.js capture_scene.js (Playwright npm installe sur Kamatera)
au lieu des bindings Python (incompatibles avec PEP 668 / Ubuntu 24.04).
"""

from __future__ import annotations

import json
import logging
import subprocess
from pathlib import Path
from typing import List, Optional

logger = logging.getLogger("whiteboard_playwright_capture")

# Chemin du script Node.js de capture
VISION_DIR = Path("/opt/whiteboard-worker/vision_engine")
CAPTURE_SCRIPT = VISION_DIR / "capture_scene.js"

# Fallback local (dev)
if not CAPTURE_SCRIPT.exists():
    CAPTURE_SCRIPT = Path(__file__).parent / "capture_scene.js"

# Résolution cible
VIEWPORT_W = 1080
VIEWPORT_H = 1920


def capture_final_frame(
    html_path: Path,
    output_png: Path,
    wait_ms: int = 3000,
) -> Path:
    """
    Ouvre le HTML via Node.js Playwright, attend les animations CSS,
    puis capture un screenshot 1080x1920.

    Args:
        html_path: chemin vers le fichier HTML de la scene
        output_png: chemin de sortie du PNG
        wait_ms: temps d'attente en ms pour les animations
    Returns:
        Path du PNG genere
    """
    html_path = Path(html_path)
    output_png = Path(output_png)

    if not html_path.exists():
        raise FileNotFoundError(f"HTML not found: {html_path}")

    try:
        result = subprocess.run(
            [
                "node", str(CAPTURE_SCRIPT),
                str(html_path.resolve()),
                str(output_png.resolve()),
                str(wait_ms),
            ],
            capture_output=True,
            text=True,
            timeout=60,
            cwd=str(VISION_DIR),
        )

        if result.returncode != 0:
            logger.error(f"[capture] Node.js error: {result.stderr[:500]}")
            raise RuntimeError(f"capture_scene.js failed: {result.stderr[:200]}")

        # Parse JSON output
        try:
            info = json.loads(result.stdout.strip())
            logger.info(f"[capture] Final frame -> {output_png} ({info.get('size', '?')} bytes)")
        except json.JSONDecodeError:
            logger.info(f"[capture] Final frame -> {output_png}")

        if not output_png.exists():
            raise FileNotFoundError(f"PNG not produced: {output_png}")

        return output_png

    except subprocess.TimeoutExpired:
        raise RuntimeError("capture_scene.js timed out (60s)")


def capture_multiple_scenes(
    html_paths: List[Path],
    output_pngs: List[Path],
    wait_ms: int = 3000,
) -> List[Path]:
    """Capture plusieurs scenes sequentiellement."""
    results = []
    for html_path, png_path in zip(html_paths, output_pngs):
        results.append(capture_final_frame(html_path, png_path, wait_ms))
    return results


# Async wrapper pour compatibilite avec le code existant
async def capture_final_frame_async(
    html_path: Path,
    output_png: Path,
    wait_ms: int = 3000,
) -> Path:
    """Wrapper async (appelle la version sync dans un thread)."""
    import asyncio
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(
        None, capture_final_frame, html_path, output_png, wait_ms
    )


if __name__ == "__main__":
    import sys

    if len(sys.argv) < 3:
        print("Usage: python whiteboard_playwright_capture.py <html_file> <output_png>")
        sys.exit(1)

    html_file = Path(sys.argv[1])
    out_file = Path(sys.argv[2])

    result = capture_final_frame(html_file, out_file)
    print(f"Captured -> {result}")

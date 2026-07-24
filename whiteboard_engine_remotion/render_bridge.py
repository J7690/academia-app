#!/usr/bin/env python3
"""
Pont worker -> moteur Remotion (studio anime). ZERO credit IA par video.

Appele par le worker whiteboard UNIQUEMENT si le storyboard demande le moteur anime :
    storyboard_json.get("engine") == "remotion"

Etapes :
  1. Resolution des assets : blocs `image` (requete -> Pexels, gratuit) ; formules
     -> clip anime Manim (optionnel, Vague 3).
  2. Narration TTS (narrate.py -> Kokoro).
  3. Rendu Remotion + finalisation ffmpeg (main/4.0, 720x1280) -> MP4.

Integration worker (opt-in, ne casse pas le diaporama v9) :
    engine = (storyboard_json or {}).get("engine")
    if engine == "remotion":
        mp4 = render_storyboard_remotion(storyboard_json, temp_path)
    else:
        # ... chemin diaporama v9 inchange

Config (env) :
    REMOTION_ENGINE_DIR   (defaut = dossier de ce fichier)
    PEXELS_API_KEY        (optionnel : sans lui, les blocs image sont ignores)
    MANIM_ENABLED=1       (optionnel : active les formules animees Manim)
    KOKORO_URL / KOKORO_VOICE ... (voir narrate.py)
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
from pathlib import Path
from typing import Any
from urllib import request, error, parse

ENGINE_DIR = Path(os.environ.get("REMOTION_ENGINE_DIR", str(Path(__file__).resolve().parent)))
RENDER_TIMEOUT = int(os.environ.get("REMOTION_RENDER_TIMEOUT", "900"))
PEXELS_API_KEY = os.environ.get("PEXELS_API_KEY", "")
MANIM_ENABLED = os.environ.get("MANIM_ENABLED", "") in {"1", "true", "yes"}


def _run(cmd: list[str], cwd: Path, extra_env: dict | None = None) -> None:
    env = None
    if extra_env:
        env = {**os.environ, **extra_env}
    r = subprocess.run(cmd, cwd=str(cwd), stdout=subprocess.PIPE,
                       stderr=subprocess.PIPE, timeout=RENDER_TIMEOUT, check=False, env=env)
    if r.returncode != 0:
        raise RuntimeError(
            f"[remotion] echec {' '.join(cmd[:2])} ({r.returncode}): "
            f"{r.stderr.decode(errors='ignore')[-1500:]}"
        )


# Limite mémoire Node relevée (le rendu SSR + fonts peut dépasser ~2 Go par défaut).
NODE_ENV = {"NODE_OPTIONS": os.environ.get("NODE_OPTIONS", "--max-old-space-size=6144")}


def _pexels_download(query: str, dest: Path) -> bool:
    """Recupere une image libre (Pexels) pour la requete. False si indisponible."""
    if not PEXELS_API_KEY or not query.strip():
        return False
    url = "https://api.pexels.com/v1/search?" + parse.urlencode(
        {"query": query, "per_page": 1, "orientation": "portrait"}
    )
    try:
        req = request.Request(url, headers={"Authorization": PEXELS_API_KEY})
        with request.urlopen(req, timeout=30) as resp:
            data = json.loads(resp.read())
        photos = data.get("photos") or []
        if not photos:
            return False
        src = (photos[0].get("src") or {}).get("large") or (photos[0].get("src") or {}).get("original")
        if not src:
            return False
        dest.parent.mkdir(parents=True, exist_ok=True)
        with request.urlopen(src, timeout=60) as img:
            dest.write_bytes(img.read())
        return dest.stat().st_size > 0
    except (error.URLError, error.HTTPError, TimeoutError, OSError, ValueError):
        return False


def _resolve_assets(storyboard: dict, public_dir: Path) -> None:
    """Resout in-place les blocs image (Pexels) et formules (Manim si active)."""
    assets_dir = public_dir / "assets"
    manim_dir = public_dir / "manim"
    for si, scene in enumerate(storyboard.get("scenes", []) or []):
        kept = []
        for bi, block in enumerate(scene.get("blocks", []) or []):
            btype = (block or {}).get("type")
            if btype == "image":
                q = (block.get("content") or "").strip()
                dest = assets_dir / f"s{si}_b{bi}.jpg"
                if _pexels_download(q, dest):
                    block["src"] = f"assets/{dest.name}"
                    kept.append(block)
                # sinon : image non resolue -> on retire le bloc (pas de rendu casse)
                continue
            if btype == "formula" and MANIM_ENABLED:
                clip = manim_dir / f"s{si}_b{bi}.mov"
                if _manim_formula(block.get("content") or "", clip):
                    block["videoSrc"] = f"manim/{clip.name}"
                kept.append(block)
                continue
            kept.append(block)
        scene["blocks"] = kept


def _manim_formula(latex: str, dest: Path) -> bool:
    """Rend un clip anime 'ecriture' de la formule via Manim. False si echec/absent."""
    if not latex.strip():
        return False
    try:
        dest.parent.mkdir(parents=True, exist_ok=True)
        _run([
            "python3", str(ENGINE_DIR / "manim_render.py"),
            "--latex", latex, "--out", str(dest),
        ], cwd=ENGINE_DIR)
        return dest.exists() and dest.stat().st_size > 0
    except Exception:
        return False


def render_storyboard_remotion(storyboard_json: Any, out_dir: Path) -> Path:
    """Rend un storyboard en MP4 via Remotion + assets + narration TTS."""
    storyboard = storyboard_json if isinstance(storyboard_json, dict) else json.loads(storyboard_json)

    job_dir = Path(out_dir)
    job_dir.mkdir(parents=True, exist_ok=True)
    storyboard_path = job_dir / "storyboard.json"
    narration_path = job_dir / "narration.json"
    output_path = job_dir / "output.mp4"

    # public/ nettoye a chaque job (narration + assets + manim) pour eviter les residus.
    for sub in ("narration", "assets", "manim"):
        d = ENGINE_DIR / "public" / sub
        if d.exists():
            shutil.rmtree(d, ignore_errors=True)
        d.mkdir(parents=True, exist_ok=True)

    # 1) Resolution des assets (images Pexels, formules Manim).
    _resolve_assets(storyboard, ENGINE_DIR / "public")
    storyboard_path.write_text(json.dumps(storyboard, ensure_ascii=False), encoding="utf-8")

    # 2) Narration TTS (echoue en douceur -> video sans voix).
    _run([
        "python3", str(ENGINE_DIR / "narrate.py"),
        "--storyboard", str(storyboard_path),
        "--public", str(ENGINE_DIR / "public"),
        "--out", str(narration_path),
    ], cwd=ENGINE_DIR)

    # 3) Rendu Remotion + finalisation ffmpeg (main/4.0, 720x1280).
    _run([
        "node", str(ENGINE_DIR / "render.mjs"),
        "--storyboard", str(storyboard_path),
        "--narration", str(narration_path),
        "--out", str(output_path),
    ], cwd=ENGINE_DIR, extra_env=NODE_ENV)

    if not output_path.exists():
        raise RuntimeError("[remotion] MP4 non produit")
    return output_path

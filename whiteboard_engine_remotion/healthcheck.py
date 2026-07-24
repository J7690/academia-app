#!/usr/bin/env python3
"""
Balise de santé du moteur Smart Whiteboard.

À exécuter SUR LE VPS (au démarrage du worker et/ou en cron). Sonde chaque outil du
studio et publie l'état dans Supabase (RPC app.whiteboard_report_engine_health). Cela
permet une VÉRIFICATION À DISTANCE de l'installation (Claude n'a pas d'accès SSH au VPS).

Usage :
  SUPABASE_URL=... SUPABASE_SERVICE_KEY=... python3 healthcheck.py

Puis, à distance : `select * from app.whiteboard_engine_health;`
"""
import json
import os
import shutil
import socket
import subprocess
from pathlib import Path
from urllib import request, error, parse

SUPABASE_URL = os.environ.get("SUPABASE_URL", "")
SERVICE_KEY = os.environ.get("SUPABASE_SERVICE_KEY") or os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")
ENGINE_DIR = Path(os.environ.get("REMOTION_ENGINE_DIR", str(Path(__file__).resolve().parent)))
KOKORO_URL = os.environ.get("KOKORO_URL", "")
PEXELS_API_KEY = os.environ.get("PEXELS_API_KEY", "")
MANIM_ENABLED = os.environ.get("MANIM_ENABLED", "") in {"1", "true", "yes"}


def _cmd(args) -> str | None:
    try:
        r = subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                           timeout=60, check=False)
        if r.returncode != 0:
            return None
        return r.stdout.decode(errors="ignore").strip().splitlines()[0][:80]
    except (FileNotFoundError, OSError, subprocess.TimeoutExpired):
        return None


def _http_up(url: str) -> bool:
    if not url:
        return False
    try:
        base = url.split("/v1/")[0] if "/v1/" in url else url
        req = request.Request(base, method="GET")
        with request.urlopen(req, timeout=10):
            return True
    except error.HTTPError:
        return True  # le serveur répond (même 404) => il tourne
    except (error.URLError, OSError, ValueError):
        return False


def probe() -> dict:
    node = _cmd(["node", "--version"])
    remotion_installed = (ENGINE_DIR / "node_modules" / "remotion" / "package.json").exists()
    chromium_cached = any((Path.home() / ".cache").rglob("chrome-headless-shell*")) or \
        any((Path.home() / ".cache").rglob("chromium*")) if (Path.home() / ".cache").exists() else False
    return {
        "node": node,
        "npm": _cmd(["npm", "--version"]),
        "ffmpeg": bool(shutil.which("ffmpeg")),
        "remotion_installed": remotion_installed,
        "chromium_ready": bool(chromium_cached),
        "kokoro_reachable": _http_up(KOKORO_URL),
        "pexels_key_set": bool(PEXELS_API_KEY),
        "manim_enabled": MANIM_ENABLED,
        "manim_installed": _cmd(["manim", "--version"]) is not None if MANIM_ENABLED else False,
        "engine_dir": str(ENGINE_DIR),
        # Prêt de bout en bout pour un rendu animé de base :
        "ready_basic": bool(node and remotion_installed and chromium_cached and shutil.which("ffmpeg")),
    }


def report(components: dict) -> bool:
    if not SUPABASE_URL or not SERVICE_KEY:
        print(json.dumps(components, indent=2, ensure_ascii=False))
        print("[health] SUPABASE_URL/KEY absents -> pas de publication (affichage local)")
        return False
    host = socket.gethostname()
    url = f"{SUPABASE_URL.rstrip('/')}/rest/v1/rpc/whiteboard_report_engine_health"
    body = json.dumps({"p_host": host, "p_components": components}).encode("utf-8")
    headers = {
        "apikey": SERVICE_KEY,
        "Authorization": f"Bearer {SERVICE_KEY}",
        "Content-Type": "application/json",
        "Content-Profile": "app",
    }
    try:
        with request.urlopen(request.Request(url, data=body, headers=headers, method="POST"), timeout=20) as r:
            print(f"[health] publié pour {host} (HTTP {r.status})")
            return True
    except (error.HTTPError, error.URLError, OSError) as e:
        print(f"[health] échec publication: {e}")
        return False


if __name__ == "__main__":
    report(probe())

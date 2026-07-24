#!/usr/bin/env python3
"""
Narration TTS auto-hébergée pour le moteur Remotion — ZÉRO crédit.

Moteur principal : KOKORO-82M (Apache 2.0, 54 voix dont le français, ~6x temps réel
sur CPU) via Kokoro-FastAPI (API compatible OpenAI). Repli automatique sur Piper si
Kokoro est injoignable, puis "pas de voix" si aucun TTS n'est dispo (dégradation douce).

Pour chaque scène : dérive le texte, synthétise un .wav dans public/narration/, mesure
sa durée, et écrit un manifest JSON consommé par render.mjs (le visuel se synchronise
sur la voix off).

Usage :
  python3 narrate.py --storyboard job/storyboard.json --public ./public --out job/narration.json

Config (variables d'environnement) :
  KOKORO_URL   = http://127.0.0.1:8880/v1/audio/speech   (Kokoro-FastAPI)
  KOKORO_VOICE = ff_siwis                                 (voix française)
  KOKORO_MODEL = kokoro
  PIPER_BIN / PIPER_MODEL                                 (repli optionnel)
"""
import argparse
import json
import os
import subprocess
import wave
from pathlib import Path
from urllib import request, error

KOKORO_URL = os.environ.get("KOKORO_URL", "http://127.0.0.1:8880/v1/audio/speech")
KOKORO_VOICE = os.environ.get("KOKORO_VOICE", "ff_siwis")
KOKORO_MODEL = os.environ.get("KOKORO_MODEL", "kokoro")
PIPER_BIN = os.environ.get("PIPER_BIN", "")
PIPER_MODEL = os.environ.get("PIPER_MODEL", "")


def scene_narration_text(scene: dict) -> str:
    """Texte à dire : champ `narration` sinon concaténation des blocs lisibles."""
    if scene.get("narration"):
        return str(scene["narration"]).strip()
    parts = []
    for b in scene.get("blocks", []) or []:
        t = (b or {}).get("type")
        content = ((b or {}).get("content") or "").strip()
        if not content or t in ("formula", "image"):  # on ne lit pas le LaTeX / les images
            continue
        parts.append(content)
    return " ".join(parts).strip()


def synth_kokoro(text: str, out_wav: Path) -> bool:
    """Kokoro-FastAPI (compatible OpenAI). Retourne False si indisponible."""
    payload = json.dumps({
        "model": KOKORO_MODEL,
        "input": text,
        "voice": KOKORO_VOICE,
        "response_format": "wav",
        # Léger ralentissement = diction plus naturelle, moins "robotique".
        "speed": float(os.environ.get("KOKORO_SPEED", "0.95")),
    }).encode("utf-8")
    req = request.Request(KOKORO_URL, data=payload,
                          headers={"Content-Type": "application/json"}, method="POST")
    try:
        with request.urlopen(req, timeout=120) as resp:
            data = resp.read()
        if not data:
            return False
        out_wav.parent.mkdir(parents=True, exist_ok=True)
        out_wav.write_bytes(data)
        return out_wav.stat().st_size > 0
    except (error.URLError, error.HTTPError, TimeoutError, OSError):
        return False


def synth_piper(text: str, out_wav: Path) -> bool:
    """Repli Piper (CPU) si Kokoro absent."""
    if not PIPER_BIN or not PIPER_MODEL:
        return False
    try:
        out_wav.parent.mkdir(parents=True, exist_ok=True)
        proc = subprocess.run(
            [PIPER_BIN, "--model", PIPER_MODEL, "--output_file", str(out_wav)],
            input=text.encode("utf-8"),
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False,
        )
        return proc.returncode == 0 and out_wav.exists() and out_wav.stat().st_size > 0
    except FileNotFoundError:
        return False


def synthesize(text: str, out_wav: Path) -> bool:
    return synth_kokoro(text, out_wav) or synth_piper(text, out_wav)


def wav_duration_sec(path: Path) -> float:
    try:
        with wave.open(str(path), "rb") as w:
            return round(w.getnframes() / float(w.getframerate() or 1), 3)
    except Exception:
        # Repli ffprobe (si le wav n'est pas lisible par le module wave)
        try:
            out = subprocess.run(
                ["ffprobe", "-v", "error", "-show_entries", "format=duration",
                 "-of", "default=nw=1:nk=1", str(path)],
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False,
            )
            return round(float(out.stdout.decode().strip() or 0), 3)
        except Exception:
            return 0.0


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--storyboard", required=True)
    ap.add_argument("--public", default="./public")
    ap.add_argument("--out", required=True)
    a = ap.parse_args()

    storyboard = json.loads(Path(a.storyboard).read_text(encoding="utf-8"))
    public_dir = Path(a.public)
    scenes = storyboard.get("scenes", []) or []

    manifest = []
    for i, scene in enumerate(scenes):
        text = scene_narration_text(scene)
        rel = f"narration/scene_{i}.wav"
        abs_wav = public_dir / rel
        if text and synthesize(text, abs_wav):
            manifest.append({"scene_index": i, "audio_path": rel,
                             "duration_sec": wav_duration_sec(abs_wav)})
        else:
            manifest.append({"scene_index": i, "audio_path": None, "duration_sec": 0.0})

    Path(a.out).write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    narrated = sum(1 for m in manifest if m["audio_path"])
    print(f"[narrate] {narrated}/{len(manifest)} scènes narrées (Kokoro/Piper)")


if __name__ == "__main__":
    main()

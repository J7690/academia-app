"""
Whiteboard Narration - Phase G
Génère une narration audio (TTS) synchronisée avec les scènes du storyboard.

Moteur TTS : gTTS (Google Translate TTS) - gratuit, voix française, pas de clé API.
Mixage : FFmpeg (déjà présent sur le VPS).

Flux :
1. Pour chaque scène, on extrait un texte lisible depuis les blocs.
2. On génère un MP3 par scène via gTTS.
3. On mesure la durée de chaque MP3 (ffprobe).
4. On calcule la durée effective de chaque scène = max(durée storyboard, audio + padding).
5. On construit une piste audio unique où chaque segment de scène est complété
   par du silence jusqu'à la durée effective de la scène.
6. Le worker assemble la vidéo avec ces durées, puis mux la piste audio.
"""

from __future__ import annotations

import logging
import os
import re
import subprocess
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import httpx

logger = logging.getLogger("whiteboard_narration")

SUPABASE_URL = os.getenv("SUPABASE_URL", "").rstrip("/")
SUPABASE_SERVICE_KEY = os.getenv("SUPABASE_SERVICE_KEY", "")
WHITEBOARD_TTS_URL = f"{SUPABASE_URL}/functions/v1/whiteboard-tts" if SUPABASE_URL else ""

try:
    from gtts import gTTS
    _HAS_GTTS = True
except ImportError:
    _HAS_GTTS = False

# Padding de silence ajouté après chaque narration (secondes)
SCENE_PADDING_SEC = 0.8
# Durée minimale d'une scène sans texte (secondes)
MIN_SCENE_SEC = 2.0
# Longueur maximale de texte narré par scène (caractères) pour éviter des audios interminables
MAX_NARRATION_CHARS = 600


def is_available() -> bool:
    """Indique si au moins un fournisseur TTS est utilisable."""
    return bool(WHITEBOARD_TTS_URL and SUPABASE_SERVICE_KEY) or _HAS_GTTS


def _generate_openrouter_tts(text: str, output_path: Path, language: str) -> None:
    """Génère un MP3 via l'Edge Function interne et les crédits OpenRouter."""
    if not WHITEBOARD_TTS_URL or not SUPABASE_SERVICE_KEY:
        raise RuntimeError("Supabase credentials unavailable for OpenRouter TTS")

    response = httpx.post(
        WHITEBOARD_TTS_URL,
        headers={
            "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
            "apikey": SUPABASE_SERVICE_KEY,
            "Content-Type": "application/json",
        },
        json={"input": text},
        timeout=90.0,
    )
    if not response.is_success:
        raise RuntimeError(
            f"OpenRouter TTS HTTP {response.status_code}: {response.text[:500]}"
        )
    if not response.content:
        raise RuntimeError("OpenRouter TTS returned empty audio")
    output_path.write_bytes(response.content)
    logger.info(
        f"[narration] OpenRouter TTS generated {len(response.content)} bytes "
        f"({response.headers.get('X-TTS-Model', 'unknown model')})"
    )


def _generate_tts(text: str, output_path: Path, language: str) -> str:
    """Utilise OpenRouter en priorité et gTTS uniquement si OpenRouter échoue."""
    try:
        _generate_openrouter_tts(text, output_path, language)
        return "openrouter"
    except Exception as openrouter_error:
        logger.warning(f"[narration] OpenRouter TTS unavailable: {openrouter_error}")
        if not _HAS_GTTS:
            raise
        tts = gTTS(text=text, lang=language)
        tts.save(str(output_path))
        logger.info("[narration] gTTS fallback generated audio")
        return "gtts"


def _clean_latex(text: str) -> str:
    """Convertit grossièrement du LaTeX en texte lisible pour la voix."""
    if not text:
        return ""
    t = text
    t = re.sub(r"\\frac\{([^}]*)\}\{([^}]*)\}", r"\1 sur \2", t)
    t = re.sub(r"\\sqrt\{([^}]*)\}", r"racine de \1", t)
    t = t.replace("\\times", " fois ").replace("\\cdot", " fois ")
    t = t.replace("\\pm", " plus ou moins ").replace("\\div", " divisé par ")
    t = t.replace("\\leq", " inférieur ou égal à ").replace("\\geq", " supérieur ou égal à ")
    t = t.replace("\\neq", " différent de ").replace("\\infty", " l'infini ")
    t = t.replace("^2", " au carré ").replace("^3", " au cube ")
    t = re.sub(r"[\\{}$^_]", " ", t)
    t = re.sub(r"\s+", " ", t).strip()
    return t


def _scene_text(scene: Dict[str, Any]) -> str:
    """Construit le texte à narrer pour une scène à partir de ses blocs."""
    parts: List[str] = []
    title = scene.get("title")
    if isinstance(title, str) and title.strip():
        parts.append(title.strip())

    for block in scene.get("blocks", []) or []:
        if not isinstance(block, dict):
            continue
        if not block.get("visible", True):
            continue
        btype = block.get("type")
        if btype in ("diagram", "graph"):
            # Non narrés (contenu structurel/visuel)
            continue
        if btype == "formula":
            content = _clean_latex(block.get("content", ""))
            if content:
                parts.append(content)
            continue
        if btype == "definition":
            term = block.get("term", "")
            definition = block.get("definition", block.get("content", ""))
            frag = ". ".join(x for x in [term, definition] if x)
            if frag:
                parts.append(frag)
            continue
        if btype == "exercise":
            q = block.get("question", block.get("content", ""))
            if q:
                parts.append(q)
            continue
        if btype == "correction":
            expl = block.get("explanation", block.get("content", ""))
            steps = block.get("steps", []) or []
            frag = ". ".join([str(s) for s in steps] + ([expl] if expl else []))
            if frag:
                parts.append(frag)
            continue
        # title, paragraph et autres : contenu brut
        content = block.get("content", "")
        if isinstance(content, str) and content.strip():
            parts.append(content.strip())

    text = ". ".join(parts).strip()
    text = re.sub(r"\s+", " ", text)
    if len(text) > MAX_NARRATION_CHARS:
        text = text[:MAX_NARRATION_CHARS].rsplit(" ", 1)[0] + "."
    return text


def _probe_duration_sec(audio_path: Path) -> float:
    """Retourne la durée d'un fichier audio via ffprobe (secondes)."""
    try:
        out = subprocess.run(
            [
                "ffprobe", "-v", "error", "-show_entries", "format=duration",
                "-of", "default=noprint_wrappers=1:nokey=1", str(audio_path),
            ],
            capture_output=True, text=True, timeout=30,
        )
        return float(out.stdout.strip())
    except Exception as e:
        logger.warning(f"[narration] ffprobe failed for {audio_path}: {e}")
        return 0.0


def _pad_audio(src: Path, dst: Path, target_sec: float, language: str = "fr") -> None:
    """Complète un audio avec du silence pour atteindre target_sec, réencode en WAV 44.1k stéréo."""
    subprocess.run(
        [
            "ffmpeg", "-y", "-i", str(src),
            "-af", f"apad=whole_dur={target_sec:.3f}",
            "-ar", "44100", "-ac", "2",
            str(dst),
        ],
        capture_output=True, text=True, timeout=120, check=True,
    )


def _silence_wav(dst: Path, target_sec: float) -> None:
    """Génère un WAV de silence de target_sec secondes."""
    subprocess.run(
        [
            "ffmpeg", "-y", "-f", "lavfi",
            "-i", "anullsrc=channel_layout=stereo:sample_rate=44100",
            "-t", f"{target_sec:.3f}",
            str(dst),
        ],
        capture_output=True, text=True, timeout=60, check=True,
    )


def build_narration(
    storyboard: Dict[str, Any],
    base_scene_durations_sec: List[float],
    work_dir: Path,
    language: str = "fr",
) -> Optional[Tuple[Path, List[float]]]:
    """
    Génère la piste de narration et les durées de scène ajustées.

    Args:
        storyboard: le storyboard JSON (dict).
        base_scene_durations_sec: durées initiales par scène (issues du storyboard).
        work_dir: répertoire de travail temporaire.
        language: langue TTS (défaut 'fr').

    Returns:
        (chemin_audio_narration, durées_ajustées_sec) ou None si indisponible.
    """
    if not _HAS_GTTS:
        logger.warning("[narration] gTTS indisponible, narration ignorée")
        return None

    scenes = storyboard.get("scenes", []) or []
    if not scenes:
        return None

    segment_paths: List[Path] = []
    adjusted_durations: List[float] = []

    for idx, scene in enumerate(scenes):
        base_dur = base_scene_durations_sec[idx] if idx < len(base_scene_durations_sec) else MIN_SCENE_SEC
        text = _scene_text(scene if isinstance(scene, dict) else {})

        seg_path = work_dir / f"narration_scene_{idx:03d}.wav"

        if not text:
            # Aucune narration : silence de la durée de base
            target = max(base_dur, MIN_SCENE_SEC)
            _silence_wav(seg_path, target)
            adjusted_durations.append(target)
            segment_paths.append(seg_path)
            continue

        # 1. Générer le MP3 : OpenRouter premium, puis gTTS si indisponible
        mp3_path = work_dir / f"narration_scene_{idx:03d}.mp3"
        try:
            provider = _generate_tts(text, mp3_path, language)
        except Exception as e:
            logger.warning(f"[narration] TTS échec scène {idx}: {e}")
            target = max(base_dur, MIN_SCENE_SEC)
            _silence_wav(seg_path, target)
            adjusted_durations.append(target)
            segment_paths.append(seg_path)
            continue

        # 2. Mesurer la durée de la narration
        audio_dur = _probe_duration_sec(mp3_path)
        # 3. Durée effective = max(storyboard, narration + padding)
        target = max(base_dur, audio_dur + SCENE_PADDING_SEC, MIN_SCENE_SEC)
        # 4. Padder l'audio avec du silence jusqu'à target
        try:
            _pad_audio(mp3_path, seg_path, target, language)
        except Exception as e:
            logger.warning(f"[narration] pad échec scène {idx}: {e}")
            _silence_wav(seg_path, target)

        adjusted_durations.append(target)
        segment_paths.append(seg_path)
        logger.info(
            f"[narration] scène {idx}: provider={provider} text={len(text)}c "
            f"audio={audio_dur:.1f}s target={target:.1f}s"
        )

    # 5. Concaténer tous les segments en une piste unique
    concat_list = work_dir / "narration_concat.txt"
    with open(concat_list, "w", encoding="utf-8") as f:
        for p in segment_paths:
            f.write(f"file '{p.as_posix()}'\n")

    narration_path = work_dir / "narration_full.wav"
    try:
        subprocess.run(
            [
                "ffmpeg", "-y", "-f", "concat", "-safe", "0",
                "-i", str(concat_list),
                "-ar", "44100", "-ac", "2",
                str(narration_path),
            ],
            capture_output=True, text=True, timeout=180, check=True,
        )
    except subprocess.CalledProcessError as e:
        logger.error(f"[narration] concat échec: {e.stderr[:400] if e.stderr else e}")
        return None

    logger.info(f"[narration] piste générée: {narration_path} ({len(scenes)} scènes)")
    return narration_path, adjusted_durations


def mux_audio_into_video(video_path: Path, audio_path: Path, out_path: Path) -> Path:
    """Injecte la piste de narration dans la vidéo (qui n'a pas d'audio)."""
    subprocess.run(
        [
            "ffmpeg", "-y",
            "-i", str(video_path),
            "-i", str(audio_path),
            "-map", "0:v",
            "-map", "1:a",
            "-c:v", "copy",
            "-c:a", "aac",
            "-b:a", "192k",
            "-shortest",
            str(out_path),
        ],
        capture_output=True, text=True, timeout=300, check=True,
    )
    return out_path

"""
Whiteboard FFmpeg Assembler - v9 CORRECTION LECTURE ANDROID + DUREES

CAUSE RACINE #1 corrigee (erreur MediaCodecVideoRenderer sur l'app) :
  v5..v7 forçaient baseline@3.1 sur une image 1080x1920 (illegale).
  v8 a corrige la resolution en 720x1280 MAIS a garde baseline@3.1 :
  720x1280@30 tombe EXACTEMENT sur les plafonds du Level 3.1
  (MaxFS = 3600 macroblocs = 45x80 ; MaxMBPS = 108000 = 3600x30). Un flux
  epingle pile sur le plafond est refuse par les decodeurs materiels des
  telephones d'entree de gamme (format_supported=YES via le tag, puis
  echec reel dans MediaCodecVideoRenderer).

  Correctif v9 : profil `main` + Level 4.0 (MaxFS 8192, MaxMBPS 245760).
  Grosse marge sous le plafond, meme resolution 720x1280@30, lu par tous
  les Android depuis ~10 ans. C'est la cible reelle de TikTok/Reels/Shorts.
  Pour repasser en 1080p : TARGET_W/H = 1080/1920, profil "high", level "4.1".

CAUSE RACINE #2 corrigee (durees ignorees) :
  v8 imposait 5 s fixes par scene (SECONDS_PER_SCENE) et ignorait les
  durees du storyboard. v9 accepte un parametre `durations` (secondes par
  scene, aligne 1:1 sur png_paths) et respecte les durees demandees.
  Retro-compatible : si `durations` est None, repli sur 5 s/scene.

Corrections precedentes conservees :
  v7: piste audio silencieuse (compat ExoPlayer/OMX Qualcomm)
  v6: colorspace sRGB->BT709 | v5: metadata BT709, no B-frames
  C1: concat demuxer duree explicite | C2: faststart (moov avant mdat)
"""
from pathlib import Path
from typing import List, Optional, Sequence
import subprocess

SECONDS_PER_SCENE = 5
FPS = 30
MIN_SCENE_SECONDS = 1.0  # garde-fou : une scene ne descend jamais sous 1 s

# --- Cible d'encodage (voir docstring) -------------------------------------
# Compatibilite maximale (defaut) : 720x1280, main, level 4.0.
# Qualite HD (parc recent) : 1080, 1920, "high", "4.1".
TARGET_W = 720
TARGET_H = 1280
H264_PROFILE = "main"
H264_LEVEL = "4.0"


def assemble_pngs_to_mp4(
    png_paths: List[Path],
    output_dir: Path,
    durations: Optional[Sequence[float]] = None,
) -> Path:
    if not png_paths:
        raise ValueError("No PNGs provided")
    for p in png_paths:
        if not p.exists():
            raise FileNotFoundError(f"PNG not found: {p}")

    # Durees par scene : soit fournies (storyboard), soit 5 s par defaut.
    # On aligne strictement sur le nombre de PNG (1 PNG = 1 scene).
    if durations is None:
        scene_seconds = [float(SECONDS_PER_SCENE)] * len(png_paths)
    else:
        scene_seconds = []
        for i in range(len(png_paths)):
            try:
                d = float(durations[i]) if i < len(durations) else float(SECONDS_PER_SCENE)
            except (TypeError, ValueError):
                d = float(SECONDS_PER_SCENE)
            scene_seconds.append(max(d, MIN_SCENE_SECONDS))

    video_filter = (
        f"scale={TARGET_W}:{TARGET_H}:force_original_aspect_ratio=decrease,"
        f"pad={TARGET_W}:{TARGET_H}:(ow-iw)/2:(oh-ih)/2:color=white,"
        "setsar=1,"
        "colorspace=all=bt709:iall=bt709:itrc=srgb,"
        "format=yuv420p"
    )

    # --- Etape 1 : un segment MP4 par scene, a duree EXACTE (-t) -------------
    # On n'utilise PLUS le concat demuxer pour tenir les durees : sur des
    # images fixes il est non fiable (la derniere scene est tronquee ou une
    # duree est ajoutee en trop). `-loop 1 -t <secs>` donne une duree exacte.
    seg_paths: List[Path] = []
    for i, (p, secs) in enumerate(zip(png_paths, scene_seconds)):
        seg = output_dir / f"seg_{i:04d}.mp4"
        seg_cmd = [
            "ffmpeg", "-y",
            "-loop", "1", "-t", f"{secs:.3f}", "-i", str(p),
            "-vf", video_filter,
            "-c:v", "libx264",
            "-profile:v", H264_PROFILE,
            "-level:v", H264_LEVEL,
            "-pix_fmt", "yuv420p",
            "-r", str(FPS),
            "-g", str(FPS * 2),
            "-preset", "fast",
            "-crf", "23",
            "-colorspace", "bt709",
            "-color_primaries", "bt709",
            "-color_trc", "bt709",
            "-color_range", "tv",
            "-x264-params", "colorprim=bt709:transfer=bt709:colormatrix=bt709:fullrange=0",
            str(seg),
        ]
        _run(seg_cmd, f"segment {i}")
        seg_paths.append(seg)

    # --- Etape 2 : concatenation des segments par copie (exacte, rapide) -----
    concat_file = output_dir / "concat.txt"
    with open(concat_file, "w") as f:
        for seg in seg_paths:
            safe = str(seg).replace("'", "'\\''")
            f.write(f"file '{safe}'\n")

    concat_video = output_dir / "concat_video.mp4"
    _run([
        "ffmpeg", "-y",
        "-f", "concat", "-safe", "0", "-i", str(concat_file),
        "-c", "copy",
        str(concat_video),
    ], "concat")

    # --- Etape 3 : piste audio silencieuse (compat ExoPlayer/OMX) + faststart
    mp4_path = output_dir / "output.mp4"
    _run([
        "ffmpeg", "-y",
        "-i", str(concat_video),
        "-f", "lavfi", "-i", "anullsrc=r=44100:cl=stereo",
        "-c:v", "copy",
        "-c:a", "aac", "-b:a", "64k", "-ar", "44100", "-ac", "2",
        "-shortest",
        "-movflags", "+faststart",
        str(mp4_path),
    ], "mux audio")

    if not mp4_path.exists():
        raise RuntimeError(f"MP4 not created: {mp4_path}")

    return mp4_path


def _run(cmd: List[str], label: str) -> None:
    r = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    if r.returncode != 0:
        err = r.stderr.decode(errors="ignore")
        raise RuntimeError(f"FFmpeg error [{label}] ({r.returncode}): {err[:3000]}")

"""
Whiteboard FFmpeg Assembler - v7 CORRECTION D.25
P1: Ajout piste audio silencieuse pour compatibilite ExoPlayer Android
    OMX Qualcomm echoue sur MP4 video-only avec format_supported=YES
    Solution: -f lavfi -i anullsrc + -c:a aac -b:a 64k -shortest

Toutes corrections precedentes maintenues:
  v6: colorspace sRGB->BT709 (plus de smpte170m)
  v5: BT709 metadata, Baseline 3.1, no B-frames
  C1: concat demuxer duree explicite
  C2: faststart (moov avant mdat)
  C3: Baseline profile
"""
from pathlib import Path
from typing import List
import subprocess

SECONDS_PER_SCENE = 5
FPS = 30


def assemble_pngs_to_mp4(png_paths: List[Path], output_dir: Path) -> Path:
    if not png_paths:
        raise ValueError("No PNGs provided")
    for p in png_paths:
        if not p.exists():
            raise FileNotFoundError(f"PNG not found: {p}")

    # C1: concat demuxer avec duree explicite par scene
    concat_file = output_dir / "concat.txt"
    with open(concat_file, "w") as f:
        for p in png_paths:
            safe = str(p).replace("'", "'\\''")
            f.write(f"file '{safe}'\n")
            f.write(f"duration {SECONDS_PER_SCENE}\n")
        last = str(png_paths[-1]).replace("'", "'\\''")
        f.write(f"file '{last}'\n")

    mp4_path = output_dir / "output.mp4"

    # v7: Encodage DIRECT avec faststart + audio silencieux (une seule passe)
    # -f lavfi -i anullsrc: generateur audio silencieux
    # -c:a aac -b:a 64k: encoder AAC (requis pour ExoPlayer)
    # -shortest: terminer quand la video se termine
    # -movflags +faststart: moov avant mdat (streaming)
    cmd = [
        "ffmpeg", "-y",
        # Input 1: video (concat demuxer)
        "-f", "concat",
        "-safe", "0",
        "-i", str(concat_file),
        # Input 2: audio silencieux
        "-f", "lavfi",
        "-i", "anullsrc=r=44100:cl=stereo",
        # Filtre video: colorspace correction sRGB->BT709 (v6)
        "-vf", (
            "scale=1080:1920:force_original_aspect_ratio=decrease,"
            "pad=1080:1920:(ow-iw)/2:(oh-ih)/2:color=white,"
            "setsar=1,"
            "colorspace=all=bt709:iall=bt709:itrc=srgb,"
            "format=yuv420p"
        ),
        # Codec video
        "-c:v", "libx264",
        "-profile:v", "baseline",
        "-level:v", "3.1",
        "-pix_fmt", "yuv420p",
        "-r", str(FPS),
        "-g", str(FPS * 2),
        "-preset", "fast",
        "-crf", "28",
        # Metadata couleur BT709 (v5/v6)
        "-colorspace", "bt709",
        "-color_primaries", "bt709",
        "-color_trc", "bt709",
        "-color_range", "tv",
        # x264 VUI tagging BT709 pur (v6)
        "-x264-params", "colorprim=bt709:transfer=bt709:colormatrix=bt709:fullrange=0",
        # Codec audio silencieux (v7 - P1)
        "-c:a", "aac",
        "-b:a", "64k",
        "-ar", "44100",
        "-ac", "2",
        # Terminer quand la video se termine
        "-shortest",
        # C2: faststart (moov avant mdat) - EN UNE SEULE PASSE (P3 bonus)
        "-movflags", "+faststart",
        str(mp4_path),
    ]

    r = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    if r.returncode != 0:
        err = r.stderr.decode(errors="ignore")
        raise RuntimeError(f"FFmpeg error ({r.returncode}): {err[:3000]}")

    if not mp4_path.exists():
        raise RuntimeError(f"MP4 not created: {mp4_path}")

    return mp4_path

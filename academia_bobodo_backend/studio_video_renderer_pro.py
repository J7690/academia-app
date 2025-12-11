from pathlib import Path
import tempfile
import subprocess
from typing import List, Optional

from fastapi import HTTPException


def run_ffmpeg_tv_pro(
    input_paths: List[Path],
    *,
    filter_complex: str,
    label: str,
    max_bitrate_k: int,
    audio_bitrate_k: int,
    fps: Optional[int] = None,
    map_audio_from: int = 0,
) -> Path:
    if not input_paths:
        raise HTTPException(
            status_code=400,
            detail=f"[{label}] No input paths provided for tv_pro render",
        )

    for p in input_paths:
        if not p.exists():
            raise HTTPException(
                status_code=400,
                detail=f"[{label}] Input file does not exist: {p}",
            )

    tmp_dir = Path(tempfile.mkdtemp(prefix=f"studio_tv_pro_{label}_"))
    output_path = tmp_dir / "output.mp4"

    maxrate = f"{max_bitrate_k}k"
    bufsize = f"{2 * max_bitrate_k}k"
    audio_bitrate = f"{audio_bitrate_k}k"

    x264_params = (
        "ref=1:"
        "bframes=0:"
        "cabac=0:"
        "deblock=0:"
        "weightp=0:"
        "no-scenecut=1:"
        "level=30:"
        f"vbv-maxrate={max_bitrate_k}:"
        f"vbv-bufsize={2 * max_bitrate_k}"
    )

    cmd: List[str] = [
        "ffmpeg",
        "-y",
    ]

    for p in input_paths:
        cmd.extend(["-i", str(p)])

    cmd.extend(
        [
            "-filter_complex",
            filter_complex,
            "-map",
            "[vout]",
            "-map",
            f"{map_audio_from}:a?",
            "-c:v",
            "libx264",
            "-preset",
            "veryfast",
            "-profile:v",
            "baseline",
            "-level",
            "3.0",
            "-x264-params",
            x264_params,
        ]
    )

    if fps is not None:
        cmd.extend(["-r", str(fps)])

    cmd.extend(
        [
            "-g",
            "30",
            "-keyint_min",
            "30",
            "-pix_fmt",
            "yuv420p",
            "-color_primaries",
            "bt709",
            "-color_trc",
            "bt709",
            "-colorspace",
            "bt709",
            "-movflags",
            "+faststart",
            "-c:a",
            "aac",
            "-ac",
            "2",
            "-ar",
            "44100",
            "-b:a",
            audio_bitrate,
            "-maxrate",
            maxrate,
            "-bufsize",
            bufsize,
            str(output_path),
        ]
    )

    print(f"[FFMPEG-{label}-TVPRO] Running command: {' '.join(cmd)}")

    try:
        result = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"[{label}] Failed to start ffmpeg (tv_pro): {e}",
        )

    if result.returncode != 0:
        stderr_text = result.stderr.decode("utf-8", errors="ignore")
        print(f"[FFMPEG-{label}-TVPRO] FAILED with code {result.returncode}")
        print(f"[FFMPEG-{label}-TVPRO] STDERR:\n{stderr_text[:4000]}")
        raise HTTPException(
            status_code=500,
            detail=(
                f"[{label}] ffmpeg error (tv_pro, code {result.returncode}): "
                f"{stderr_text[:4000]}"
            ),
        )

    if not output_path.exists():
        raise HTTPException(
            status_code=500,
            detail=f"[{label}] ffmpeg succeeded (tv_pro) but output file is missing",
        )

    print(f"[FFMPEG-{label}-TVPRO] SUCCESS output={output_path}")
    return output_path

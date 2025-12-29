from pathlib import Path
import os
import uuid
import tempfile
import subprocess
from typing import Any, Dict, Optional, List

import httpx
from fastapi import FastAPI, HTTPException, Request
from pydantic import BaseModel
from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent
load_dotenv(BASE_DIR / ".env")

STUDIO_VIDEO_RENDER_API_KEY = os.getenv("STUDIO_VIDEO_RENDER_API_KEY")
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_KEY = os.getenv("SUPABASE_SERVICE_KEY")


class RenderRequest(BaseModel):
    video_url: str
    overlays: Dict[str, Any] = {}
    participation_id: str


class RenderResponse(BaseModel):
    video_url: str
    video_renditions: Dict[str, str]


app = FastAPI(title="Academia Studio Video Renderer")


async def _download_video_to_temp(url: str) -> Path:
    cleaned = (url or "").strip()
    if not cleaned:
        raise HTTPException(status_code=400, detail="video_url manquant.")

    tmp_dir = Path(tempfile.gettempdir())
    file_name = f"input_{uuid.uuid4().hex}.mp4"
    dest_path = tmp_dir / file_name

    async with httpx.AsyncClient(timeout=600.0) as client:
        resp = await client.get(cleaned)

    if resp.status_code >= 400:
        raise HTTPException(
            status_code=502,
            detail=f"Erreur lors du téléchargement de la vidéo source ({resp.status_code}).",
        )

    dest_path.write_bytes(resp.content)
    return dest_path


def _run_ffmpeg_transcode(input_path: Path) -> Path:
    """Rendition principale "source légère" compatible Android/MediaTek.

    - max largeur ~ 720 px
    - H.264 Baseline Level 3.0
    - pas de B-frames, pas de CABAC
    - GOP court (g=30) pour limiter les soucis de décodage matériel
    - bitrate modéré adapté aux appareils d'entrée de gamme
    """

    return _run_ffmpeg_generic(
        input_path=input_path,
        max_width=720,
        max_bitrate_k=900,
        audio_bitrate_k=96,
        label="main",
        fps=None,
    )


def _run_ffmpeg_transcode_480p(input_path: Path) -> Path:
    """Rendition 480p prioritaire sur les devices suffisamment puissants."""

    return _run_ffmpeg_generic(
        input_path=input_path,
        max_width=480,
        max_bitrate_k=600,
        audio_bitrate_k=96,
        label="480p",
        fps=30,
    )


def _run_ffmpeg_transcode_360p(input_path: Path) -> Path:
    """Rendition 360p (fallback solide pour les appareils fragiles)."""

    return _run_ffmpeg_generic(
        input_path=input_path,
        max_width=360,
        max_bitrate_k=450,
        audio_bitrate_k=80,
        label="360p",
        fps=30,
    )


def _run_ffmpeg_transcode_240p(input_path: Path) -> Path:
    """Rendition 240p (dernier recours pour très vieux/low‑end téléphones)."""

    return _run_ffmpeg_generic(
        input_path=input_path,
        max_width=240,
        max_bitrate_k=300,
        audio_bitrate_k=64,
        label="240p",
        fps=24,
    )


def _run_ffmpeg_generic(
    input_path: Path,
    max_width: int,
    max_bitrate_k: int,
    audio_bitrate_k: int,
    label: str,
    fps: Optional[int] = None,
    extra_filters: Optional[str] = None,
) -> Path:
    """Transcode une vidéo en MP4 H.264 ultra-compatible (MediaTek-friendly).

    - H.264 Baseline, Level 3.0
    - yuv420p
    - Aucun B-frame, ref=1
    - Paramètres x264 simples
    - Colorimétrie BT709 explicite
    """

    if not input_path.exists():
        raise HTTPException(
            status_code=400,
            detail=f"[{label}] Input file does not exist: {input_path}",
        )

    tmp_dir = Path(tempfile.mkdtemp(prefix=f"studio_render_{label}_"))
    output_path = tmp_dir / "output.mp4"

    vf_filter = f"scale='min({max_width},iw)':-2,format=yuv420p"
    if extra_filters:
        vf_filter = f"{vf_filter},{extra_filters}"

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

    cmd = [
        "ffmpeg",
        "-y",
        "-i",
        str(input_path),
        "-sws_flags",
        "lanczos+accurate_rnd+full_chroma_int",
        "-vf",
        vf_filter,
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

    if fps is not None:
        cmd.extend(["-r", str(fps)])

    cmd.extend([
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
    ])

    print(f"[FFMPEG-{label}] Running command: {' '.join(cmd)}")

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
            detail=f"[{label}] Failed to start ffmpeg: {e}",
        )

    if result.returncode != 0:
        stderr_text = result.stderr.decode("utf-8", errors="ignore")
        print(f"[FFMPEG-{label}] FAILED with code {result.returncode}")
        print(f"[FFMPEG-{label}] STDERR:\n{stderr_text[:4000]}")
        raise HTTPException(
            status_code=500,
            detail=(
                f"[{label}] ffmpeg error (code {result.returncode}): "
                f"{stderr_text[:4000]}"
            ),
        )

    if not output_path.exists():
        raise HTTPException(
            status_code=500,
            detail=f"[{label}] ffmpeg succeeded but output file is missing",
        )

    print(f"[FFMPEG-{label}] SUCCESS output={output_path}")
    return output_path


def _run_ffmpeg_tv_complex(
    input_paths: List[Path],
    *,
    filter_complex: str,
    label: str,
    max_bitrate_k: int,
    audio_bitrate_k: int,
    fps: Optional[int] = None,
) -> Path:
    """Transcode TV avec filter_complex multi-input.

    Le filter_complex doit produire un flux vidéo nommé [vout]. L'audio est
    mappé depuis la première entrée (0:a?) lorsqu'il existe.
    """

    if not input_paths:
        raise HTTPException(
            status_code=400,
            detail=f"[{label}] No input paths provided for tv_complex render",
        )

    for p in input_paths:
        if not p.exists():
            raise HTTPException(
                status_code=400,
                detail=f"[{label}] Input file does not exist: {p}",
            )

    tmp_dir = Path(tempfile.mkdtemp(prefix=f"studio_render_{label}_"))
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
            "0:a?",
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

    print(f"[FFMPEG-{label}-TV] Running command: {' '.join(cmd)}")

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
            detail=f"[{label}] Failed to start ffmpeg (tv_complex): {e}",
        )

    if result.returncode != 0:
        stderr_text = result.stderr.decode("utf-8", errors="ignore")
        print(f"[FFMPEG-{label}-TV] FAILED with code {result.returncode}")
        print(f"[FFMPEG-{label}-TV] STDERR:\n{stderr_text[:4000]}")
        raise HTTPException(
            status_code=500,
            detail=(
                f"[{label}] ffmpeg error (tv_complex, code {result.returncode}): "
                f"{stderr_text[:4000]}"
            ),
        )

    if not output_path.exists():
        raise HTTPException(
            status_code=500,
            detail=f"[{label}] ffmpeg succeeded (tv_complex) but output file is missing",
        )

    print(f"[FFMPEG-{label}-TV] SUCCESS output={output_path}")
    return output_path


async def _upload_to_supabase_storage(path: Path, participation_id: str) -> str:
    if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
        raise HTTPException(
            status_code=500,
            detail="SUPABASE_URL ou SUPABASE_SERVICE_KEY manquante pour le rendu vidéo.",
        )

    bucket = "challenge-media"
    object_key = f"renders/{participation_id}/{uuid.uuid4().hex}.mp4"
    storage_url = f"{SUPABASE_URL}/storage/v1/object/{bucket}/{object_key}"

    headers = {
        "apikey": SUPABASE_SERVICE_KEY,
        "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
        "Content-Type": "video/mp4",
    }

    data = path.read_bytes()

    async with httpx.AsyncClient(timeout=600.0) as client:
        resp = await client.post(storage_url, headers=headers, content=data)

    if resp.status_code >= 400:
        try:
            body = resp.json()
        except ValueError:
            body = {"raw": resp.text}
        raise HTTPException(
            status_code=500,
            detail={
                "message": "Erreur lors de l'upload de la vidéo rendue dans Supabase Storage.",
                "status_code": resp.status_code,
                "error": body,
            },
        )

    public_url = f"{SUPABASE_URL}/storage/v1/object/public/{bucket}/{object_key}"
    return public_url


@app.post("/render", response_model=RenderResponse)
async def render_video(req: RenderRequest, request: Request) -> RenderResponse:
    auth_header = request.headers.get("authorization") or request.headers.get("Authorization")
    if not auth_header or not auth_header.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Authorization Bearer manquant.")

    token = auth_header.split(" ", 1)[1].strip()
    if STUDIO_VIDEO_RENDER_API_KEY and token != STUDIO_VIDEO_RENDER_API_KEY:
        raise HTTPException(status_code=403, detail="Cl API de rendu vido invalide.")

    video_url = (req.video_url or "").strip()
    if not video_url:
        raise HTTPException(status_code=400, detail="video_url manquant.")

    input_path: Optional[Path] = None
    output_path_default: Optional[Path] = None
    output_path_480p: Optional[Path] = None
    output_path_360p: Optional[Path] = None
    output_path_240p: Optional[Path] = None

    url_default: Optional[str] = None
    url_480p: Optional[str] = None
    url_360p: Optional[str] = None
    url_240p: Optional[str] = None

    try:
        input_path = await _download_video_to_temp(video_url)

        # Génère plusieurs renditions MP4 "ultra-compatibles" pour le Studio :
        # - 480p pour les appareils suffisamment puissants
        # - 360p comme profil par défaut, ciblant les téléphones d'entrée de gamme
        # - 240p comme dernier recours pour les très vieux appareils
        # On conserve également une rendition "source légère" (preset par défaut)
        # afin de disposer d'une qualité supérieure lorsque c'est possible.
        output_path_default = _run_ffmpeg_transcode(input_path)
        output_path_480p = _run_ffmpeg_transcode_480p(input_path)
        output_path_360p = _run_ffmpeg_transcode_360p(input_path)
        output_path_240p = _run_ffmpeg_transcode_240p(input_path)

        if output_path_default is not None:
            url_default = await _upload_to_supabase_storage(output_path_default, req.participation_id)
        if output_path_480p is not None:
            url_480p = await _upload_to_supabase_storage(output_path_480p, req.participation_id)
        if output_path_360p is not None:
            url_360p = await _upload_to_supabase_storage(output_path_360p, req.participation_id)
        if output_path_240p is not None:
            url_240p = await _upload_to_supabase_storage(output_path_240p, req.participation_id)

        # Priorité de lecture par défaut : 360p -> 480p -> source -> 240p
        default_url = (
            (url_360p or "").strip()
            or (url_480p or "").strip()
            or (url_default or "").strip()
            or (url_240p or "").strip()
        )

        if not default_url:
            raise HTTPException(status_code=500, detail="Aucune URL vidéo rendue disponible.")

        video_renditions: Dict[str, str] = {"default": default_url}
        if url_480p:
            video_renditions["480p"] = url_480p
        if url_360p:
            video_renditions["360p"] = url_360p
        if url_240p:
            video_renditions["240p"] = url_240p
        if url_default and url_default != default_url:
            video_renditions["source"] = url_default
    finally:
        try:
            if input_path and input_path.exists():
                input_path.unlink()
        except Exception:
            pass
        try:
            if output_path_default and output_path_default.exists():
                output_path_default.unlink()
        except Exception:
            pass
        try:
            if output_path_480p and output_path_480p.exists():
                output_path_480p.unlink()
        except Exception:
            pass
        try:
            if output_path_360p and output_path_360p.exists():
                output_path_360p.unlink()
        except Exception:
            pass
        try:
            if output_path_240p and output_path_240p.exists():
                output_path_240p.unlink()
        except Exception:
            pass

    return RenderResponse(video_url=default_url, video_renditions=video_renditions)

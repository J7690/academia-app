from pathlib import Path
import os
import uuid
import tempfile
import subprocess
from typing import Any, Dict, Optional

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
    output_path = input_path.with_name(f"rendered_{uuid.uuid4().hex}.mp4")

    cmd = [
        "ffmpeg",
        "-y",
        "-i",
        str(input_path),
        # Limiter la résolution pour rester dans les capacités des décodeurs
        # mobiles (max ~1280px de large).
        "-vf",
        "scale='if(gt(iw,1280),1280,iw)':-2",
        "-c:v",
        "libx264",
        # Forcer un profil/level largement supporté par Android.
        "-profile:v",
        "baseline",
        "-level:v",
        "3.0",
        # Désactiver explicitement les options High Profile pour éviter que
        # le fichier sorte en High (avc1.64...) sur certains ffmpeg/x264.
        "-x264-params",
        "ref=1:bframes=0:cabac=0:deblock=0:weightp=0:no-scenecut=1:level=30",
        "-g",
        "60",
        "-keyint_min",
        "60",
        "-sc_threshold",
        "0",
        "-bf",
        "0",
        "-refs",
        "1",
        "-preset",
        "veryfast",
        "-crf",
        "23",
        # Format de pixels universellement supporté.
        "-pix_fmt",
        "yuv420p",
        "-c:a",
        "aac",
        "-b:a",
        "128k",
        "-movflags",
        "+faststart",
        str(output_path),
    ]

    try:
        result = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
    except FileNotFoundError:
        raise HTTPException(
            status_code=500,
            detail="ffmpeg introuvable sur le serveur de rendu vidéo.",
        )

    if result.returncode != 0:
        stderr_text = result.stderr.decode(errors="ignore")
        raise HTTPException(
            status_code=500,
            detail=f"Erreur ffmpeg lors du rendu vidéo ({result.returncode}). {stderr_text[:500]}",
        )

    return output_path


def _run_ffmpeg_transcode_480p(input_path: Path) -> Path:
    output_path = input_path.with_name(f"rendered_480p_{uuid.uuid4().hex}.mp4")

    cmd = [
        "ffmpeg",
        "-y",
        "-i",
        str(input_path),
        "-vf",
        "scale='if(gt(iw,360),360,iw)':-2",
        "-c:v",
        "libx264",
        "-profile:v",
        "baseline",
        "-level:v",
        "3.0",
        "-x264-params",
        "ref=1:bframes=0:cabac=0:deblock=0:weightp=0:no-scenecut=1:level=30",
        "-g",
        "60",
        "-keyint_min",
        "60",
        "-sc_threshold",
        "0",
        "-bf",
        "0",
        "-refs",
        "1",
        "-preset",
        "veryfast",
        "-crf",
        "23",
        "-maxrate",
        "800k",
        "-bufsize",
        "1600k",
        "-pix_fmt",
        "yuv420p",
        "-c:a",
        "aac",
        "-b:a",
        "128k",
        "-movflags",
        "+faststart",
        str(output_path),
    ]

    try:
        result = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
    except FileNotFoundError:
        raise HTTPException(
            status_code=500,
            detail="ffmpeg introuvable sur le serveur de rendu vidéo.",
        )

    if result.returncode != 0:
        stderr_text = result.stderr.decode(errors="ignore")
        raise HTTPException(
            status_code=500,
            detail=f"Erreur ffmpeg lors du rendu vidéo 480p ({result.returncode}). {stderr_text[:500]}",
        )

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

    try:
        input_path = await _download_video_to_temp(video_url)
        output_path_default = _run_ffmpeg_transcode(input_path)
        output_path_480p = _run_ffmpeg_transcode_480p(input_path)
        url_default = await _upload_to_supabase_storage(output_path_default, req.participation_id)
        url_480p = await _upload_to_supabase_storage(output_path_480p, req.participation_id)
        default_url = url_480p or url_default
        if not default_url:
            raise HTTPException(status_code=500, detail="Aucune URL vidéo rendue disponible.")
        video_renditions: Dict[str, str] = {"default": default_url}
        if url_480p:
            video_renditions["480p"] = url_480p
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

    return RenderResponse(video_url=default_url, video_renditions=video_renditions)

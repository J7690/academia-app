from pathlib import Path
import os
from typing import Any, Dict

from fastapi import FastAPI, HTTPException, Request
from pydantic import BaseModel
from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent
load_dotenv(BASE_DIR / ".env")

STUDIO_VIDEO_RENDER_API_KEY = os.getenv("STUDIO_VIDEO_RENDER_API_KEY")


class RenderRequest(BaseModel):
    video_url: str
    overlays: Dict[str, Any] = {}
    participation_id: str


class RenderResponse(BaseModel):
    video_url: str


app = FastAPI(title="Academia Studio Video Renderer")


@app.post("/render", response_model=RenderResponse)
async def render_video(req: RenderRequest, request: Request) -> RenderResponse:
    auth_header = request.headers.get("authorization") or request.headers.get("Authorization")
    if not auth_header or not auth_header.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Authorization Bearer manquant.")

    token = auth_header.split(" ", 1)[1].strip()
    if STUDIO_VIDEO_RENDER_API_KEY and token != STUDIO_VIDEO_RENDER_API_KEY:
        raise HTTPException(status_code=403, detail="Cl API de rendu vido invalide.")

    url = (req.video_url or "").strip()
    if not url:
        raise HTTPException(status_code=400, detail="video_url manquant.")

    return RenderResponse(video_url=url)

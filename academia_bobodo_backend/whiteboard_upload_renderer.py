"""
Whiteboard Upload Renderer - Phase C.3
Upload de MP4 vers Supabase Storage
Basé sur le pattern de videoasset_worker.py
"""

from pathlib import Path
from typing import Optional
import os
import uuid

import httpx
from dotenv import load_dotenv

# Configuration
load_dotenv()

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_KEY = os.getenv("SUPABASE_SERVICE_KEY")
WHITEBOARD_BUCKET = "whiteboard-renders"

SUPABASE_HTTP_TIMEOUT = 600.0


def _storage_base() -> str:
    return f"{SUPABASE_URL.rstrip('/')}/storage/v1"


def _supabase_headers(extra: Optional[dict] = None) -> dict:
    headers = {
        "apikey": SUPABASE_SERVICE_KEY,
        "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
        "Content-Type": "video/mp4",
    }
    if extra:
        headers.update(extra)
    return headers


async def upload_mp4_to_storage(mp4_path: Path, render_id: str) -> str:
    """
    Upload un MP4 vers Supabase Storage
    
    Args:
        mp4_path: Chemin du MP4
        render_id: ID du rendu
        
    Returns:
        URL publique du MP4
    """
    if not mp4_path.exists():
        raise FileNotFoundError(f"MP4 not found: {mp4_path}")
    
    # Générer un nom de fichier unique
    object_key = f"renders/{render_id}/{uuid.uuid4().hex}.mp4"
    
    # Construire l'URL d'upload
    storage_url = f"{_storage_base()}/object/{WHITEBOARD_BUCKET}/{object_key}"
    
    # Lire le fichier
    data = mp4_path.read_bytes()
    
    # Uploader
    async with httpx.AsyncClient(timeout=SUPABASE_HTTP_TIMEOUT) as client:
        resp = await client.put(
            storage_url,
            headers=_supabase_headers(),
            content=data,
        )
    
    resp.raise_for_status()
    
    # Construire l'URL publique
    public_url = f"{SUPABASE_URL}/storage/v1/object/public/{WHITEBOARD_BUCKET}/{object_key}"
    
    return public_url

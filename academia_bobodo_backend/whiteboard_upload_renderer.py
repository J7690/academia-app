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


BASE_DIR = Path(__file__).resolve().parent
load_dotenv(BASE_DIR / ".env", override=True)

SUPABASE_URL = (os.getenv("SUPABASE_URL") or "").rstrip("/")
SUPABASE_SERVICE_KEY = os.getenv("SUPABASE_SERVICE_KEY") or ""
SUPABASE_PROXY_URL = (os.getenv("SUPABASE_PROXY_URL") or "").rstrip("/")
WHITEBOARD_BUCKET = "whiteboard-renders"

SUPABASE_HTTP_TIMEOUT = 600.0


def _storage_base() -> str:
    if SUPABASE_PROXY_URL:
        return f"{SUPABASE_PROXY_URL}/supabase/storage/v1"
    return f"{SUPABASE_URL}/storage/v1"


def _supabase_headers(extra: Optional[dict] = None) -> dict:
    headers = {
        "apikey": SUPABASE_SERVICE_KEY,
        "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
        "Content-Type": "video/mp4",
    }
    if extra:
        headers.update(extra)
    return headers


def preview_object_key(render_id: str) -> str:
    """
    Chemin CONVENU de l'aperçu d'un rendu, dans le bucket public.

    Ce chemin est un CONTRAT partagé avec l'application : elle le reconstruit
    elle-même et l'interroge pendant que la vidéo se fabrique (voir
    `SmartWhiteboardRenderService.previewUrlFor`). Le faire ainsi évite d'ajouter une
    colonne en base et de modifier `whiteboard_get_render_status` — donc aucun risque
    sur le schéma. En contrepartie, ce nom NE DOIT PAS changer d'un côté sans l'autre.
    """
    return f"renders/{render_id}/preview.mp4"


def upload_preview_sync(mp4_path: Path, render_id: str) -> str:
    """
    Envoie l'APERÇU (les premières secondes du cours, sonorisées) vers le bucket.

    Version synchrone à dessein : elle est appelée depuis le fil d'exécution qui vient
    de terminer la première tranche de capture, pendant que les autres tranches sont
    encore en cours. L'étudiant peut ainsi commencer à regarder son cours bien avant
    que la vidéo complète n'existe.

    `x-upsert` : un rendu relancé écrase son aperçu précédent.
    """
    if not mp4_path.exists():
        raise FileNotFoundError(f"apercu introuvable : {mp4_path}")

    object_key = preview_object_key(render_id)
    storage_url = f"{_storage_base()}/object/{WHITEBOARD_BUCKET}/{object_key}"

    with httpx.Client(timeout=SUPABASE_HTTP_TIMEOUT) as client:
        resp = client.put(
            storage_url,
            headers=_supabase_headers({"x-upsert": "true"}),
            content=mp4_path.read_bytes(),
        )
    resp.raise_for_status()

    return f"{SUPABASE_URL}/storage/v1/object/public/{WHITEBOARD_BUCKET}/{object_key}"


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

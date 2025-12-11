import os
from pathlib import Path
from typing import Any, Dict, List, Optional
from datetime import datetime, timezone
import subprocess
import tempfile
import json
import time

from fastapi import FastAPI, HTTPException, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import httpx
from dotenv import load_dotenv
from livekit import api as livekit_api
from studio_video_renderer import (
    _download_video_to_temp,
    _run_ffmpeg_transcode,
    _run_ffmpeg_transcode_480p,
    _run_ffmpeg_transcode_360p,
    _run_ffmpeg_transcode_240p,
    _upload_to_supabase_storage,
    _run_ffmpeg_generic,
)

BASE_DIR = Path(__file__).resolve().parent
load_dotenv(BASE_DIR / ".env")

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_KEY = os.getenv("SUPABASE_SERVICE_KEY")
OPENROUTER_API_KEY = os.getenv("OPENROUTER_API_KEY")
OPENROUTER_MODEL = os.getenv("OPENROUTER_MODEL", "meta-llama/Meta-Llama-3.1-70B-Instruct")
WEBSEARCH_API_KEY = os.getenv("WEBSEARCH_API_KEY")
WEBSEARCH_ENGINE = os.getenv("WEBSEARCH_ENGINE")

STUDIO_ASR_URL = os.getenv("STUDIO_ASR_URL")
STUDIO_ASR_API_KEY = os.getenv("STUDIO_ASR_API_KEY")

STUDIO_AUDIO_MIX_URL = os.getenv("STUDIO_AUDIO_MIX_URL")
STUDIO_AUDIO_MIX_API_KEY = os.getenv("STUDIO_AUDIO_MIX_API_KEY")

STUDIO_VIDEO_RENDER_URL = os.getenv("STUDIO_VIDEO_RENDER_URL")
STUDIO_VIDEO_RENDER_API_KEY = os.getenv("STUDIO_VIDEO_RENDER_API_KEY")

LIVEKIT_HOST = os.getenv("LIVEKIT_HOST")
LIVEKIT_API_KEY = os.getenv("LIVEKIT_API_KEY")
LIVEKIT_API_SECRET = os.getenv("LIVEKIT_API_SECRET")

LIVEKIT_SERVER_URL = None
if LIVEKIT_HOST:
    if LIVEKIT_HOST.startswith("wss://"):
        LIVEKIT_SERVER_URL = "https://" + LIVEKIT_HOST[len("wss://") :]
    elif LIVEKIT_HOST.startswith("ws://"):
        LIVEKIT_SERVER_URL = "http://" + LIVEKIT_HOST[len("ws://") :]
    else:
        LIVEKIT_SERVER_URL = LIVEKIT_HOST

NO_ANSWER_SENTINEL = "__BOBODO_NO_ANSWER__"

SENSITIVE_KEYWORDS = [
    "terrorisme",
    "terrorist",
    "bombe",
    "bomb",
    "explosif",
    "explosive",
    "attentat",
    "attacks",
    "djihad",
    "jihad",
    "radicalisation",
    "radicalization",
    "armes",
    "weapons",
    "arme à feu",
    "gun",
    "piratage",
    "hacking",
    "hack",
    "pirate informatique",
    "ddos",
    "ransomware",
    "malware",
    "virus informatique",
    "sécurité nationale",
    "national security",
    "espionnage",
    "espionage",
    "cyberattaque",
    "cyberattack",
    "politique",
    "politics",
    "élections",
    "election",
    "activisme social",
    "social activism",
    "manifestation violente",
    "violent protest",
]


CATEGORY_SMALL_TALK_EMOTION = "SMALL_TALK_EMOTION"
CATEGORY_NEXIOM_ACADEMIA_INTERNE = "NEXIOM_ACADEMIA_INTERNE"
CATEGORY_ORIENTATION_ETUDES_EMPLOI = "ORIENTATION_ETUDES_EMPLOI"
CATEGORY_PARTENAIRE_UNIVERSITE_DETAILLEE = "PARTENAIRE_UNIVERSITE_DETAILLEE"
CATEGORY_AUTRE_UNIVERSITE_OU_ENTREPRISE = "AUTRE_UNIVERSITE_OU_ENTREPRISE"
CATEGORY_HORS_SCOPE = "HORS_SCOPE"

VALID_CATEGORIES = {
    CATEGORY_SMALL_TALK_EMOTION,
    CATEGORY_NEXIOM_ACADEMIA_INTERNE,
    CATEGORY_ORIENTATION_ETUDES_EMPLOI,
    CATEGORY_PARTENAIRE_UNIVERSITE_DETAILLEE,
    CATEGORY_AUTRE_UNIVERSITE_OU_ENTREPRISE,
    CATEGORY_HORS_SCOPE,
}


if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
    raise RuntimeError("SUPABASE_URL et SUPABASE_SERVICE_KEY doivent être définies dans le fichier .env")

app = FastAPI(
    title="Academia Bobodo Backend",
    description="Backend FastAPI pour l'assistant Bobodo (Supabase + OpenRouter + websearch)",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/debug/ffmpeg")
async def debug_ffmpeg() -> Dict[str, Any]:
    """Endpoint de diagnostic pour vérifier la présence de ffmpeg dans le conteneur.

    - Retourne ok=False si ffmpeg n'est pas trouvé dans le PATH.
    - Sinon, retourne le code de retour et les premières lignes de stdout/stderr.
    """

    try:
        result = subprocess.run(
            ["ffmpeg", "-version"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
    except FileNotFoundError:
        return {"ok": False, "error": "ffmpeg not found in PATH"}

    stdout_head = result.stdout.decode(errors="ignore").splitlines()[:3]
    stderr_head = result.stderr.decode(errors="ignore").splitlines()[:3]

    return {
        "ok": result.returncode == 0,
        "returncode": result.returncode,
        "stdout_head": stdout_head,
        "stderr_head": stderr_head,
    }


@app.api_route("/supabase/{full_path:path}", methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"])
async def supabase_proxy(full_path: str, request: Request) -> Response:
    """
    Proxy HTTP générique vers l'API Supabase pour contourner les problèmes de résolution DNS côté client.

    Toutes les requêtes envoyées par les applications vers /supabase/... sont relayées vers
    SUPABASE_URL/... avec les bons en-têtes d'authentification.
    """
    if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
        raise HTTPException(
            status_code=500,
            detail="SUPABASE_URL ou SUPABASE_SERVICE_KEY non configurée côté backend.",
        )

    supabase_base = SUPABASE_URL.rstrip("/")
    target_url = f"{supabase_base}/{full_path}"
    query = request.url.query
    if query:
        target_url = f"{target_url}?{query}"

    # Construction d'en-têtes propres pour l'appel vers Supabase.
    # On ne relaie pas les en-têtes spécifiques navigateur (Origin, Sec-*, User-Agent, etc.)
    # pour éviter les 400 HTML côté Cloudflare et limiter les informations exposées.
    #
    # Cas 1: requête authentifiée (header Authorization déjà présent côté client, par exemple
    #        Supabase Flutter). On propage alors le JWT tel quel pour que auth.uid() fonctionne
    #        côté Supabase et que les politiques RLS s'appliquent correctement.
    # Cas 2: requête non authentifiée (pas de header Authorization). On utilise la service_role
    #        key pour les appels système internes ou les endpoints publics côté backend.
    incoming_auth = request.headers.get("authorization")
    incoming_apikey = request.headers.get("apikey")

    outgoing_headers: Dict[str, str] = {}

    if incoming_auth:
        # Mode utilisateur: on garde le JWT du client.
        outgoing_headers["Authorization"] = incoming_auth
        # On propage l'apikey du client (clé anon publique) si elle est présente.
        if incoming_apikey:
            outgoing_headers["apikey"] = incoming_apikey
        else:
            outgoing_headers["apikey"] = SUPABASE_SERVICE_KEY
    else:
        # Mode service: appels internes ou publics sans JWT.
        outgoing_headers["apikey"] = SUPABASE_SERVICE_KEY
        outgoing_headers["Authorization"] = f"Bearer {SUPABASE_SERVICE_KEY}"

    content_type = request.headers.get("content-type")
    if content_type:
        outgoing_headers["content-type"] = content_type

    accept = request.headers.get("accept")
    if accept:
        outgoing_headers["accept"] = accept

    range_header = request.headers.get("range")
    if range_header:
        outgoing_headers["range"] = range_header

    body = await request.body()

    async with httpx.AsyncClient(timeout=30.0) as client:
        try:
            upstream_response = await client.request(
                request.method,
                target_url,
                headers=outgoing_headers,
                content=body if request.method.upper() != "GET" else None,
            )
        except httpx.HTTPError as exc:
            # Log détaillé pour les erreurs de proxy Supabase (visible dans les logs Railway)
            print(
                f"[SUPABASE_PROXY_ERROR] method={request.method} "
                f"full_path={full_path} target={target_url} error={repr(exc)}"
            )
            raise HTTPException(
                status_code=502,
                detail={"message": "Erreur réseau Supabase (proxy)", "error": str(exc)},
            )

    # Filtrer certains en-têtes de réponse problématiques pour FastAPI
    excluded_headers = {"content-encoding", "transfer-encoding", "connection"}
    response_headers = {
        k: v for k, v in upstream_response.headers.items() if k.lower() not in excluded_headers
    }

    return Response(
        content=upstream_response.content,
        status_code=upstream_response.status_code,
        headers=response_headers,
        media_type=upstream_response.headers.get("content-type"),
    )



class BobodoChatRequest(BaseModel):
    session_id: Optional[str]
    message: str


class BobodoChatResponse(BaseModel):
    session_id: str
    assistant_message: str


class StudioTranscriptionRequest(BaseModel):
    participation_id: Optional[str] = None
    free_video_id: Optional[str] = None
    video_type: Optional[str] = "challenge"
    language: Optional[str] = None


class StudioTranscriptionResponse(BaseModel):
    success: bool
    participation_id: str
    subtitles: List[Dict[str, Any]]
    overlays: Dict[str, Any]
    video_type: Optional[str] = "challenge"
    free_video_id: Optional[str] = None


class StudioAnalyzeRequest(BaseModel):
    participation_id: Optional[str] = None
    free_video_id: Optional[str] = None
    video_type: Optional[str] = "challenge"


class StudioAnalyzeResponse(BaseModel):
    success: bool
    participation_id: str
    analysis: str
    video_type: Optional[str] = "challenge"
    free_video_id: Optional[str] = None


class StudioProofreadRequest(BaseModel):
    text: str


class StudioProofreadResponse(BaseModel):
    success: bool
    text: str


class StudioAudioTrackSpec(BaseModel):
    asset_url: str
    start_ms: Optional[int] = None
    end_ms: Optional[int] = None
    volume_db: Optional[float] = None
    kind: Optional[str] = None


class StudioAudioRenderRequest(BaseModel):
    participation_id: Optional[str] = None
    free_video_id: Optional[str] = None
    video_type: Optional[str] = "challenge"
    tracks: List[StudioAudioTrackSpec]
    normalize: Optional[bool] = True


class StudioAudioRenderResponse(BaseModel):
    success: bool
    participation_id: str
    video_url: str
    added_video_id: Optional[str] = None
    video_type: Optional[str] = "challenge"
    free_video_id: Optional[str] = None


class StudioVideoRenderRequest(BaseModel):
    participation_id: Optional[str] = None
    free_video_id: Optional[str] = None
    video_type: Optional[str] = "challenge"


class StudioVideoRenderResponse(BaseModel):
    success: bool
    participation_id: str
    video_url: str
    added_video_id: Optional[str] = None
    video_type: Optional[str] = "challenge"
    free_video_id: Optional[str] = None


class HeroStudioRenderRequest(BaseModel):
    playlist_item_id: str
    slot: Optional[str] = None


class HeroStudioRenderResponse(BaseModel):
    success: bool
    playlist_item_id: str
    render_id: str
    render_url: str
    thumbnail_url: str
    status: str


class TvStudioRenderRequest(BaseModel):
    playlist_item_id: str
    slot: Optional[str] = None
    meta: Optional[Dict[str, Any]] = None


class TvStudioRenderResponse(BaseModel):
    success: bool
    playlist_item_id: str
    render_id: str
    render_url: str
    thumbnail_url: str
    status: str


class VideoPlaybackErrorIn(BaseModel):
    device_model: Optional[str] = None
    platform: Optional[str] = None
    os_version: Optional[str] = None
    app_version: Optional[str] = None
    video_url: str
    rendition_key: Optional[str] = None
    error_message: str
    raw_error: Optional[Dict[str, Any]] = None


async def call_supabase_rpc(function: str, payload: Dict[str, Any]) -> Any:
    """Appelle une fonction RPC Supabase via l'API REST avec la service_role key."""
    url = f"{SUPABASE_URL}/rest/v1/rpc/{function}"
    headers = {
        "apikey": SUPABASE_SERVICE_KEY,
        "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
        "Content-Type": "application/json",
        "Accept": "application/json",
    }

    async with httpx.AsyncClient(timeout=30.0) as client:
        try:
            response = await client.post(url, headers=headers, json=payload)
        except httpx.HTTPError as exc:
            raise HTTPException(
                status_code=502,
                detail={"message": "Erreur réseau Supabase", "error": str(exc)},
            )

    if response.status_code >= 400:
        try:
            error_body = response.json()
        except ValueError:
            error_body = {"raw": response.text}
        raise HTTPException(
            status_code=500,
            detail={
                "message": "Erreur RPC Supabase",
                "rpc": function,
                "status_code": response.status_code,
                "error": error_body,
            },
        )

    if not response.content:
        return None

    try:
        return response.json()
    except ValueError:
        return response.text


async def call_supabase_rpc_as_user(jwt: str, function: str, payload: Dict[str, Any]) -> Any:
    """Appelle une RPC Supabase avec le JWT de l'utilisateur pour que auth.uid() reflète bien l'utilisateur courant.

    On utilise la service_role key comme apikey projet, mais le contexte d'authentification
    est celui du JWT passé en Authorization.
    """
    if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
        raise HTTPException(
            status_code=500,
            detail="SUPABASE_URL ou SUPABASE_SERVICE_KEY non configurée côté backend.",
        )

    url = f"{SUPABASE_URL}/rest/v1/rpc/{function}"
    headers = {
        "apikey": SUPABASE_SERVICE_KEY,
        "Authorization": f"Bearer {jwt}",
        "Content-Type": "application/json",
        "Accept": "application/json",
    }

    async with httpx.AsyncClient(timeout=30.0) as client:
        try:
            response = await client.post(url, headers=headers, json=payload)
        except httpx.HTTPError as exc:
            raise HTTPException(
                status_code=502,
                detail={"message": "Erreur réseau Supabase", "error": str(exc)},
            )

    if response.status_code >= 400:
        try:
            error_body = response.json()
        except ValueError:
            error_body = {"raw": response.text}
        raise HTTPException(
            status_code=500,
            detail={
                "message": "Erreur RPC Supabase (user)",
                "rpc": function,
                "status_code": response.status_code,
                "error": error_body,
            },
        )

    if not response.content:
        return None

    try:
        return response.json()
    except ValueError:
        return response.text


class LivekitTokenRequest(BaseModel):
    session_id: str


class LivekitTokenResponse(BaseModel):
    token: str
    host: str
    room_name: str
    identity: str
    role: str


@app.post("/livekit/token", response_model=LivekitTokenResponse)
async def get_livekit_token(req: LivekitTokenRequest, request: Request) -> LivekitTokenResponse:
    """Génère un token LiveKit pour une session live donnée.

    - Vérifie le JWT Supabase de l'appelant (Authorization: Bearer ...).
    - Demande à Supabase (RPC) d'enregistrer/valider le participant pour la session.
    - Génère un JWT LiveKit avec les clés LIVEKIT_API_KEY / LIVEKIT_API_SECRET.
    """

    if not LIVEKIT_API_KEY or not LIVEKIT_API_SECRET or not LIVEKIT_HOST:
        raise HTTPException(
            status_code=500,
            detail="LIVEKIT_HOST, LIVEKIT_API_KEY ou LIVEKIT_API_SECRET non configurés côté backend.",
        )

    auth_header = request.headers.get("authorization") or request.headers.get("Authorization")
    if not auth_header or not auth_header.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Authorization Bearer manquant pour LiveKit.")

    user_jwt = auth_header.split(" ", 1)[1].strip()
    if not user_jwt:
        raise HTTPException(status_code=401, detail="JWT utilisateur invalide pour LiveKit.")

    data = await call_supabase_rpc_as_user(
        user_jwt,
        "app_register_online_course_live_session_participant",
        {"p_session_id": req.session_id},
    )

    if not isinstance(data, dict) or not data.get("success"):
        # On normalise un message d'erreur compréhensible côté client
        error_code = None
        if isinstance(data, dict):
            error_code = data.get("error")
        raise HTTPException(
            status_code=403,
            detail={
                "message": "Accès refusé pour cette session live",
                "error": error_code or "unknown_error",
            },
        )

    room_name = str(data.get("livekit_room_name") or "").strip()
    identity = str(data.get("identity") or "").strip()
    role = str(data.get("role") or "").strip()

    if not room_name or not identity:
        raise HTTPException(
            status_code=500,
            detail="Réponse Supabase invalide pour la session live (room_name/identity manquants).",
        )

    token = (
        livekit_api.AccessToken(LIVEKIT_API_KEY, LIVEKIT_API_SECRET)
        .with_identity(identity)
        .with_grants(
            livekit_api.VideoGrants(
                room_join=True,
                room=room_name,
            )
        )
    )

    return LivekitTokenResponse(
        token=token.to_jwt(),
        host=LIVEKIT_HOST,
        room_name=room_name,
        identity=identity,
        role=role,
    )


class LivekitAdminKickRequest(BaseModel):
  session_id: str
  user_id: str


class LivekitAdminKickResponse(BaseModel):
  success: bool
  kicked: bool


@app.post("/livekit/admin/kick", response_model=LivekitAdminKickResponse)
async def livekit_admin_kick(req: LivekitAdminKickRequest, request: Request) -> LivekitAdminKickResponse:
  """Bannit un participant via Supabase puis le retire de la room LiveKit si possible.

  - Vérifie le JWT admin Supabase.
  - Appelle app_admin_ban_user_from_online_course_live_session.
  - Récupère room_name / identity via app_admin_get_live_session_participant_livekit_identity.
  - Appelle RoomService.RemoveParticipant si les infos sont disponibles.
  """

  if not LIVEKIT_API_KEY or not LIVEKIT_API_SECRET or not LIVEKIT_SERVER_URL:
    raise HTTPException(
      status_code=500,
      detail="LIVEKIT_HOST/URL, LIVEKIT_API_KEY ou LIVEKIT_API_SECRET non configurés côté backend.",
    )

  auth_header = request.headers.get("authorization") or request.headers.get("Authorization")
  if not auth_header or not auth_header.lower().startswith("bearer "):
    raise HTTPException(status_code=401, detail="Authorization Bearer manquant pour LiveKit admin.")

  admin_jwt = auth_header.split(" ", 1)[1].strip()
  if not admin_jwt:
    raise HTTPException(status_code=401, detail="JWT admin invalide pour LiveKit.")

  # 1) Bannissement via RPC admin (contexte admin, audit Supabase)
  ban_data = await call_supabase_rpc_as_user(
    admin_jwt,
    "app_admin_ban_user_from_online_course_live_session",
    {"p_session_id": req.session_id, "p_user_id": req.user_id},
  )

  if not isinstance(ban_data, dict) or not ban_data.get("success"):
    error_code = None
    if isinstance(ban_data, dict):
      error_code = ban_data.get("error")
    raise HTTPException(
      status_code=403,
      detail={
        "message": "Bannissement impossible pour cette session live",
        "error": error_code or "unknown_error",
      },
    )

  # 2) Récupération des infos LiveKit (room_name, identity)
  ident_data = await call_supabase_rpc_as_user(
    admin_jwt,
    "app_admin_get_live_session_participant_livekit_identity",
    {"p_session_id": req.session_id, "p_user_id": req.user_id},
  )

  if not isinstance(ident_data, dict) or not ident_data.get("success"):
    # Bannissement OK mais pas d'info LiveKit exploitable
    return LivekitAdminKickResponse(success=True, kicked=False)

  room_name = str(ident_data.get("livekit_room_name") or "").strip()
  identity = str(ident_data.get("identity") or "").strip()

  if not room_name or not identity:
    return LivekitAdminKickResponse(success=True, kicked=False)

  # 3) Suppression du participant côté LiveKit (ne bloque pas le succès du ban si échec)
  try:
    lkapi = livekit_api.LiveKitAPI(
      url=LIVEKIT_SERVER_URL,
      api_key=LIVEKIT_API_KEY,
      api_secret=LIVEKIT_API_SECRET,
    )
    await lkapi.room.remove_participant(
      livekit_api.room.RoomParticipantIdentity(room=room_name, identity=identity)
    )
    return LivekitAdminKickResponse(success=True, kicked=True)
  except Exception:
    # En cas d'erreur LiveKit, on considère le ban DB comme effectif
    return LivekitAdminKickResponse(success=True, kicked=False)


async def get_student_first_name(session_id: str) -> Optional[str]:
    """Récupère le prénom de l'étudiant lié à une session Bobodo via une RPC Supabase.

    Utilise la fonction app_get_bobodo_student_first_name (schéma app).
    """
    if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
        return None

    try:
        data = await call_supabase_rpc(
            "app_get_bobodo_student_first_name",
            {"p_session_id": session_id},
        )
    except HTTPException:
        return None

    # Pour une fonction TEXT simple, Supabase renvoie généralement une chaîne JSON
    if isinstance(data, str):
        first = data.strip()
        return first or None

    if isinstance(data, dict) and isinstance(data.get("result"), str):
        first = data["result"].strip()
        return first or None

    return None


async def has_bobodo_assistant_message(session_id: str) -> bool:
    """
    Indique s'il existe déjà au moins un message de l'assistant Bobodo
    pour une session donnée, via la RPC app_has_bobodo_assistant_message.
    """
    if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
        return False

    try:
        data = await call_supabase_rpc(
            "app_has_bobodo_assistant_message",
            {"p_session_id": session_id},
        )
    except HTTPException:
        return False

    # Supabase peut renvoyer un booléen brut ou un dict avec un champ result
    if isinstance(data, bool):
        return data
    if isinstance(data, dict) and isinstance(data.get("result"), bool):
        return data["result"]

    return False


async def get_challenge_video_for_user(jwt: str, participation_id: str) -> Dict[str, Any]:
    data = await call_supabase_rpc_as_user(
        jwt,
        "app_student_get_challenge_video",
        {"p_participation_id": participation_id},
    )

    if not isinstance(data, dict) or not data.get("success"):
        error_code = None
        if isinstance(data, dict):
            error_code = data.get("error")
        raise HTTPException(
            status_code=403,
            detail={
                "message": "Accs refus pour cette vido de challenge",
                "error": error_code or "unknown_error",
            },
        )

    video = data.get("video")
    if not isinstance(video, dict):
        raise HTTPException(
            status_code=500,
            detail={"message": "Rponse Supabase invalide pour la vido de challenge."},
        )

    return video


async def get_free_video_for_user(jwt: str, free_video_id: str) -> Dict[str, Any]:
    data = await call_supabase_rpc_as_user(
        jwt,
        "app_student_get_free_video",
        {"p_free_video_id": free_video_id},
    )

    if not isinstance(data, dict) or not data.get("success"):
        error_code = None
        if isinstance(data, dict):
            error_code = data.get("error")
        raise HTTPException(
            status_code=403,
            detail={
                "message": "Accès refusé pour cette vidéo libre",
                "error": error_code or "unknown_error",
            },
        )

    video = data.get("video")
    if not isinstance(video, dict):
        raise HTTPException(
            status_code=500,
            detail={"message": "Réponse Supabase invalide pour la vidéo libre."},
        )

    return video


def is_sensitive_query(message: str) -> bool:
    text = message.lower()
    for keyword in SENSITIVE_KEYWORDS:
        if keyword in text:
            return True
    return False


def should_append_admin_contact_hint(message: str) -> bool:
    """Détecte les questions où l'utilisateur ne trouve pas une formation sur Academia.

    Cela permet d'ajouter systématiquement un rappel clair d'écrire à
    l'administrateur de la plateforme Academia dans ces cas.
    """
    text = message.lower()
    if "formation" not in text:
        return False

    trigger_phrases = (
        "je ne la trouve pas",
        "je ne trouve pas",
        "je ne vois pas",
        "je ne la vois pas",
        "je ne vois pas de formation",
        "je ne trouve pas de formation",
        "n'est pas dans la liste",
        "n est pas dans la liste",
        "n'est pas dans vos offres",
        "n est pas dans vos offres",
        "n'apparait pas",
        "n apparait pas",
        "n'apparaît pas",
        "n apparait pas",
        "ne figure pas",
        "ne figure pas dans la liste",
    )
    if any(phrase in text for phrase in trigger_phrases):
        return True

    if "liste" in text and ("ne" in text or "n'" in text):
        if any(
            keyword in text
            for keyword in ("vois", "voir", "trouve", "trouver", "figure", "apparait", "apparaît")
        ):
            return True

    return False


async def search_knowledge(query: str) -> List[Dict[str, Any]]:
    """Recherche dans la base de connaissances Bobodo via la RPC app_search_bobodo_knowledge."""
    if not query.strip():
        return []

    def _extract_list(raw: Any) -> List[Dict[str, Any]]:
        if isinstance(raw, list):
            return raw
        if isinstance(raw, dict) and "result" in raw and isinstance(raw["result"], list):
            return raw["result"]
        return []

    # 1) Première recherche avec la requête complète
    data = await call_supabase_rpc(
        "app_search_bobodo_knowledge",
        {"p_query": query, "p_category": None},
    )
    knowledge = _extract_list(data)
    if knowledge:
        return knowledge

    # 2) Si aucune connaissance trouvée, on tente des requêtes simplifiées
    lower = query.lower()
    fallback_terms: List[str] = []
    if "nexiom" in lower or "nexium" in lower:
        fallback_terms.append("nexiom")
    if "academia" in lower:
        fallback_terms.append("academia")

    combined: List[Dict[str, Any]] = []
    for term in fallback_terms:
        try:
            data_term = await call_supabase_rpc(
                "app_search_bobodo_knowledge",
                {"p_query": term, "p_category": None},
            )
        except HTTPException:
            continue
        combined.extend(_extract_list(data_term))

    return combined


async def log_unanswered_question(session_id: str, question: str, category: str) -> None:
    if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
        return
    try:
        await call_supabase_rpc(
            "app_log_bobodo_unanswered_question",
            {
                "p_session_id": session_id,
                "p_question_text": question,
                "p_category": category,
            },
        )
    except HTTPException:
        return


async def log_detected_need(session_id: str, question: str, category: str) -> None:
    if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
        return

    # Ne logger que les catégories utiles pour l'analyse des besoins
    if category not in {
        CATEGORY_NEXIOM_ACADEMIA_INTERNE,
        CATEGORY_ORIENTATION_ETUDES_EMPLOI,
        CATEGORY_PARTENAIRE_UNIVERSITE_DETAILLEE,
        CATEGORY_AUTRE_UNIVERSITE_OU_ENTREPRISE,
    }:
        return

    need_summary = question.strip()

    if OPENROUTER_API_KEY:
        need_system_prompt = (
            "Tu es Bobodo, assistant IA pour la plateforme Academia. "
            "On te fournit une question posée par un utilisateur. Ta tâche est de résumer en UNE ou DEUX phrases "
            "le BESOIN principal exprimé, en français simple, sans citer de nom propre ni inclure de données personnelles, "
            "et sans promettre de résultat. Concentre-toi sur le type de formation, d'orientation ou de service recherché."
        )

        try:
            raw_summary = await call_openrouter(
                question,
                [],
                system_prompt=need_system_prompt,
                include_no_answer_sentinel=False,
            )
            cleaned = raw_summary.strip()
            if cleaned:
                need_summary = cleaned[:1000]
        except HTTPException:
            # En cas d'échec OpenRouter, on garde la question brute comme résumé
            pass

    try:
        await call_supabase_rpc(
            "app_log_bobodo_detected_need",
            {
                "p_session_id": session_id,
                "p_question_text": question,
                "p_category": category,
                "p_need_summary": need_summary,
            },
        )
    except HTTPException:
        return


def classify_query_with_rules(message: str) -> str:
    text = message.lower()

    if any(keyword in text for keyword in (
        "bonjour",
        "bonsoir",
        "salut",
        "merci",
        "désolé",
        "desole",
        "excuse",
        "triste",
        "heureux",
        "heureuse",
        "content",
        "contente",
        "stressé",
        "stresse",
        "inquiet",
        "inquiète",
    )):
        return CATEGORY_SMALL_TALK_EMOTION

    if "nexiom" in text or "nexium" in text or "nexion" in text or "academia" in text:
        return CATEGORY_NEXIOM_ACADEMIA_INTERNE

    if any(keyword in text for keyword in (
        "orientation",
        "étude",
        "etude",
        "filière",
        "filiere",
        "métier",
        "metier",
        "emploi",
        "travail",
        "carrière",
        "carriere",
        "cv",
        "lettre de motivation",
        "actuariat",
        "actuaria",
        "actuaire",
    )):
        return CATEGORY_ORIENTATION_ETUDES_EMPLOI

    if any(keyword in text for keyword in (
        "université",
        "universite",
        "centre de formation",
        "école",
        "ecole",
        "lycée",
        "lycee",
        "entreprise",
    )):
        return CATEGORY_AUTRE_UNIVERSITE_OU_ENTREPRISE

    return CATEGORY_HORS_SCOPE


async def classify_query_with_openrouter(message: str) -> str:
    if not OPENROUTER_API_KEY:
        return classify_query_with_rules(message)

    classification_system_prompt = (
        "Tu es Bobodo, assistant IA pour la plateforme Academia. "
        "Ta tâche est de COMPRENDRE le sens de la question de l'utilisateur, même si elle est mal formulée, comporte des fautes ou ne contient pas de mots-clés évidents, puis de la CLASSER dans UNE SEULE catégorie parmi la liste suivante:\n"
        f"- {CATEGORY_SMALL_TALK_EMOTION}: salutations, remerciements, compliments, petites discussions, émotions (joie, tristesse, stress, plaintes personnelles).\n"
        f"- {CATEGORY_NEXIOM_ACADEMIA_INTERNE}: questions sur Nexiom Group, Nexiom, la plateforme Academia, ses fonctionnalités, règles, procédures internes, tarifs, politique d'utilisation.\n"
        f"- {CATEGORY_ORIENTATION_ETUDES_EMPLOI}: questions d'orientation, choix d'études, de formation, de métier, d'emploi, d'insertion professionnelle, rédaction de CV ou de lettre de motivation.\n"
        f"- {CATEGORY_PARTENAIRE_UNIVERSITE_DETAILLEE}: question détaillée sur une université ou un centre de formation PARTENAIRE d'Academia (programmes précis, frais exacts, conditions d'admission détaillées, promotions).\n"
        f"- {CATEGORY_AUTRE_UNIVERSITE_OU_ENTREPRISE}: question sur une université ou une entreprise NON partenaire, ou sur la comparaison entre plusieurs établissements ou entreprises.\n"
        f"- {CATEGORY_HORS_SCOPE}: toute autre question qui ne rentre pas dans les catégories précédentes.\n"
        "Réponds STRICTEMENT par l'un de ces codes, sans aucun texte supplémentaire, sans ponctuation, sans explication. "
        f"Si tu hésites entre plusieurs catégories, choisis la plus prudente et utilise {CATEGORY_HORS_SCOPE}."
    )

    try:
        raw_category = await call_openrouter(
            message,
            [],
            system_prompt=classification_system_prompt,
            include_no_answer_sentinel=False,
        )
    except HTTPException:
        return classify_query_with_rules(message)

    category = raw_category.strip().upper()
    # Catégorie proposée par les règles heuristiques (filet de sécurité)
    rules_category = classify_query_with_rules(message)

    # Priorité absolue :
    # - si les règles détectent une question interne Nexiom/Academia
    # - OU une question sur une autre université / entreprise non partenaire
    # alors on suit les règles, même si OpenRouter propose autre chose.
    if rules_category in {
        CATEGORY_NEXIOM_ACADEMIA_INTERNE,
        CATEGORY_AUTRE_UNIVERSITE_OU_ENTREPRISE,
    }:
        return rules_category

    if category in VALID_CATEGORIES:
        return category

    return rules_category


async def perform_web_search(query: str, max_results: int = 5) -> List[Dict[str, Any]]:
    if not query.strip():
        return []
    if not WEBSEARCH_API_KEY or not WEBSEARCH_ENGINE:
        return []

    params = {"q": query, "api_key": WEBSEARCH_API_KEY, "num": max_results}

    async with httpx.AsyncClient(timeout=30.0) as client:
        try:
            response = await client.get(WEBSEARCH_ENGINE, params=params)
        except httpx.HTTPError as exc:
            raise HTTPException(
                status_code=502,
                detail={"message": "Erreur réseau WebSearch", "error": str(exc)},
            )

    if response.status_code >= 400:
        raise HTTPException(
            status_code=500,
            detail={
                "message": "Erreur WebSearch",
                "status_code": response.status_code,
                "error": response.text[:500],
            },
        )

    try:
        data = response.json()
    except ValueError:
        return []

    results_raw = data.get("results") if isinstance(data, dict) else None
    if not isinstance(results_raw, list):
        return []

    results: List[Dict[str, Any]] = []
    for item in results_raw[:max_results]:
        if not isinstance(item, dict):
            continue
        results.append(
            {
                "title": str(item.get("title") or ""),
                "snippet": str(item.get("snippet") or ""),
                "url": str(item.get("url") or ""),
            }
        )
    return results


async def call_studio_asr(video_url: str, language: Optional[str]) -> List[Dict[str, Any]]:
    url = (video_url or "").strip()
    if not url:
        raise HTTPException(status_code=400, detail="video_url manquant pour la transcription.")

    if not STUDIO_ASR_URL or not STUDIO_ASR_API_KEY:
        raise HTTPException(
            status_code=500,
            detail="STUDIO_ASR_URL ou STUDIO_ASR_API_KEY non configur pour la transcription.",
        )

    payload: Dict[str, Any] = {"video_url": url}
    if language:
        payload["language"] = language

    headers = {
        "Authorization": f"Bearer {STUDIO_ASR_API_KEY}",
        "Content-Type": "application/json",
        "Accept": "application/json",
    }

    async with httpx.AsyncClient(timeout=300.0) as client:
        try:
            response = await client.post(STUDIO_ASR_URL, headers=headers, json=payload)
        except httpx.HTTPError as exc:
            raise HTTPException(
                status_code=502,
                detail={"message": "Erreur rseau ASR", "error": str(exc)},
            )

    if response.status_code >= 400:
        try:
            error_body = response.json()
        except ValueError:
            error_body = {"raw": response.text}
        raise HTTPException(
            status_code=500,
            detail={
                "message": "Erreur service ASR",
                "status_code": response.status_code,
                "error": error_body,
            },
        )

    try:
        data = response.json()
    except ValueError:
        raise HTTPException(
            status_code=500,
            detail={"message": "Rponse ASR inattendue", "raw": response.text[:500]},
        )

    segments_raw = data.get("segments")
    segments: List[Dict[str, Any]] = []
    if isinstance(segments_raw, list):
        for item in segments_raw:
            if not isinstance(item, dict):
                continue
            text = str(item.get("text") or "").strip()
            if not text:
                continue
            start_ms_raw = item.get("start_ms")
            end_ms_raw = item.get("end_ms")
            try:
                start_ms = int(start_ms_raw) if start_ms_raw is not None else 0
            except (TypeError, ValueError):
                start_ms = 0
            try:
                end_ms = int(end_ms_raw) if end_ms_raw is not None else 0
            except (TypeError, ValueError):
                end_ms = 0
            segments.append(
                {
                    "text": text,
                    "start_ms": max(start_ms, 0),
                    "end_ms": max(end_ms, 0),
                }
            )

    return segments


async def call_studio_audio_mix(
    video_url: str,
    tracks: List[Dict[str, Any]],
    normalize: Optional[bool],
) -> str:
    url = (video_url or "").strip()
    if not url:
        raise HTTPException(status_code=400, detail={"message": "video_url manquant pour le rendu audio."})

    if not STUDIO_AUDIO_MIX_URL or not STUDIO_AUDIO_MIX_API_KEY:
        raise HTTPException(
            status_code=500,
            detail={
                "message": "STUDIO_AUDIO_MIX_URL ou STUDIO_AUDIO_MIX_API_KEY non configuré pour le rendu audio.",
            },
        )

    if not tracks:
        raise HTTPException(status_code=400, detail={"message": "Aucune piste audio fournie pour le rendu."})

    payload: Dict[str, Any] = {
        "video_url": url,
        "tracks": tracks,
        "options": {"normalize": bool(normalize) if normalize is not None else True},
    }

    headers = {
        "Authorization": f"Bearer {STUDIO_AUDIO_MIX_API_KEY}",
        "Content-Type": "application/json",
        "Accept": "application/json",
    }

    async with httpx.AsyncClient(timeout=600.0) as client:
        try:
            response = await client.post(STUDIO_AUDIO_MIX_URL, headers=headers, json=payload)
        except httpx.HTTPError as exc:
            raise HTTPException(
                status_code=502,
                detail={"message": "Erreur réseau Studio audio", "error": str(exc)},
            )

    if response.status_code >= 400:
        try:
            error_body = response.json()
        except ValueError:
            error_body = {"raw": response.text}
        raise HTTPException(
            status_code=500,
            detail={
                "message": "Erreur service Studio audio",
                "status_code": response.status_code,
                "error": error_body,
            },
        )

    try:
        data = response.json()
    except ValueError:
        raise HTTPException(
            status_code=500,
            detail={"message": "Réponse Studio audio inattendue", "raw": response.text[:500]},
        )

    rendered_url = data.get("video_url")
    if not isinstance(rendered_url, str) or not rendered_url.strip():
        raise HTTPException(
            status_code=500,
            detail={"message": "URL vidéo de rendu manquante dans la réponse Studio audio."},
        )

    return rendered_url.strip()


async def call_studio_video_render(
    video_url: str,
    overlays: Dict[str, Any],
    participation_id: str,
) -> Dict[str, Any]:
    url = (video_url or "").strip()
    if not url:
        raise HTTPException(status_code=400, detail={"message": "video_url manquant pour le rendu vidéo."})

    if not isinstance(overlays, dict):
        overlays = {}

    input_path: Optional[Path] = None
    output_path_default: Optional[Path] = None
    output_path_480p: Optional[Path] = None
    output_path_360p: Optional[Path] = None
    output_path_240p: Optional[Path] = None

    try:
        # 1) Télécharger la vidéo source dans un fichier temporaire
        input_path = await _download_video_to_temp(url)

        # 2) Générer plusieurs renditions pensées pour Android/MediaTek
        output_path_default = _run_ffmpeg_transcode(input_path)
        output_path_480p = _run_ffmpeg_transcode_480p(input_path)
        output_path_360p = _run_ffmpeg_transcode_360p(input_path)
        output_path_240p = _run_ffmpeg_transcode_240p(input_path)

        # 3) Uploader chaque rendition dans Supabase Storage
        url_default = await _upload_to_supabase_storage(output_path_default, participation_id)
        url_480p = await _upload_to_supabase_storage(output_path_480p, participation_id)
        url_360p = await _upload_to_supabase_storage(output_path_360p, participation_id)
        url_240p = await _upload_to_supabase_storage(output_path_240p, participation_id)

        # 4) Choisir une URL "par défaut" raisonnable (480p > 360p > 240p > source)
        default_url = (
            (url_480p or "")
            or (url_360p or "")
            or (url_240p or "")
            or (url_default or "")
        )

        if not default_url:
            raise HTTPException(
                status_code=500,
                detail={"message": "Aucune URL vidéo rendue disponible."},
            )

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
        # Nettoyage des fichiers temporaires, best-effort
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

    return {
        "video_url": default_url,
        "video_renditions": video_renditions,
    }


async def create_render_job(
    *,
    video_type: str,
    participation_id: Optional[str] = None,
    free_video_id: Optional[str] = None,
    job_type: str,
    source_video_url: Optional[str],
    metadata: Optional[Dict[str, Any]] = None,
) -> Optional[str]:
    if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
        return None

    vt = (video_type or "challenge").strip().lower()
    if vt == "free":
        if not free_video_id:
            return None
        table_url = f"{SUPABASE_URL}/rest/v1/app.free_video_render_jobs"
    else:
        if not participation_id:
            return None
        table_url = f"{SUPABASE_URL}/rest/v1/app.challenge_video_render_jobs"
    headers = {
        "apikey": SUPABASE_SERVICE_KEY,
        "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Prefer": "return=representation",
    }

    payload: Dict[str, Any] = {
        "job_type": job_type,
        "status": "running",
    }
    if vt == "free":
        payload["free_video_id"] = free_video_id
    else:
        payload["participation_id"] = participation_id
    if source_video_url:
        payload["source_video_url"] = source_video_url
    if metadata:
        payload["metadata"] = metadata
    payload["started_at"] = datetime.now(timezone.utc).isoformat()

    async with httpx.AsyncClient(timeout=10.0) as client:
        try:
            response = await client.post(table_url, headers=headers, json=payload)
        except httpx.HTTPError:
            return None

    if response.status_code >= 400:
        return None

    try:
        data = response.json()
    except ValueError:
        return None

    if isinstance(data, list) and data and isinstance(data[0], dict):
        job_id_raw = data[0].get("id")
        if isinstance(job_id_raw, str) and job_id_raw.strip():
            return job_id_raw.strip()

    return None


async def update_render_job(
    job_id: Optional[str],
    *,
    video_type: str = "challenge",
    status: Optional[str] = None,
    result_video_url: Optional[str] = None,
    error_message: Optional[str] = None,
) -> None:
    if not job_id:
        return
    if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
        return

    fields: Dict[str, Any] = {}
    if status:
        fields["status"] = status
        if status.lower() == "completed":
            fields["completed_at"] = datetime.now(timezone.utc).isoformat()
    if result_video_url:
        fields["result_video_url"] = result_video_url
    if error_message:
        # Tronquer pour éviter des erreurs sur des messages trop longs
        fields["error_message"] = error_message[:2000]

    if not fields:
        return

    vt = (video_type or "challenge").strip().lower()
    if vt == "free":
        table_url = f"{SUPABASE_URL}/rest/v1/app.free_video_render_jobs?id=eq.{job_id}"
    else:
        table_url = f"{SUPABASE_URL}/rest/v1/app.challenge_video_render_jobs?id=eq.{job_id}"
    headers = {
        "apikey": SUPABASE_SERVICE_KEY,
        "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
        "Content-Type": "application/json",
        "Accept": "application/json",
    }

    async with httpx.AsyncClient(timeout=10.0) as client:
        try:
            await client.patch(table_url, headers=headers, json=fields)
        except httpx.HTTPError:
            return


async def update_tv_render_record(
    render_id: Optional[str],
    *,
    status: Optional[str] = None,
    render_url: Optional[str] = None,
    thumbnail_url: Optional[str] = None,
    error_message: Optional[str] = None,
    set_started_at: bool = False,
    set_finished_at: bool = False,
) -> None:
    if not render_id:
        return
    if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
        return

    fields: Dict[str, Any] = {}
    if status:
        fields["status"] = status
    if render_url:
        fields["render_url"] = render_url
    if thumbnail_url:
        fields["thumbnail_url"] = thumbnail_url
    if error_message:
        fields["error_message"] = error_message[:4000]

    if set_started_at or set_finished_at:
        now_iso = datetime.now(timezone.utc).isoformat()
        if set_started_at:
            fields["started_at"] = now_iso
        if set_finished_at:
            fields["finished_at"] = now_iso

    if not fields:
        return

    table_url = f"{SUPABASE_URL}/rest/v1/app.hero_renders_tv?id=eq.{render_id}"
    headers = {
        "apikey": SUPABASE_SERVICE_KEY,
        "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
        "Content-Type": "application/json",
        "Accept": "application/json",
    }

    async with httpx.AsyncClient(timeout=10.0) as client:
        try:
            await client.patch(table_url, headers=headers, json=fields)
        except httpx.HTTPError:
            return


async def _upload_hero_file_to_supabase_storage(
    path: Path,
    *,
    slot: str,
    playlist_item_id: str,
    filename: str,
    content_type: str,
) -> str:
    if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
        raise HTTPException(
            status_code=500,
            detail={"message": "SUPABASE_URL ou SUPABASE_SERVICE_KEY manquante pour le rendu Hero Studio."},
        )

    bucket = "landing-media"
    slot_clean = (slot or "default").strip() or "default"
    object_key = f"hero-renders/{slot_clean}/{playlist_item_id}/{filename}"
    storage_url = f"{SUPABASE_URL}/storage/v1/object/{bucket}/{object_key}"

    try:
        print(
            "[HERO-STUDIO-UPLOAD]",
            json.dumps(
                {
                    "bucket": bucket,
                    "object_key": object_key,
                    "slot": slot_clean,
                    "playlist_item_id": playlist_item_id,
                    "content_type": content_type,
                },
                ensure_ascii=False,
            ),
        )
    except Exception:
        pass

    headers = {
        "apikey": SUPABASE_SERVICE_KEY,
        "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
        "Content-Type": content_type,
        # On autorise explicitement la réécriture d'un fichier existant
        # pour que les rerenders Hero/TV puissent écraser final.mp4 / thumb.jpg
        "x-upsert": "true",
    }

    data = path.read_bytes()

    async with httpx.AsyncClient(timeout=600.0) as client:
        resp = await client.post(storage_url, headers=headers, content=data)

    try:
        print(
            "[HERO-STUDIO-UPLOAD-RESULT]",
            json.dumps(
                {
                    "bucket": bucket,
                    "object_key": object_key,
                    "status_code": resp.status_code,
                },
                ensure_ascii=False,
            ),
        )
    except Exception:
        pass

    public_url = f"{SUPABASE_URL}/storage/v1/object/public/{bucket}/{object_key}"

    if resp.status_code >= 400:
        # Cas particulier : Supabase renvoie parfois une erreur Duplicate/409
        # lorsqu'un objet existe déjà. Avec x-upsert=true, cela ne devrait
        # plus se produire, mais on garde un garde-fou pour traiter ce cas
        # comme un succès silencieux.
        body: Dict[str, Any]
        try:
            body = resp.json()
        except ValueError:
            body = {"raw": resp.text}

        status_code_str = str(body.get("statusCode") or body.get("status_code") or "")
        error_str = str(body.get("error") or "").lower()
        message_str = str(body.get("message") or "").lower()
        is_duplicate = status_code_str == "409" or "duplicate" in error_str or "already exists" in message_str

        if is_duplicate:
            return public_url

        raise HTTPException(
            status_code=500,
            detail={
                "message": "Erreur lors de l'upload Hero Studio dans Supabase Storage.",
                "status_code": resp.status_code,
                "error": body,
            },
        )

    return public_url


async def update_hero_render_record(
    render_id: Optional[str],
    *,
    status: Optional[str] = None,
    render_url: Optional[str] = None,
    thumbnail_url: Optional[str] = None,
    logs: Optional[str] = None,
) -> None:
    if not render_id:
        return
    if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
        return

    fields: Dict[str, Any] = {}
    if status:
        fields["status"] = status
    if render_url:
        fields["render_url"] = render_url
    if thumbnail_url:
        fields["thumbnail_url"] = thumbnail_url
    if logs:
        fields["logs"] = logs[:4000]

    if not fields:
        return

    table_url = f"{SUPABASE_URL}/rest/v1/app.hero_renders?id=eq.{render_id}"
    headers = {
        "apikey": SUPABASE_SERVICE_KEY,
        "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
        "Content-Type": "application/json",
        "Accept": "application/json",
    }

    async with httpx.AsyncClient(timeout=10.0) as client:
        try:
            await client.patch(table_url, headers=headers, json=fields)
        except httpx.HTTPError:
            return


def _escape_drawtext_text(text: str) -> str:
    text = text.replace("\\", "\\\\")
    text = text.replace(":", "\\:")
    text = text.replace("'", "\\'")
    return text


def _build_hero_overlays_filter(layers_raw: Any) -> Optional[str]:
    if not isinstance(layers_raw, list):
        return None

    parts: List[str] = []
    for layer in layers_raw:
        if not isinstance(layer, dict):
            continue

        layer_type_raw = layer.get("type") or layer.get("kind")
        layer_type = str(layer_type_raw or "").strip().lower()
        if layer_type not in ("text", "lower_third", "ticker"):
            continue

        raw_text = layer.get("text") or layer.get("title")
        if raw_text is None:
            continue
        text = str(raw_text).strip()
        if not text:
            continue

        start = layer.get("start_at_seconds")
        end = layer.get("end_at_seconds")
        try:
            start_f = float(start) if start is not None else 0.0
        except (TypeError, ValueError):
            start_f = 0.0
        try:
            end_f = float(end) if end is not None else start_f + 5.0
        except (TypeError, ValueError):
            end_f = start_f + 5.0
        if end_f <= start_f:
            end_f = start_f + 5.0

        enable_expr = f"between(t,{start_f:.3f},{end_f:.3f})"

        align = str(layer.get("align") or layer.get("position") or "").strip().lower()
        if align == "top_left":
            x_expr, y_expr = "40", "40"
        elif align == "top_right":
            x_expr, y_expr = "w-tw-40", "40"
        elif align == "bottom_left":
            x_expr, y_expr = "40", "h-th-80"
        elif align == "bottom_right":
            x_expr, y_expr = "w-tw-40", "h-th-80"
        else:
            x_val = layer.get("x")
            y_val = layer.get("y")
            if isinstance(x_val, (int, float)) and isinstance(y_val, (int, float)):
                x_expr = str(int(x_val))
                y_expr = str(int(y_val))
            else:
                x_expr, y_expr = "40", "h-th-80"

        # Comportement spécifique pour les tickers TV : texte défilant de droite à gauche
        if layer_type == "ticker":
            # On fait défiler le texte à une vitesse modérée (~100 px/s),
            # en démarrant le mouvement à partir de start_f.
            base_t = f"{start_f:.3f}"
            x_expr = f"w-mod((t-{base_t})*100,w+tw)"
            y_expr = "h-th-40"

        escaped_text = _escape_drawtext_text(text)
        draw = (
            "drawtext=text='{text}':fontcolor=white:fontsize=32:"
            "x={x}:y={y}:box=1:boxcolor=black@0.5:boxborderw=10:enable='{enable}'"
        ).format(text=escaped_text, x=x_expr, y=y_expr, enable=enable_expr)
        parts.append(draw)

        # On limite volontairement le nombre de calques pour garder la commande ffmpeg raisonnable.
        if len(parts) >= 8:
            break

    if not parts:
        return None

    return ",".join(parts)


async def perform_hero_video_render(
    base_video_url: str,
    *,
    slot: str,
    playlist_item_id: str,
    overlays: Optional[Dict[str, Any]] = None,
) -> Dict[str, str]:
    url = (base_video_url or "").strip()
    if not url:
        raise HTTPException(status_code=400, detail={"message": "base_video_url manquant pour Hero Studio."})

    input_path: Optional[Path] = None
    output_path: Optional[Path] = None
    thumb_path: Optional[Path] = None
    logs_parts: List[str] = []

    video_url: str = ""
    thumbnail_url: str = ""
    started_at = time.perf_counter()
    error_message: Optional[str] = None

    overlays_dict: Dict[str, Any] = {}
    if isinstance(overlays, dict):
        overlays_dict = overlays
    layers_val = overlays_dict.get("layers") if overlays_dict else None
    extra_filters = _build_hero_overlays_filter(layers_val)
    if extra_filters:
        logs_parts.append(f"filters={extra_filters}")

    try:
        input_path = await _download_video_to_temp(url)

        if extra_filters:
            output_path = _run_ffmpeg_generic(
                input_path=input_path,
                max_width=720,
                max_bitrate_k=900,
                audio_bitrate_k=96,
                label="hero_main",
                fps=None,
                extra_filters=extra_filters,
            )
        else:
            output_path = _run_ffmpeg_transcode(input_path)

        tmp_dir = Path(tempfile.mkdtemp(prefix="hero_thumb_"))
        thumb_path = tmp_dir / "thumb.jpg"
        cmd = [
            "ffmpeg",
            "-y",
            "-i",
            str(output_path),
            "-ss",
            "0",
            "-vframes",
            "1",
            "-q:v",
            "2",
            str(thumb_path),
        ]
        result = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
        if result.returncode != 0:
            stderr_text = result.stderr.decode("utf-8", errors="ignore")
            logs_parts.append(f"thumb_error: {stderr_text[:1000]}")
            thumb_path = None

        video_url = await _upload_hero_file_to_supabase_storage(
            output_path,
            slot=slot,
            playlist_item_id=playlist_item_id,
            filename="final.mp4",
            content_type="video/mp4",
        )

        if thumb_path is not None and thumb_path.exists():
            thumbnail_url = await _upload_hero_file_to_supabase_storage(
                thumb_path,
                slot=slot,
                playlist_item_id=playlist_item_id,
                filename="thumb.jpg",
                content_type="image/jpeg",
            )
        else:
            thumbnail_url = ""
    except Exception as exc:
        error_message = str(exc)
        raise
    finally:
        try:
            if input_path is not None and input_path.exists():
                input_path.unlink()
        except Exception:
            pass
        try:
            if output_path is not None and output_path.exists():
                output_path.unlink()
        except Exception:
            pass
        try:
            if thumb_path is not None and thumb_path.exists():
                thumb_path.unlink()
        except Exception:
            pass

        duration_ms = int((time.perf_counter() - started_at) * 1000)
        event = {
            "event": "hero_video_render",
            "engine": "classic",
            "slot": slot,
            "playlist_item_id": playlist_item_id,
            "source_url": url,
            "filters": extra_filters or "",
            "status": "error" if error_message else "success",
            "render_url": video_url,
            "thumbnail_url": thumbnail_url,
            "duration_ms": duration_ms,
        }
        try:
            print("[HERO_RENDER]", json.dumps(event, ensure_ascii=False))
        except Exception:
            print("[HERO_RENDER]", str(event))

    logs_str = "\n".join(logs_parts) if logs_parts else ""
    return {"render_url": video_url, "thumbnail_url": thumbnail_url, "logs": logs_str}


def _build_tv_overlays_filter(overlays_raw: Any) -> Optional[str]:
    if not isinstance(overlays_raw, list):
        return None

    parts: List[str] = []
    for ov in overlays_raw:
        if not isinstance(ov, dict):
            continue

        overlay_type = str(ov.get("overlay_type") or "").strip().lower()
        if overlay_type not in ("text", "banner", "ticker"):
            continue

        cfg = ov.get("config") or {}
        if not isinstance(cfg, dict):
            cfg = {}

        raw_text = cfg.get("text") or cfg.get("title")
        if raw_text is None:
            continue
        text = str(raw_text).strip()
        if not text:
            continue

        start = ov.get("start_at_seconds")
        end = ov.get("end_at_seconds")
        try:
            start_f = float(start) if start is not None else 0.0
        except (TypeError, ValueError):
            start_f = 0.0
        try:
            end_f = float(end) if end is not None else start_f + 5.0
        except (TypeError, ValueError):
            end_f = start_f + 5.0
        if end_f <= start_f:
            end_f = start_f + 5.0

        enable_expr = f"between(t,{start_f:.3f},{end_f:.3f})"

        # Style broadcast basique (personnalisable via config)
        fontcolor = str(cfg.get("fontcolor") or cfg.get("font_color") or "white").strip() or "white"
        fontsize_raw = cfg.get("fontsize") or cfg.get("font_size")
        try:
            fontsize = int(fontsize_raw) if fontsize_raw is not None else 32
        except (TypeError, ValueError):
            fontsize = 32
        boxcolor = str(cfg.get("boxcolor") or cfg.get("box_color") or "black@0.5").strip() or "black@0.5"
        boxborderw_raw = cfg.get("boxborderw") or cfg.get("box_border_width")
        try:
            boxborderw = int(boxborderw_raw) if boxborderw_raw is not None else 10
        except (TypeError, ValueError):
            boxborderw = 10

        align = str(cfg.get("align") or cfg.get("position") or "").strip().lower()
        if align == "top_left":
            x_expr, y_expr = "40", "40"
        elif align == "top_right":
            x_expr, y_expr = "w-tw-40", "40"
        elif align == "top_center":
            x_expr, y_expr = "(w-tw)/2", "40"
        elif align == "bottom_left":
            x_expr, y_expr = "40", "h-th-80"
        elif align == "bottom_right":
            x_expr, y_expr = "w-tw-40", "h-th-80"
        elif align == "bottom_center":
            x_expr, y_expr = "(w-tw)/2", "h-th-80"
        elif align == "center":
            x_expr, y_expr = "(w-tw)/2", "(h-th)/2"
        else:
            x_val = cfg.get("x")
            y_val = cfg.get("y")
            if isinstance(x_val, (int, float)) and isinstance(y_val, (int, float)):
                x_expr = str(int(x_val))
                y_expr = str(int(y_val))
            else:
                x_expr, y_expr = "40", "h-th-80"

        # Animation optionnelle pour le texte fixe/banner
        animation = str(cfg.get("animation") or "").strip().lower()
        alpha_opt = ""
        if animation == "fade":
            fade_in_raw = cfg.get("fade_in_duration")
            fade_out_raw = cfg.get("fade_out_duration")
            try:
                fade_in = float(fade_in_raw) if fade_in_raw is not None else 0.5
            except (TypeError, ValueError):
                fade_in = 0.5
            try:
                fade_out = float(fade_out_raw) if fade_out_raw is not None else 0.5
            except (TypeError, ValueError):
                fade_out = 0.5
            # Sécuriser pour éviter des durées négatives
            if fade_in < 0:
                fade_in = 0.0
            if fade_out < 0:
                fade_out = 0.0
            # Expression alpha : fade in puis fade out autour de start/end
            alpha_expr = (
                f"if(lt(t,{start_f:.3f}+{fade_in:.3f}),"
                f" (t-{start_f:.3f})/{fade_in:.3f},"
                f" if(lt(t,{end_f:.3f}-{fade_out:.3f}),"
                " 1,"
                f" max(0,({end_f:.3f}-t)/{fade_out:.3f})))"
            )
            alpha_opt = f":alpha='{alpha_expr}'"

        # Comportement spécifique pour les tickers TV : texte défilant
        if overlay_type == "ticker":
            base_t = f"{start_f:.3f}"
            speed_raw = cfg.get("speed") or cfg.get("speed_px_per_s") or cfg.get("pixels_per_second")
            try:
                speed = float(speed_raw) if speed_raw is not None else 100.0
            except (TypeError, ValueError):
                speed = 100.0
            if speed <= 0:
                speed = 100.0
            x_expr = f"w-mod((t-{base_t})*{speed},w+tw)"
            y_expr = "h-th-40"

        escaped_text = _escape_drawtext_text(text)
        draw = (
            "drawtext=text='{text}':fontcolor={fontcolor}:fontsize={fontsize}:"
            "x={x}:y={y}:box=1:boxcolor={boxcolor}:boxborderw={boxborderw}{alpha}:enable='{enable}'"
        ).format(
            text=escaped_text,
            fontcolor=fontcolor,
            fontsize=fontsize,
            x=x_expr,
            y=y_expr,
            boxcolor=boxcolor,
            boxborderw=boxborderw,
            alpha=alpha_opt,
            enable=enable_expr,
        )
        parts.append(draw)

        if len(parts) >= 8:
            break

    if not parts:
        return None

    return ",".join(parts)


async def perform_hero_tv_video_render(
    base_video_url: str,
    *,
    slot: str,
    playlist_item_id: str,
    overlays: Optional[List[Dict[str, Any]]] = None,
) -> Dict[str, str]:
    url = (base_video_url or "").strip()
    if not url:
        raise HTTPException(status_code=400, detail={"message": "base_video_url manquant pour Studio TV."})

    input_path: Optional[Path] = None
    output_path: Optional[Path] = None
    thumb_path: Optional[Path] = None
    logs_parts: List[str] = []

    video_url: str = ""
    thumbnail_url: str = ""
    started_at = time.perf_counter()
    error_message: Optional[str] = None

    extra_filters = _build_tv_overlays_filter(overlays or [])
    if extra_filters:
        logs_parts.append(f"tv_filters={extra_filters}")

    try:
        input_path = await _download_video_to_temp(url)

        output_path = _run_ffmpeg_generic(
            input_path=input_path,
            max_width=1280,
            max_bitrate_k=1800,
            audio_bitrate_k=128,
            label="hero_tv_720p",
            fps=None,
            extra_filters=extra_filters,
        )

        tmp_dir = Path(tempfile.mkdtemp(prefix="hero_tv_thumb_"))
        thumb_path = tmp_dir / "thumb.jpg"
        cmd = [
            "ffmpeg",
            "-y",
            "-i",
            str(output_path),
            "-ss",
            "0",
            "-vframes",
            "1",
            "-q:v",
            "2",
            str(thumb_path),
        ]
        result = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
        if result.returncode != 0:
            stderr_text = result.stderr.decode("utf-8", errors="ignore")
            logs_parts.append(f"tv_thumb_error: {stderr_text[:1000]}")
            thumb_path = None

        video_url = await _upload_hero_file_to_supabase_storage(
            output_path,
            slot=slot,
            playlist_item_id=playlist_item_id,
            filename="tv_final.mp4",
            content_type="video/mp4",
        )

        if thumb_path is not None and thumb_path.exists():
            thumbnail_url = await _upload_hero_file_to_supabase_storage(
                thumb_path,
                slot=slot,
                playlist_item_id=playlist_item_id,
                filename="tv_thumb.jpg",
                content_type="image/jpeg",
            )
        else:
            thumbnail_url = ""
    except Exception as exc:
        error_message = str(exc)
        raise
    finally:
        try:
            if input_path is not None and input_path.exists():
                input_path.unlink()
        except Exception:
            pass
        try:
            if output_path is not None and output_path.exists():
                output_path.unlink()
        except Exception:
            pass
        try:
            if thumb_path is not None and thumb_path.exists():
                thumb_path.unlink()
        except Exception:
            pass

        duration_ms = int((time.perf_counter() - started_at) * 1000)
        event = {
            "event": "hero_video_render",
            "engine": "tv",
            "slot": slot,
            "playlist_item_id": playlist_item_id,
            "source_url": url,
            "filters": extra_filters or "",
            "status": "error" if error_message else "success",
            "render_url": video_url,
            "thumbnail_url": thumbnail_url,
            "duration_ms": duration_ms,
        }
        try:
            print("[HERO_TV_RENDER]", json.dumps(event, ensure_ascii=False))
        except Exception:
            print("[HERO_TV_RENDER]", str(event))

    logs_str = "\n".join(logs_parts) if logs_parts else ""
    return {"render_url": video_url, "thumbnail_url": thumbnail_url, "logs": logs_str}


@app.post("/hero/studio/render", response_model=HeroStudioRenderResponse)
async def hero_studio_render(req: HeroStudioRenderRequest, request: Request) -> HeroStudioRenderResponse:
    auth_header = request.headers.get("authorization") or request.headers.get("Authorization")
    if not auth_header or not auth_header.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Authorization Bearer manquant pour Hero Studio.")

    user_jwt = auth_header.split(" ", 1)[1].strip()
    if not user_jwt:
        raise HTTPException(status_code=401, detail="JWT utilisateur invalide pour Hero Studio.")

    playlist_item_id = (req.playlist_item_id or "").strip()
    if not playlist_item_id:
        raise HTTPException(status_code=400, detail="playlist_item_id manquant pour Hero Studio.")

    try:
        print(
            "[HERO_STUDIO_ENDPOINT]",
            json.dumps(
                {
                    "event": "hero_studio_render_request",
                    "playlist_item_id": playlist_item_id,
                    "slot": (req.slot or ""),
                },
                ensure_ascii=False,
            ),
        )
    except Exception:
        pass

    start_data = await call_supabase_rpc_as_user(
        user_jwt,
        "app_admin_start_hero_render",
        {"p_playlist_item_id": playlist_item_id},
    )

    if not isinstance(start_data, dict) or not start_data.get("success"):
        error_code = None
        if isinstance(start_data, dict):
            error_code = start_data.get("error")
        raise HTTPException(
            status_code=403,
            detail={
                "message": "Impossible de démarrer le rendu Hero Studio",
                "error": error_code or "unknown_error",
            },
        )

    render_id_raw = start_data.get("render_id") if isinstance(start_data, dict) else None
    if not isinstance(render_id_raw, str) or not render_id_raw.strip():
        raise HTTPException(
            status_code=500,
            detail={"message": "Réponse Supabase invalide pour app_admin_start_hero_render."},
        )
    render_id = render_id_raw.strip()

    cfg_data = await call_supabase_rpc_as_user(
        user_jwt,
        "app_admin_get_hero_playlist_item_config",
        {"p_playlist_item_id": playlist_item_id},
    )

    if not isinstance(cfg_data, dict) or not cfg_data.get("success"):
        error_code = None
        if isinstance(cfg_data, dict):
            error_code = cfg_data.get("error")
        await update_hero_render_record(
            render_id,
            status="failed",
            logs=f"config_error: {error_code or 'unknown_error'}",
        )
        raise HTTPException(
            status_code=403,
            detail={
                "message": "Impossible de lire la configuration Hero Studio",
                "error": error_code or "unknown_error",
            },
        )

    item = cfg_data.get("item") if isinstance(cfg_data, dict) else None
    if not isinstance(item, dict):
        await update_hero_render_record(
            render_id,
            status="failed",
            logs="config_error: missing_item",
        )
        raise HTTPException(
            status_code=500,
            detail={"message": "Réponse Supabase invalide pour la configuration Hero Studio."},
        )

    slot = (req.slot or str(item.get("slot") or "")).strip() or "default"
    media_type = str(item.get("media_type") or "video").strip().lower()
    base_video_url_raw = item.get("base_video_url")
    base_video_url = str(base_video_url_raw or "").strip()

    if media_type != "video":
        await update_hero_render_record(
            render_id,
            status="failed",
            logs=f"unsupported_media_type: {media_type}",
        )
        raise HTTPException(
            status_code=400,
            detail={"message": "Seules les entrées vidéo sont supportées pour Hero Studio."},
        )

    if not base_video_url:
        await update_hero_render_record(
            render_id,
            status="failed",
            logs="missing_base_video_url",
        )
        raise HTTPException(
            status_code=400,
            detail={"message": "Aucune URL vidéo de base configurée pour cet item Hero."},
        )

    overlays_val = item.get("overlays")
    overlays_dict: Optional[Dict[str, Any]] = None
    if isinstance(overlays_val, dict):
        overlays_dict = overlays_val
    elif isinstance(overlays_val, list):
        overlays_dict = {"layers": overlays_val}

    try:
        render_payload = await perform_hero_video_render(
            base_video_url,
            slot=slot,
            playlist_item_id=playlist_item_id,
            overlays=overlays_dict,
        )
    except HTTPException as exc:
        detail = exc.detail
        msg: Optional[str] = None
        if isinstance(detail, dict):
            msg = str(detail.get("message") or "")
        await update_hero_render_record(
            render_id,
            status="failed",
            logs=msg or "hero_render_failed",
        )
        raise

    render_url = str(render_payload.get("render_url") or "").strip()
    thumbnail_url = str(render_payload.get("thumbnail_url") or "").strip()
    logs = str(render_payload.get("logs") or "").strip()

    if not render_url:
        await update_hero_render_record(
            render_id,
            status="failed",
            logs=logs or "missing_render_url",
        )
        raise HTTPException(
            status_code=500,
            detail={"message": "URL du rendu Hero Studio manquante."},
        )

    await update_hero_render_record(
        render_id,
        status="done",
        render_url=render_url,
        thumbnail_url=thumbnail_url or None,
        logs=logs or None,
    )

    if SUPABASE_URL and SUPABASE_SERVICE_KEY and render_url:
        table_url = f"{SUPABASE_URL}/rest/v1/app.hero_playlist?id=eq.{playlist_item_id}"
        headers = {
            "apikey": SUPABASE_SERVICE_KEY,
            "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
            "Content-Type": "application/json",
            "Accept": "application/json",
            "Prefer": "return=minimal",
        }
        payload: Dict[str, Any] = {"base_video_url": render_url}
        if thumbnail_url:
            payload["base_image_url"] = thumbnail_url

        async with httpx.AsyncClient(timeout=10.0) as client:
            try:
                await client.patch(table_url, headers=headers, json=payload)
            except httpx.HTTPError:
                pass

    return HeroStudioRenderResponse(
        success=True,
        playlist_item_id=playlist_item_id,
        render_id=render_id,
        render_url=render_url,
        thumbnail_url=thumbnail_url or "",
        status="done",
    )


@app.post("/studio/tv/render", response_model=TvStudioRenderResponse)
async def tv_studio_render(req: TvStudioRenderRequest, request: Request) -> TvStudioRenderResponse:
    auth_header = request.headers.get("authorization") or request.headers.get("Authorization")
    if not auth_header or not auth_header.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Authorization Bearer manquant pour le Studio TV.")

    user_jwt = auth_header.split(" ", 1)[1].strip()
    if not user_jwt:
        raise HTTPException(status_code=401, detail="JWT utilisateur invalide pour le Studio TV.")

    playlist_item_id = (req.playlist_item_id or "").strip()
    if not playlist_item_id:
        raise HTTPException(status_code=400, detail="playlist_item_id manquant pour le Studio TV.")

    meta = req.meta or {}

    try:
        print(
            "[TV_STUDIO_ENDPOINT]",
            json.dumps(
                {
                    "event": "tv_studio_render_request",
                    "playlist_item_id": playlist_item_id,
                    "slot": (req.slot or ""),
                    "meta_keys": sorted(list(meta.keys())) if isinstance(meta, dict) else None,
                },
                ensure_ascii=False,
            ),
        )
    except Exception:
        pass

    start_data = await call_supabase_rpc_as_user(
        user_jwt,
        "app_admin_tv_request_render",
        {"p_playlist_item_id": playlist_item_id, "p_meta": meta},
    )

    if not isinstance(start_data, dict) or not start_data.get("success"):
        error_code = None
        if isinstance(start_data, dict):
            error_code = start_data.get("error")
        raise HTTPException(
            status_code=403,
            detail={
                "message": "Impossible de démarrer le rendu Studio TV",
                "error": error_code or "unknown_error",
            },
        )

    render_id_raw = start_data.get("render_id") if isinstance(start_data, dict) else None
    if not isinstance(render_id_raw, str) or not render_id_raw.strip():
        raise HTTPException(
            status_code=500,
            detail="Réponse Supabase invalide pour app_admin_tv_request_render.",
        )
    render_id = render_id_raw.strip()

    await update_tv_render_record(
        render_id,
        status="processing",
        set_started_at=True,
    )

    cfg_data = await call_supabase_rpc_as_user(
        user_jwt,
        "app_admin_get_hero_playlist_item_config",
        {"p_playlist_item_id": playlist_item_id},
    )

    if not isinstance(cfg_data, dict) or not cfg_data.get("success"):
        error_code = None
        if isinstance(cfg_data, dict):
            error_code = cfg_data.get("error")
        await update_tv_render_record(
            render_id,
            status="failed",
            error_message=f"config_error: {error_code or 'unknown_error'}",
            set_finished_at=True,
        )
        raise HTTPException(
            status_code=403,
            detail={
                "message": "Impossible de lire la configuration Hero pour Studio TV",
                "error": error_code or "unknown_error",
            },
        )

    item = cfg_data.get("item") if isinstance(cfg_data, dict) else None
    if not isinstance(item, dict):
        await update_tv_render_record(
            render_id,
            status="failed",
            error_message="config_error: missing_item",
            set_finished_at=True,
        )
        raise HTTPException(
            status_code=500,
            detail={"message": "Réponse Supabase invalide pour la configuration Hero (Studio TV)."},
        )

    slot = (req.slot or str(item.get("slot") or "")).strip() or "default"
    media_type = str(item.get("media_type") or "video").strip().lower()
    base_video_url_raw = item.get("base_video_url")
    base_video_url = str(base_video_url_raw or "").strip()

    if media_type != "video":
        await update_tv_render_record(
            render_id,
            status="failed",
            error_message=f"unsupported_media_type: {media_type}",
            set_finished_at=True,
        )
        raise HTTPException(
            status_code=400,
            detail={"message": "Seules les entrées vidéo sont supportées pour le Studio TV."},
        )

    if not base_video_url:
        await update_tv_render_record(
            render_id,
            status="failed",
            error_message="missing_base_video_url",
            set_finished_at=True,
        )
        raise HTTPException(
            status_code=400,
            detail={"message": "Aucune URL vidéo de base configurée pour cet item Hero (Studio TV)."},
        )

    timeline_data = await call_supabase_rpc_as_user(
        user_jwt,
        "app_admin_tv_get_timeline",
        {"p_playlist_item_id": playlist_item_id},
    )

    if not isinstance(timeline_data, dict) or not timeline_data.get("success"):
        error_code = None
        if isinstance(timeline_data, dict):
            error_code = timeline_data.get("error")
        await update_tv_render_record(
            render_id,
            status="failed",
            error_message=f"timeline_error: {error_code or 'unknown_error'}",
            set_finished_at=True,
        )
        raise HTTPException(
            status_code=403,
            detail={
                "message": "Impossible de lire la timeline TV pour cet item Hero.",
                "error": error_code or "unknown_error",
            },
        )

    overlays_list_raw = timeline_data.get("overlays")
    overlays_list: List[Dict[str, Any]] = []
    if isinstance(overlays_list_raw, list):
        for ov in overlays_list_raw:
            if isinstance(ov, dict):
                overlays_list.append(ov)

    try:
        render_payload = await perform_hero_tv_video_render(
            base_video_url,
            slot=slot,
            playlist_item_id=playlist_item_id,
            overlays=overlays_list,
        )
    except HTTPException as exc:
        detail = exc.detail
        msg: Optional[str] = None
        if isinstance(detail, dict):
            msg = str(detail.get("message") or "")
        await update_tv_render_record(
            render_id,
            status="failed",
            error_message=msg or "tv_render_failed",
            set_finished_at=True,
        )
        raise

    render_url = str(render_payload.get("render_url") or "").strip()
    thumbnail_url = str(render_payload.get("thumbnail_url") or "").strip()
    logs = str(render_payload.get("logs") or "").strip()

    if not render_url:
        await update_tv_render_record(
            render_id,
            status="failed",
            error_message=logs or "missing_render_url",
            set_finished_at=True,
        )
        raise HTTPException(
            status_code=500,
            detail={"message": "URL du rendu Studio TV manquante."},
        )

    await update_tv_render_record(
        render_id,
        status="success",
        render_url=render_url,
        thumbnail_url=thumbnail_url or None,
        set_finished_at=True,
    )

    if SUPABASE_URL and SUPABASE_SERVICE_KEY and render_url:
        table_url = f"{SUPABASE_URL}/rest/v1/app.hero_playlist?id=eq.{playlist_item_id}"
        headers = {
            "apikey": SUPABASE_SERVICE_KEY,
            "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
            "Content-Type": "application/json",
            "Accept": "application/json",
            "Prefer": "return=minimal",
        }
        payload: Dict[str, Any] = {"base_video_url": render_url}
        if thumbnail_url:
            payload["base_image_url"] = thumbnail_url

        async with httpx.AsyncClient(timeout=10.0) as client:
            try:
                await client.patch(table_url, headers=headers, json=payload)
            except httpx.HTTPError:
                pass

    return TvStudioRenderResponse(
        success=True,
        playlist_item_id=playlist_item_id,
        render_id=render_id,
        render_url=render_url,
        thumbnail_url=thumbnail_url or "",
        status="success",
    )


@app.post("/admin/challenge_videos/{participation_id}/rerender")
async def admin_rerender_challenge_video(participation_id: str, request: Request) -> Dict[str, Any]:
    auth_header = request.headers.get("authorization") or request.headers.get("Authorization")
    if not auth_header or not auth_header.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Authorization Bearer manquant pour le re-rendu vidéo admin.")

    participation_id = participation_id.strip()
    if not participation_id:
        raise HTTPException(status_code=400, detail="participation_id manquant pour le re-rendu vidéo admin.")

    if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
        raise HTTPException(
            status_code=500,
            detail="SUPABASE_URL ou SUPABASE_SERVICE_KEY non configurée côté backend.",
        )

    supabase_base = SUPABASE_URL.rstrip("/")

    # 1) Récupérer la participation pour obtenir l'URL vidéo actuelle
    participation_url = f"{supabase_base}/rest/v1/app.challenge_participations"
    params = {
        "id": f"eq.{participation_id}",
        "select": "id,video_url,video_renditions,thumbnail_url",
    }
    headers = {
        "apikey": SUPABASE_SERVICE_KEY,
        "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
        "Accept": "application/json",
    }

    async with httpx.AsyncClient(timeout=10.0) as client:
        resp = await client.get(participation_url, headers=headers, params=params)

    if resp.status_code >= 400:
        try:
            body = resp.json()
        except ValueError:
            body = {"raw": resp.text}
        raise HTTPException(
            status_code=500,
            detail={
                "message": "Erreur lors de la récupération de la participation de challenge.",
                "status_code": resp.status_code,
                "error": body,
            },
        )

    try:
        rows = resp.json()
    except ValueError:
        rows = []

    if not isinstance(rows, list) or not rows:
        raise HTTPException(
            status_code=404,
            detail={"message": "Participation de challenge introuvable pour le re-rendu vidéo admin."},
        )

    participation_row = rows[0]
    source_video_raw = participation_row.get("video_url")
    source_video_url = str(source_video_raw or "").strip()
    if not source_video_url:
        raise HTTPException(
            status_code=400,
            detail={"message": "Aucune URL vidéo existante pour cette participation (admin re-render)."},
        )

    # 2) Récupérer éventuellement les overlays associés (table app.challenge_video_overlays)
    overlays: Dict[str, Any] = {}
    overlays_url = f"{supabase_base}/rest/v1/app.challenge_video_overlays"
    overlays_params = {
        "participation_id": f"eq.{participation_id}",
        "select": "layers",
    }

    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            overlays_resp = await client.get(overlays_url, headers=headers, params=overlays_params)
        if overlays_resp.status_code < 400:
            ov_rows = overlays_resp.json()
            if isinstance(ov_rows, list) and ov_rows:
                first = ov_rows[0]
                layers_val = first.get("layers")
                if isinstance(layers_val, dict):
                    overlays = {"layers": layers_val}
                else:
                    overlays = {"layers": layers_val}
    except Exception:
        # En cas d'erreur, on continue avec des overlays vides
        overlays = {}

    # 3) Créer un job de rendu spécifique admin pour tracer l'opération
    metadata: Dict[str, Any] = {"admin_rerender": True}
    job_id = await create_render_job(
        video_type="challenge",
        participation_id=participation_id,
        job_type="video_edit_admin",
        source_video_url=source_video_url,
        metadata=metadata,
    )

    # 4) Relancer le pipeline de rendu vidéo Studio
    try:
        render_payload = await call_studio_video_render(
            video_url=source_video_url,
            overlays=overlays,
            participation_id=participation_id,
        )
    except HTTPException as exc:
        detail = exc.detail
        msg: Optional[str] = None
        if isinstance(detail, dict):
            msg = str(detail.get("message") or "")
        await update_render_job(job_id, status="failed", error_message=msg)
        raise

    rendered_url_raw: Optional[str] = None
    video_renditions: Dict[str, Any] = {}
    if isinstance(render_payload, dict):
        raw = render_payload.get("video_url") or render_payload.get("rendered_url")
        if isinstance(raw, str):
            rendered_url_raw = raw
        vr = render_payload.get("video_renditions")
        if isinstance(vr, dict):
            video_renditions = vr

    rendered_url = (rendered_url_raw or "").strip()
    if not rendered_url:
        msg = "URL vidéo rendue manquante dans la réponse du service Studio vidéo (admin re-render)."
        await update_render_job(job_id, status="failed", error_message=msg)
        raise HTTPException(status_code=500, detail={"message": msg})

    # 5) Mettre à jour la participation avec la nouvelle URL et les renditions
    patch_url = f"{supabase_base}/rest/v1/app.challenge_participations?id=eq.{participation_id}"
    patch_body: Dict[str, Any] = {
        "video_url": rendered_url,
        "video_renditions": video_renditions or None,
    }

    async with httpx.AsyncClient(timeout=10.0) as client:
        patch_resp = await client.patch(patch_url, headers=headers, json=patch_body)

    if patch_resp.status_code >= 400:
        try:
            body = patch_resp.json()
        except ValueError:
            body = {"raw": patch_resp.text}
        msg = "Erreur lors de la mise à jour de la participation avec la nouvelle vidéo rendue (admin)."
        await update_render_job(job_id, status="failed", error_message=msg)
        raise HTTPException(
            status_code=500,
            detail={
                "message": msg,
                "status_code": patch_resp.status_code,
                "error": body,
            },
        )

    await update_render_job(job_id, status="completed", result_video_url=rendered_url)

    return {
        "success": True,
        "participation_id": participation_id,
        "video_url": rendered_url,
        "video_renditions": video_renditions,
    }


@app.post("/telemetry/video_playback_error")
async def telemetry_video_playback_error(payload: VideoPlaybackErrorIn) -> Dict[str, Any]:
    if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
        raise HTTPException(
            status_code=500,
            detail="SUPABASE_URL ou SUPABASE_SERVICE_KEY non configurée côté backend.",
        )

    supabase_base = SUPABASE_URL.rstrip("/")
    table_url = f"{supabase_base}/rest/v1/app.video_playback_errors"

    video_url = (payload.video_url or "").strip()
    error_message = (payload.error_message or "").strip()
    if not video_url or not error_message:
        raise HTTPException(
            status_code=400,
            detail={"message": "video_url et error_message sont obligatoires pour la télémétrie vidéo."},
        )

    body: Dict[str, Any] = {
        "video_url": video_url,
        "error_message": error_message[:2000],
    }
    if payload.device_model:
        body["device_model"] = payload.device_model
    if payload.platform:
        body["platform"] = payload.platform
    if payload.os_version:
        body["os_version"] = payload.os_version
    if payload.app_version:
        body["app_version"] = payload.app_version
    if payload.rendition_key:
        body["rendition_key"] = payload.rendition_key
    if payload.raw_error is not None:
        body["raw_error"] = payload.raw_error

    headers = {
        "apikey": SUPABASE_SERVICE_KEY,
        "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
        "Content-Type": "application/json",
        "Accept": "application/json",
    }

    async with httpx.AsyncClient(timeout=10.0) as client:
        resp = await client.post(table_url, headers=headers, json=body)

    if resp.status_code >= 400:
        try:
            error_body = resp.json()
        except ValueError:
            error_body = {"raw": resp.text[:400]}
        raise HTTPException(
            status_code=500,
            detail={
                "message": "Erreur lors de l'enregistrement de la télémétrie de lecture vidéo.",
                "status_code": resp.status_code,
                "error": error_body,
            },
        )

    return {"success": True}


@app.post("/studio/ai/transcribe", response_model=StudioTranscriptionResponse)
async def studio_ai_transcribe(req: StudioTranscriptionRequest, request: Request) -> StudioTranscriptionResponse:
    auth_header = request.headers.get("authorization") or request.headers.get("Authorization")
    if not auth_header or not auth_header.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Authorization Bearer manquant pour la transcription.")

    user_jwt = auth_header.split(" ", 1)[1].strip()
    if not user_jwt:
        raise HTTPException(status_code=401, detail="JWT utilisateur invalide pour la transcription.")

    vt = (req.video_type or "challenge").strip().lower()
    if vt not in ("challenge", "free"):
        vt = "challenge"

    participation_id: Optional[str] = None
    free_video_id: Optional[str] = None

    if vt == "free":
        free_video_id = (req.free_video_id or "").strip()
        if not free_video_id:
            raise HTTPException(status_code=400, detail="free_video_id manquant pour la transcription.")
        video = await get_free_video_for_user(user_jwt, free_video_id)
    else:
        participation_id = (req.participation_id or "").strip()
        if not participation_id:
            raise HTTPException(status_code=400, detail="participation_id manquant pour la transcription.")
        video = await get_challenge_video_for_user(user_jwt, participation_id)

    video_url_raw = video.get("video_url")
    video_url = str(video_url_raw or "").strip()
    if not video_url:
        raise HTTPException(status_code=400, detail="Aucune URL vidéo disponible pour cette participation.")

    subtitles = await call_studio_asr(video_url, req.language)

    existing_overlays = video.get("overlays")
    overlays_dict: Dict[str, Any]
    if isinstance(existing_overlays, dict):
        overlays_dict = existing_overlays
    else:
        overlays_dict = {}

    new_overlays: Dict[str, Any] = dict(overlays_dict)
    background = overlays_dict.get("background")
    if not isinstance(background, dict):
        background = {}
    new_overlays["background"] = background

    filter_value = overlays_dict.get("filter")
    if not isinstance(filter_value, str):
        filter_value = "none"
    new_overlays["filter"] = filter_value

    def _normalize_layer_list(value: Any) -> List[Dict[str, Any]]:
        if isinstance(value, list):
            result: List[Dict[str, Any]] = []
            for item in value:
                if isinstance(item, dict):
                    result.append(dict(item))
            return result
        return []

    new_overlays["texts"] = _normalize_layer_list(overlays_dict.get("texts"))
    new_overlays["equations"] = _normalize_layer_list(overlays_dict.get("equations"))
    new_overlays["subtitles"] = subtitles
    new_overlays["stickers"] = _normalize_layer_list(overlays_dict.get("stickers"))

    if vt == "free":
        update_result = await call_supabase_rpc_as_user(
            user_jwt,
            "app_student_update_free_video_overlays",
            {
                "p_free_video_id": free_video_id,
                "p_layers": new_overlays,
            },
        )
    else:
        update_result = await call_supabase_rpc_as_user(
            user_jwt,
            "app_student_update_challenge_video_overlays",
            {
                "p_participation_id": participation_id,
                "p_layers": new_overlays,
            },
        )

    if not isinstance(update_result, dict) or not update_result.get("success"):
        error_code = None
        if isinstance(update_result, dict):
            error_code = update_result.get("error")
        raise HTTPException(
            status_code=500,
            detail={
                "message": "Erreur lors de la mise à jour des overlays de challenge.",
                "error": error_code or "unknown_error",
            },
        )

    return StudioTranscriptionResponse(
        success=True,
        participation_id=participation_id or (free_video_id or ""),
        subtitles=subtitles,
        overlays=new_overlays,
        video_type=vt,
        free_video_id=free_video_id,
    )


@app.post("/studio/ai/analyze", response_model=StudioAnalyzeResponse)
async def studio_ai_analyze(req: StudioAnalyzeRequest, request: Request) -> StudioAnalyzeResponse:
    auth_header = request.headers.get("authorization") or request.headers.get("Authorization")
    if not auth_header or not auth_header.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Authorization Bearer manquant pour l'analyse.")

    user_jwt = auth_header.split(" ", 1)[1].strip()
    if not user_jwt:
        raise HTTPException(status_code=401, detail="JWT utilisateur invalide pour l'analyse.")

    vt = (req.video_type or "challenge").strip().lower()
    if vt not in ("challenge", "free"):
        vt = "challenge"

    participation_id: Optional[str] = None
    free_video_id: Optional[str] = None

    if vt == "free":
        free_video_id = (req.free_video_id or "").strip()
        if not free_video_id:
            raise HTTPException(status_code=400, detail="free_video_id manquant pour l'analyse.")
        video = await get_free_video_for_user(user_jwt, free_video_id)
    else:
        participation_id = (req.participation_id or "").strip()
        if not participation_id:
            raise HTTPException(status_code=400, detail="participation_id manquant pour l'analyse.")
        video = await get_challenge_video_for_user(user_jwt, participation_id)

    overlays = video.get("overlays")
    transcript_parts: List[str] = []
    if isinstance(overlays, dict):
        subtitles_val = overlays.get("subtitles")
        if isinstance(subtitles_val, list):
            for item in subtitles_val:
                if not isinstance(item, dict):
                    continue
                text = str(item.get("text") or "").strip()
                if text:
                    transcript_parts.append(text)

    transcript = "\n".join(transcript_parts)

    metadata_parts: List[str] = []
    if vt == "free":
        title_raw = video.get("title")
        if title_raw:
            metadata_parts.append(f"Titre de la vidéo: {title_raw}")
        description_raw = video.get("description")
        if description_raw:
            metadata_parts.append(f"Description: {description_raw}")
    else:
        challenge_title_raw = video.get("challenge_title")
        if challenge_title_raw:
            metadata_parts.append(f"Titre du challenge: {challenge_title_raw}")
        challenge_type_raw = video.get("challenge_type")
        if challenge_type_raw:
            metadata_parts.append(f"Type: {challenge_type_raw}")
        difficulty_raw = video.get("difficulty")
        if difficulty_raw:
            metadata_parts.append(f"Difficulté: {difficulty_raw}")
        points_raw = video.get("points")
        if points_raw is not None:
            metadata_parts.append(f"Points: {points_raw}")

    knowledge: List[Dict[str, Any]] = []
    if transcript:
        knowledge.append({"title": "transcription_video", "content": transcript})
    if metadata_parts:
        knowledge.append({"title": "meta_video", "content": "\n".join(metadata_parts)})

    if vt == "free":
        analysis_prompt = (
            "Analyse cette vidéo pour en extraire: "
            "1) un résumé pédagogique clair, "
            "2) un plan de cours en quelques points, "
            "3) 3 à 5 questions de type quiz ou QCM pour vérifier la compréhension. "
            "Réponds en français, dans un texte structuré avec des titres et puces simples."
        )
    else:
        analysis_prompt = (
            "Analyse cette vidéo de challenge pour en extraire: "
            "1) un résumé pédagogique clair, "
            "2) un plan de cours en quelques points, "
            "3) 3 à 5 questions de type quiz ou QCM pour vérifier la compréhension. "
            "Réponds en français, dans un texte structuré avec des titres et puces simples."
        )

    analysis = await call_openrouter(
        analysis_prompt,
        knowledge,
        system_prompt=None,
        include_no_answer_sentinel=False,
    )

    return StudioAnalyzeResponse(
        success=True,
        participation_id=participation_id or (free_video_id or ""),
        analysis=analysis,
        video_type=vt,
        free_video_id=free_video_id,
    )


@app.post("/studio/ai/proofread", response_model=StudioProofreadResponse)
async def studio_ai_proofread(req: StudioProofreadRequest, request: Request) -> StudioProofreadResponse:
    auth_header = request.headers.get("authorization") or request.headers.get("Authorization")
    if not auth_header or not auth_header.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Authorization Bearer manquant pour la relecture.")

    user_jwt = auth_header.split(" ", 1)[1].strip()
    if not user_jwt:
        raise HTTPException(status_code=401, detail="JWT utilisateur invalide pour la relecture.")

    text = (req.text or "").strip()
    if not text:
        raise HTTPException(status_code=400, detail="Le texte à relire ne peut pas être vide.")

    system_prompt = (
        "Tu es un assistant pédagogique pour la plateforme Academia. "
        "On te fournit un texte court à destination d'étudiants ou de correcteurs. "
        "Tu dois corriger l'orthographe, la grammaire et la ponctuation, et harmoniser le ton en français académique simple, "
        "sans changer le sens ni allonger fortement le texte."
    )

    corrected = await call_openrouter(
        text,
        [],
        system_prompt=system_prompt,
        include_no_answer_sentinel=False,
    )

    return StudioProofreadResponse(success=True, text=corrected)


@app.post("/bobodo/chat", response_model=BobodoChatResponse)
async def bobodo_chat(payload: BobodoChatRequest) -> BobodoChatResponse:
    """Endpoint principal Bobodo.

    - enregistre le message de l'étudiant via Supabase (RPC app_append_bobodo_message)
    - cherche du contexte dans la base de connaissances
    - appelle OpenRouter pour générer la réponse
    - enregistre la réponse IA dans Supabase
    """
    message = payload.message.strip()
    if not message:
        raise HTTPException(status_code=400, detail="Le message ne peut pas être vide.")

    session_id = payload.session_id
    if not session_id:
        # La création de session est gérée côté Flutter via app_create_bobodo_session,
        # car cette RPC dépend de auth.uid(). Ici, on exige un session_id valide.
        raise HTTPException(
            status_code=400,
            detail="session_id manquant. La session Bobodo doit être créée côté Flutter.",
        )

    already_has_assistant = await has_bobodo_assistant_message(session_id)
    is_first_assistant = not already_has_assistant

    # 1) Enregistrer le message de l'étudiant
    await call_supabase_rpc(
        "app_append_bobodo_message",
        {
            "p_session_id": session_id,
            "p_sender": "student",
            "p_content": message,
            "p_safety_flag": None,
        },
    )

    # 2) Recherche de connaissance
    knowledge = await search_knowledge(message)

    # 3) Filtre de sécurité, classification et génération de la réponse IA
    try:
        if is_sensitive_query(message):
            assistant_message = await call_openrouter_safety_refusal(message)
        else:
            category = await classify_query_with_openrouter(message)
            assistant_message = await generate_answer_for_category(
                message,
                category,
                knowledge,
                session_id,
            )
            await log_detected_need(session_id, message, category)
    except HTTPException as exc:
        detail = exc.detail
        fallback_message: Optional[str] = None
        if isinstance(detail, dict):
            message_key = str(detail.get("message") or "")
            if message_key in {"Erreur OpenRouter", "Erreur réseau OpenRouter"}:
                fallback_message = (
                    "Je suis temporairement indisponible car le service d'intelligence "
                    "artificielle externe d'Academia rencontre un problème technique. "
                    "Tu peux réessayer dans quelques minutes ; les autres fonctionnalités "
                    "de la plateforme restent disponibles."
                )

        if fallback_message is None:
            raise

        assistant_message = fallback_message

    if is_first_assistant:
        first_name = await get_student_first_name(session_id)
        if first_name:
            greeting_prefix = (
                f"Bonjour {first_name}, on se rencontre, je suis Bobodo, "
                "l'assistant d'Academia. "
            )
        else:
            greeting_prefix = (
                "Bonjour, je suis Bobodo, l'assistant d'Academia. "
            )
        assistant_message = greeting_prefix + assistant_message.lstrip()

    # 4) Enregistrer la réponse IA
    await call_supabase_rpc(
        "app_append_bobodo_message",
        {
            "p_session_id": session_id,
            "p_sender": "assistant",
            "p_content": assistant_message,
            "p_safety_flag": None,
        },
    )

    return BobodoChatResponse(session_id=session_id, assistant_message=assistant_message)


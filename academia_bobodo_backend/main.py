import os
from pathlib import Path
from typing import Any, Dict, List, Optional
from datetime import datetime, timezone
import subprocess

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
    participation_id: str
    language: Optional[str] = None


class StudioTranscriptionResponse(BaseModel):
    success: bool
    participation_id: str
    subtitles: List[Dict[str, Any]]
    overlays: Dict[str, Any]


class StudioAnalyzeRequest(BaseModel):
    participation_id: str


class StudioAnalyzeResponse(BaseModel):
    success: bool
    participation_id: str
    analysis: str


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
    participation_id: str
    tracks: List[StudioAudioTrackSpec]
    normalize: Optional[bool] = True


class StudioAudioRenderResponse(BaseModel):
    success: bool
    participation_id: str
    video_url: str
    added_video_id: Optional[str] = None


class StudioVideoRenderRequest(BaseModel):
    participation_id: str


class StudioVideoRenderResponse(BaseModel):
    success: bool
    participation_id: str
    video_url: str
    added_video_id: Optional[str] = None


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
    participation_id: str,
    job_type: str,
    source_video_url: Optional[str],
    metadata: Optional[Dict[str, Any]] = None,
) -> Optional[str]:
    if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
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
        "participation_id": participation_id,
        "job_type": job_type,
        "status": "running",
    }
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


async def call_openrouter(
    message: str,
    knowledge: List[Dict[str, Any]],
    system_prompt: Optional[str] = None,
    include_no_answer_sentinel: bool = True,
) -> str:
    """Appelle OpenRouter pour générer une réponse d'IA en français, avec contexte."""
    if not OPENROUTER_API_KEY:
        return (
            "Je suis Bobodo en mode développement (clé OpenRouter manquante). "
            "Merci de configurer OPENROUTER_API_KEY dans le fichier .env."
        )

    context_chunks: List[str] = []
    for item in knowledge[:5]:
        title = str(item.get("title") or "")
        content = str(item.get("content") or "")
        context_chunks.append(f"[{title}]\n{content}")

    context_text = "\n\n".join(context_chunks) or "Aucune connaissance spécifique trouvée."

    if system_prompt is None:
        system_prompt = (
            "Tu es Bobodo, un assistant IA pour le projet Academia. "
            "Tu aides les étudiants sur les études, les candidatures, les cours et les offres. "
            "Réponds toujours en français, de manière claire, structurée et bienveillante. "
            "Tu dois comprendre le sens de la question même si elle est mal formulée, contient des fautes de frappe ou des tournures inhabituelles. "
            "Si l'utilisateur pose plusieurs fois la même question, tu peux reformuler la réponse avec un style légèrement différent tout en gardant le même fond. "
            "Quand la question concerne l'orientation des études, la formation ou l'emploi, tu peux, après ta réponse principale, proposer UNE SEULE question ouverte et courte pour mieux comprendre la situation de l'étudiant, uniquement si cela est vraiment utile. "
            "Ne demande jamais de données personnelles sensibles (numéro de téléphone, adresse, document officiel, etc.). "
            "Si une information n'est pas disponible, dis-le honnêtement."
        )
        if include_no_answer_sentinel:
            system_prompt += (
                f" Si tu n'as vraiment pas assez d'informations fiables pour répondre, "
                f"réponds EXACTEMENT par {NO_ANSWER_SENTINEL} et rien d'autre."
            )

    user_prompt = (
        f"Contexte de la base de connaissances :\n{context_text}\n\n"
        f"Question de l'étudiant :\n{message}"
    )

    headers = {
        "Authorization": f"Bearer {OPENROUTER_API_KEY}",
        "Content-Type": "application/json",
    }

    body = {
        "model": OPENROUTER_MODEL,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ],
        "temperature": 0.7,
        "top_p": 0.9,
        "presence_penalty": 0.2,
        "frequency_penalty": 0.3,
    }

    async with httpx.AsyncClient(timeout=60.0) as client:
        try:
            response = await client.post(
                "https://openrouter.ai/api/v1/chat/completions",
                headers=headers,
                json=body,
            )
        except httpx.HTTPError as exc:
            raise HTTPException(
                status_code=502,
                detail={"message": "Erreur réseau OpenRouter", "error": str(exc)},
            )

    if response.status_code >= 400:
        try:
            error_body = response.json()
        except ValueError:
            error_body = {"raw": response.text}
        raise HTTPException(
            status_code=500,
            detail={
                "message": "Erreur OpenRouter",
                "status_code": response.status_code,
                "error": error_body,
            },
        )

    data = response.json()
    try:
        return data["choices"][0]["message"]["content"]
    except Exception:
        raise HTTPException(
            status_code=500,
            detail={"message": "Réponse OpenRouter inattendue", "raw": data},
        )


async def wrap_with_openrouter_style(base_message: str, user_message: str) -> str:
    if not OPENROUTER_API_KEY:
        return base_message

    reformulation_system_prompt = (
        "Tu es Bobodo, un assistant IA pour le projet Academia. "
        "On te fournit un 'message de base' dans le contexte. Ce message contient exactement le contenu factuel que tu dois transmettre à l'utilisateur. "
        "Ta tâche est de le reformuler en français naturel, clair et bienveillant, en t'adaptant au ton et à l'humeur de l'utilisateur, mais SANS ajouter de nouveaux faits, chiffres, promesses ou spéculations. "
        "Tu ne dois PAS inventer d'informations supplémentaires, ni élargir le sujet au-delà de ce qui est contenu dans ce message de base."
    )

    knowledge = [
        {
            "title": "message_de_base",
            "content": base_message,
        }
    ]

    return await call_openrouter(
        user_message,
        knowledge,
        system_prompt=reformulation_system_prompt,
        include_no_answer_sentinel=False,
    )


async def call_openrouter_safety_refusal(message: str) -> str:
    if not OPENROUTER_API_KEY:
        return (
            "Je ne peux pas répondre à cette question car elle concerne un domaine sensible "
            "(sécurité, terrorisme, piratage, politique, etc.). "
            "Pour des raisons de sécurité et de conformité, Bobodo n'est pas autorisé à traiter ce type de demande."
        )

    safety_system_prompt = (
        "Tu es Bobodo, un assistant IA pour le projet Academia. "
        "Pour des raisons de sécurité, de conformité et d'éthique, tu dois refuser toute question liée au terrorisme, "
        "à la violence, au piratage informatique, aux activités illégales, à la sécurité nationale, à la haine, "
        "ou aux manipulations politiques ou sociales. "
        "Quand une telle question est détectée, tu dois répondre en français, de manière claire et bienveillante, "
        "que tu ne peux pas aider sur ce sujet et inviter l'utilisateur à se tourner vers les canaux officiels. "
        "Ne fournis aucun détail technique, aucune instruction pratique et aucun conseil opérationnel."
    )

    return await call_openrouter(
        message,
        [],
        system_prompt=safety_system_prompt,
        include_no_answer_sentinel=False,
    )


async def generate_answer_with_fallback(
    message: str,
    knowledge: List[Dict[str, Any]],
    session_id: str,
) -> str:
    primary_answer = await call_openrouter(
        message,
        knowledge,
        system_prompt=None,
        include_no_answer_sentinel=True,
    )
    if NO_ANSWER_SENTINEL not in primary_answer:
        return primary_answer

    web_results: List[Dict[str, Any]] = []
    try:
        web_results = await perform_web_search(message)
    except HTTPException:
        web_results = []

    if not web_results:
        await log_unanswered_question(
            session_id,
            message,
            CATEGORY_ORIENTATION_ETUDES_EMPLOI,
        )
        base_message = (
            "Je n'ai pas trouvé d'information fiable sur cette question, "
            "ni dans la base de connaissances interne Nexiom/Academia ni via la recherche web. "
            "Je te recommande d'écrire à l'administrateur de la plateforme Academia (via la messagerie "
            "ou les contacts indiqués) pour exposer ta demande et voir si une solution peut être trouvée."
        )
        return await wrap_with_openrouter_style(base_message, message)

    web_knowledge: List[Dict[str, Any]] = []
    for item in web_results:
        web_knowledge.append(
            {
                "title": item.get("title") or "",
                "content": f"{item.get('snippet') or ''}\nSource: {item.get('url') or ''}",
                "category": "websearch",
            }
        )

    combined_knowledge = knowledge[:5] + web_knowledge
    secondary_answer = await call_openrouter(
        message,
        combined_knowledge,
        system_prompt=None,
        include_no_answer_sentinel=True,
    )

    if NO_ANSWER_SENTINEL in secondary_answer:
        await log_unanswered_question(
            session_id,
            message,
            CATEGORY_ORIENTATION_ETUDES_EMPLOI,
        )
        base_message = (
            "Même après consultation de sources externes, je ne dispose pas d'information "
            "suffisamment fiable pour répondre à cette question. "
            "Je te recommande d'écrire à l'administrateur de la plateforme Academia (via la messagerie "
            "ou les contacts indiqués) pour exposer ta demande et voir si une solution peut être trouvée."
        )
        return await wrap_with_openrouter_style(base_message, message)

    return secondary_answer


async def generate_answer_for_category(
    message: str,
    category: str,
    knowledge: List[Dict[str, Any]],
    session_id: str,
) -> str:
    # Catégorie small talk / émotions : conversation humaine dans le cadre d'Academia
    if category == CATEGORY_SMALL_TALK_EMOTION:
        smalltalk_system_prompt = (
            "Tu es Bobodo, un assistant IA pour le projet Academia. "
            "Tu dois répondre aux salutations, remerciements, compliments et émotions des étudiants "
            "de manière chaleureuse, respectueuse et bienveillante, tout en rappelant si nécessaire "
            "que ton rôle principal est d'aider sur Nexiom Group, la plateforme Academia, l'orientation et l'emploi. "
            "Ne donne pas d'avis médical, juridique ou psychologique."
        )
        answer = await call_openrouter(
            message,
            [],
            system_prompt=smalltalk_system_prompt,
            include_no_answer_sentinel=False,
        )
        return answer

    # Questions internes Nexiom/Academia : base locale uniquement, pas de WebSearch
    if category == CATEGORY_NEXIOM_ACADEMIA_INTERNE:
        if knowledge:
            internal_system_prompt = (
                "Tu es Bobodo, un assistant IA pour Nexiom Group et la plateforme Academia. "
                "Tu dois répondre UNIQUEMENT en te basant sur le contexte interne fourni (connaissance Nexiom/Academia). "
                "Tu peux reformuler, structurer et clarifier, mais tu ne dois pas inventer d'informations ni extrapoler. "
                "Si le contexte ne contient pas assez d'informations pour répondre précisément, "
                f"réponds EXACTEMENT par {NO_ANSWER_SENTINEL} et rien d'autre. "
                "Quand c'est utile pour mieux comprendre la situation de l'utilisateur dans le cadre de Nexiom/Academia, "
                "tu peux, après ta réponse principale, proposer UNE SEULE question ouverte et courte, sans demander de données personnelles sensibles."
            )
            answer = await call_openrouter(
                message,
                knowledge,
                system_prompt=internal_system_prompt,
                include_no_answer_sentinel=True,
            )
        else:
            answer = NO_ANSWER_SENTINEL

        normalized = answer.strip()
        if NO_ANSWER_SENTINEL in normalized:
            await log_unanswered_question(session_id, message, CATEGORY_NEXIOM_ACADEMIA_INTERNE)
            cleaned = normalized.replace(NO_ANSWER_SENTINEL, "").strip()
            if cleaned:
                return cleaned

            # Contexte interne insuffisant : log + réponse neutre reformulée par OpenRouter
            base_message = (
                "Je n'ai pas encore suffisamment d'informations internes pour répondre précisément à cette question "
                "sur Nexiom Group ou la plateforme Academia. Cette demande sera transmise à l'équipe en charge du contenu."
            )
            return await wrap_with_openrouter_style(base_message, message)

        if should_append_admin_contact_hint(message):
            suffix = (
                "\n\nSi tu ne trouves pas une formation précise sur la plateforme Academia et qu'elle n'est pas "
                "diplômante, tu peux écrire à l'administrateur de la plateforme Academia pour que ta demande soit "
                "étudiée."
            )
            return answer.rstrip() + "\n\n" + suffix

        return answer

    # Orientation / études / emploi : pipeline complet local + OpenRouter + WebSearch
    if category == CATEGORY_ORIENTATION_ETUDES_EMPLOI:
        answer = await generate_answer_with_fallback(message, knowledge, session_id)
        if should_append_admin_contact_hint(message):
            suffix = (
                "\n\nSi tu ne trouves pas une formation précise sur la plateforme Academia et qu'elle n'est pas "
                "diplômante, tu peux écrire à l'administrateur de la plateforme Academia pour que ta demande soit "
                "étudiée."
            )
            return answer.rstrip() + "\n\n" + suffix

        return answer

    # Université partenaire : description générale sans détails contractuels, pas de WebSearch
    if category == CATEGORY_PARTENAIRE_UNIVERSITE_DETAILLEE:
        if knowledge:
            partner_system_prompt = (
                "Tu es Bobodo, un assistant IA pour le projet Academia. "
                "L'utilisateur pose une question détaillée sur une université ou un centre de formation partenaire. "
                "Tu peux donner UNE DESCRIPTION GÉNÉRALE basée sur le contexte (présentation globale, localisation, type de partenariats), "
                "mais tu NE DOIS PAS fournir de chiffres exacts (frais, durées, quotas), ni de conditions d'admission contractuelles, "
                "ni promettre quoi que ce soit au nom de l'université. "
                "Invite toujours l'utilisateur à consulter la section 'Universités partenaires' dans Academia "
                "ou à poser ses questions à l'équipe lors de sa candidature."
            )
            return await call_openrouter(
                message,
                knowledge,
                system_prompt=partner_system_prompt,
                include_no_answer_sentinel=False,
            )

        base_message = (
            "Pour les détails sur cette université partenaire (programmes, frais, conditions), "
            "je t'invite à consulter la section 'Universités partenaires' dans la plateforme Academia "
            "ou à poser tes questions à l'équipe lors du dépôt de ta candidature."
        )
        return await wrap_with_openrouter_style(base_message, message)

    # Autre université ou entreprise (non partenaire / concurrent) : refus poli
    if category == CATEGORY_AUTRE_UNIVERSITE_OU_ENTREPRISE:
        base_message = (
            "Je ne peux pas fournir d'informations détaillées ni de comparatifs sur des universités ou entreprises "
            "spécifiques. La politique de Nexiom Group est de proposer des formations à partir de la liste de ses "
            "universités et centres de formation partenaires. Je t'invite à consulter la section 'Universités partenaires' "
            "et 'Centres de formation partenaires' dans la plateforme Academia, puis à regarder les offres de formation "
            "disponibles. Si une université n'apparaît pas dans cette section, cela signifie que Nexiom Group ne peut pas "
            "te proposer de formation via cet établissement. En revanche, tu peux toujours explorer l'ensemble des "
            "formations disponibles sur Academia pour trouver une option qui te convient."
        )
    # HORS_SCOPE ou catégorie inconnue : refuser poliment car hors domaine
    await log_unanswered_question(session_id, message, category)
    base_message = (
        "Je suis un assistant spécialisé pour Nexiom Group, la plateforme Academia, l'orientation et l'emploi. "
        "Cette question sort de mon domaine de compétence, je ne peux donc pas y répondre."
    )
    return await wrap_with_openrouter_style(base_message, message)


@app.post("/studio/audio/render", response_model=StudioAudioRenderResponse)
async def studio_audio_render(req: StudioAudioRenderRequest, request: Request) -> StudioAudioRenderResponse:
    auth_header = request.headers.get("authorization") or request.headers.get("Authorization")
    if not auth_header or not auth_header.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Authorization Bearer manquant pour le rendu audio.")

    user_jwt = auth_header.split(" ", 1)[1].strip()
    if not user_jwt:
        raise HTTPException(status_code=401, detail="JWT utilisateur invalide pour le rendu audio.")

    participation_id = req.participation_id.strip()
    if not participation_id:
        raise HTTPException(status_code=400, detail="participation_id manquant pour le rendu audio.")

    video = await get_challenge_video_for_user(user_jwt, participation_id)

    video_url_raw = video.get("video_url")
    video_url = str(video_url_raw or "").strip()
    if not video_url:
        raise HTTPException(status_code=400, detail="Aucune URL vidéo disponible pour cette participation.")

    tracks_payload: List[Dict[str, Any]] = []
    for track in req.tracks:
        asset_url = (track.asset_url or "").strip()
        if not asset_url:
            continue
        track_dict: Dict[str, Any] = {"asset_url": asset_url}
        if track.start_ms is not None:
            track_dict["start_ms"] = int(track.start_ms)
        if track.end_ms is not None:
            track_dict["end_ms"] = int(track.end_ms)
        if track.volume_db is not None:
            track_dict["volume_db"] = float(track.volume_db)
        if track.kind is not None:
            kind_val = track.kind.strip()
            if kind_val:
                track_dict["kind"] = kind_val
        tracks_payload.append(track_dict)

    job_id = await create_render_job(
        participation_id=participation_id,
        job_type="audio_mix",
        source_video_url=video_url,
        metadata={"track_count": len(tracks_payload)},
    )

    try:
        rendered_url = await call_studio_audio_mix(
            video_url=video_url,
            tracks=tracks_payload,
            normalize=req.normalize,
        )
    except HTTPException as exc:
        detail = exc.detail
        msg: Optional[str] = None
        if isinstance(detail, dict):
            msg = str(detail.get("message") or "")
        await update_render_job(job_id, status="failed", error_message=msg)
        raise

    await update_render_job(job_id, status="completed", result_video_url=rendered_url)

    add_result = await call_supabase_rpc_as_user(
        user_jwt,
        "app_student_add_challenge_video",
        {
            "p_participation_id": participation_id,
            "p_video_url": rendered_url,
            "p_thumbnail_url": None,
        },
    )

    if not isinstance(add_result, dict) or not add_result.get("success"):
        error_code = None
        if isinstance(add_result, dict):
            error_code = add_result.get("error")
        raise HTTPException(
            status_code=500,
            detail={
                "message": "Erreur lors de l'enregistrement de la vidéo mixée.",
                "error": error_code or "unknown_error",
            },
        )

    added_video_id = None
    raw_id = None
    if isinstance(add_result, dict):
        raw_id = add_result.get("video_id")
    if isinstance(raw_id, str):
        added_video_id = raw_id

    return StudioAudioRenderResponse(
        success=True,
        participation_id=participation_id,
        video_url=rendered_url,
        added_video_id=added_video_id,
    )


@app.post("/studio/video/render", response_model=StudioVideoRenderResponse)
async def studio_video_render(req: StudioVideoRenderRequest, request: Request) -> StudioVideoRenderResponse:
    auth_header = request.headers.get("authorization") or request.headers.get("Authorization")
    if not auth_header or not auth_header.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Authorization Bearer manquant pour le rendu vidéo.")

    user_jwt = auth_header.split(" ", 1)[1].strip()
    if not user_jwt:
        raise HTTPException(status_code=401, detail="JWT utilisateur invalide pour le rendu vidéo.")

    participation_id = req.participation_id.strip()
    if not participation_id:
        raise HTTPException(status_code=400, detail="participation_id manquant pour le rendu vidéo.")

    video = await get_challenge_video_for_user(user_jwt, participation_id)

    video_url_raw = video.get("video_url")
    video_url = str(video_url_raw or "").strip()
    if not video_url:
        raise HTTPException(status_code=400, detail="Aucune URL vidéo disponible pour cette participation.")

    overlays = video.get("overlays")
    if not isinstance(overlays, dict):
        overlays = {}

    metadata: Dict[str, Any] = {
        "has_layers": bool(overlays.get("layers")),
        "has_texts": bool(overlays.get("texts")),
        "has_subtitles": bool(overlays.get("subtitles")),
        "has_ar_objects": bool(overlays.get("ar_objects")),
    }

    job_id = await create_render_job(
        participation_id=participation_id,
        job_type="video_edit",
        source_video_url=video_url,
        metadata=metadata,
    )

    try:
        render_payload = await call_studio_video_render(
            video_url=video_url,
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
        msg = "URL vidéo rendue manquante dans la réponse du service Studio vidéo."
        await update_render_job(job_id, status="failed", error_message=msg)
        raise HTTPException(status_code=500, detail={"message": msg})

    await update_render_job(job_id, status="completed", result_video_url=rendered_url)

    add_result = await call_supabase_rpc_as_user(
        user_jwt,
        "app_student_add_challenge_video",
        {
            "p_participation_id": participation_id,
            "p_video_url": rendered_url,
            "p_thumbnail_url": None,
        },
    )

    if not isinstance(add_result, dict) or not add_result.get("success"):
        error_code = None
        if isinstance(add_result, dict):
            error_code = add_result.get("error")
        raise HTTPException(
            status_code=500,
            detail={
                "message": "Erreur lors de l'enregistrement de la vidéo montée.",
                "error": error_code or "unknown_error",
            },
        )

    try:
        await call_supabase_rpc_as_user(
            user_jwt,
            "app_student_set_challenge_main_video",
            {
                "p_participation_id": participation_id,
                "p_video_url": rendered_url,
                "p_video_renditions": video_renditions or None,
            },
        )
    except HTTPException:
        pass

    added_video_id = None
    raw_id = None
    if isinstance(add_result, dict):
        raw_id = add_result.get("video_id")
    if isinstance(raw_id, str):
        added_video_id = raw_id

    return StudioVideoRenderResponse(
        success=True,
        participation_id=participation_id,
        video_url=rendered_url,
        added_video_id=added_video_id,
    )


@app.post("/studio/ai/transcribe", response_model=StudioTranscriptionResponse)
async def studio_ai_transcribe(req: StudioTranscriptionRequest, request: Request) -> StudioTranscriptionResponse:
    auth_header = request.headers.get("authorization") or request.headers.get("Authorization")
    if not auth_header or not auth_header.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Authorization Bearer manquant pour la transcription.")

    user_jwt = auth_header.split(" ", 1)[1].strip()
    if not user_jwt:
        raise HTTPException(status_code=401, detail="JWT utilisateur invalide pour la transcription.")

    participation_id = req.participation_id.strip()
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
        participation_id=participation_id,
        subtitles=subtitles,
        overlays=new_overlays,
    )


@app.post("/studio/ai/analyze", response_model=StudioAnalyzeResponse)
async def studio_ai_analyze(req: StudioAnalyzeRequest, request: Request) -> StudioAnalyzeResponse:
    auth_header = request.headers.get("authorization") or request.headers.get("Authorization")
    if not auth_header or not auth_header.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Authorization Bearer manquant pour l'analyse.")

    user_jwt = auth_header.split(" ", 1)[1].strip()
    if not user_jwt:
        raise HTTPException(status_code=401, detail="JWT utilisateur invalide pour l'analyse.")

    participation_id = req.participation_id.strip()
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
        knowledge.append({"title": "meta_challenge", "content": "\n".join(metadata_parts)})

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
        participation_id=participation_id,
        analysis=analysis,
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


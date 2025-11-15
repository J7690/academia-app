import os
from pathlib import Path
from typing import Any, Dict, List, Optional

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import httpx
from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent
load_dotenv(BASE_DIR / ".env")

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_KEY = os.getenv("SUPABASE_SERVICE_KEY")
OPENROUTER_API_KEY = os.getenv("OPENROUTER_API_KEY")
OPENROUTER_MODEL = os.getenv("OPENROUTER_MODEL", "meta-llama/Meta-Llama-3.1-70B-Instruct")
WEBSEARCH_API_KEY = os.getenv("WEBSEARCH_API_KEY")
WEBSEARCH_ENGINE = os.getenv("WEBSEARCH_ENGINE")

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


class BobodoChatRequest(BaseModel):
    session_id: Optional[str]
    message: str


class BobodoChatResponse(BaseModel):
    session_id: str
    assistant_message: str


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


async def search_knowledge(query: str) -> List[Dict[str, Any]]:
    """Recherche dans la base de connaissances Bobodo via la RPC app_search_bobodo_knowledge."""
    if not query.strip():
        return []

    data = await call_supabase_rpc(
        "app_search_bobodo_knowledge",
        {"p_query": query, "p_category": None},
    )

    if isinstance(data, list):
        return data

    # Certains retours JSONB peuvent être encapsulés
    if isinstance(data, dict) and "result" in data and isinstance(data["result"], list):
        return data["result"]

    return []


async def call_openrouter(message: str, knowledge: List[Dict[str, Any]]) -> str:
    """Appelle OpenRouter pour générer une réponse d'IA en français, avec contexte."""
    if not OPENROUTER_API_KEY:
        # Mode dégradé en développement si la clé n'est pas définie
        return (
            "Je suis Bobodo en mode développement (clé OpenRouter manquante). "
            "Merci de configurer OPENROUTER_API_KEY dans le fichier .env."
        )

    # Construire le contexte à partir de la base de connaissances
    context_chunks: List[str] = []
    for item in knowledge[:5]:
        title = str(item.get("title") or "")
        content = str(item.get("content") or "")
        context_chunks.append(f"[{title}]\n{content}")

    context_text = "\n\n".join(context_chunks) or "Aucune connaissance spécifique trouvée."

    system_prompt = (
        "Tu es Bobodo, un assistant IA pour le projet Academia. "
        "Tu aides les étudiants sur les études, les candidatures, les cours et les offres. "
        "Réponds toujours en français, de manière claire, structurée et bienveillante. "
        "Si une information n'est pas disponible, dis-le honnêtement."
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

    # 3) Génération de la réponse IA
    assistant_message = await call_openrouter(message, knowledge)

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


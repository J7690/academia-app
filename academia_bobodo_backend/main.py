import os
from pathlib import Path
from typing import Any, Dict, List, Optional

from fastapi import FastAPI, HTTPException, Request, Response
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

    # Copie des en-têtes de la requête entrante
    incoming_headers = dict(request.headers)
    # Nettoyage des en-têtes qui ne doivent pas être forwardés tels quels
    for h in ("host", "content-length", "connection"):
        incoming_headers.pop(h, None)

    # Ajout / surcharge des en-têtes Supabase nécessaires
    incoming_headers["apikey"] = SUPABASE_SERVICE_KEY
    incoming_headers["Authorization"] = f"Bearer {SUPABASE_SERVICE_KEY}"

    body = await request.body()

    async with httpx.AsyncClient(timeout=30.0) as client:
        try:
            upstream_response = await client.request(
                request.method,
                target_url,
                headers=incoming_headers,
                content=body if request.method.upper() != "GET" else None,
            )
        except httpx.HTTPError as exc:
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
        return await wrap_with_openrouter_style(base_message, message)

    # HORS_SCOPE ou catégorie inconnue : refuser poliment car hors domaine
    await log_unanswered_question(session_id, message, category)
    base_message = (
        "Je suis un assistant spécialisé pour Nexiom Group, la plateforme Academia, l'orientation et l'emploi. "
        "Cette question sort de mon domaine de compétence, je ne peux donc pas y répondre."
    )
    return await wrap_with_openrouter_style(base_message, message)


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


from __future__ import annotations

from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
main_path = BASE_DIR / "academia_bobodo_backend" / "main.py"

IMPORT_OLD = "from fastapi import FastAPI, HTTPException\n"
IMPORT_NEW = "from fastapi import FastAPI, HTTPException, Request, Response\n"

APP_ANCHOR = """app = FastAPI(\n    title=\"Academia Bobodo Backend\",\n    description=\"Backend FastAPI pour l'assistant Bobodo (Supabase + OpenRouter + websearch)\",\n)\n\napp.add_middleware(\n    CORSMiddleware,\n    allow_origins=[\"*\"],\n    allow_credentials=True,\n    allow_methods=[\"*\"],\n    allow_headers=[\"*\"],\n)\n"""

ROUTE_CODE = '''\n\n@app.api_route("/supabase/{full_path:path}", methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"])
async def supabase_proxy(full_path: str, request: Request) -> Response:
    """\n    Proxy HTTP générique vers l'API Supabase pour contourner les problèmes de résolution DNS côté client.\n\n    Toutes les requêtes envoyées par les applications vers /supabase/... sont relayées vers\n    SUPABASE_URL/... avec les bons en-têtes d'authentification.\n    """\n    if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
        raise HTTPException(
            status_code=500,
            detail="SUPABASE_URL ou SUPABASE_SERVICE_KEY non configurée côté backend.",
        )
\n    supabase_base = SUPABASE_URL.rstrip("/")
    target_url = f"{supabase_base}/{full_path}"
    query = request.url.query
    if query:
        target_url = f"{target_url}?{query}"
\n    # Copie des en-têtes de la requête entrante
    incoming_headers = dict(request.headers)
    # Nettoyage des en-têtes qui ne doivent pas être forwardés tels quels
    for h in ("host", "content-length", "connection"):
        incoming_headers.pop(h, None)
\n    # Ajout / surcharge des en-têtes Supabase nécessaires
    incoming_headers["apikey"] = SUPABASE_SERVICE_KEY
    incoming_headers["Authorization"] = f"Bearer {SUPABASE_SERVICE_KEY}"
\n    body = await request.body()
\n    async with httpx.AsyncClient(timeout=30.0) as client:
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
\n    # Filtrer certains en-têtes de réponse problématiques pour FastAPI
    excluded_headers = {"content-encoding", "transfer-encoding", "connection"}
    response_headers = {
        k: v for k, v in upstream_response.headers.items() if k.lower() not in excluded_headers
    }
\n    return Response(
        content=upstream_response.content,
        status_code=upstream_response.status_code,
        headers=response_headers,
        media_type=upstream_response.headers.get("content-type"),
    )
'''


def main() -> int:
    text = main_path.read_text(encoding="utf-8")

    if "def supabase_proxy(" in text:
        print("supabase_proxy already present in main.py")
        return 0

    if IMPORT_NEW not in text:
        if IMPORT_OLD not in text:
            print("FastAPI import anchor not found in main.py")
            return 1
        text = text.replace(IMPORT_OLD, IMPORT_NEW)

    if APP_ANCHOR not in text:
        print("FastAPI app anchor block not found in main.py")
        return 1

    new_text = text.replace(APP_ANCHOR, APP_ANCHOR + ROUTE_CODE + "\n")
    main_path.write_text(new_text, encoding="utf-8")
    print("Patched main.py with supabase_proxy route")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

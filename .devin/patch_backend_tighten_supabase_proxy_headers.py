from __future__ import annotations

from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
main_path = BASE_DIR / "academia_bobodo_backend" / "main.py"

OLD_HEADERS_BLOCK = '''    # Copie des en-têtes de la requête entrante
    incoming_headers = dict(request.headers)
    # Nettoyage des en-têtes qui ne doivent pas être forwardés tels quels
    for h in ("host", "content-length", "connection"):
        incoming_headers.pop(h, None)

    # Ajout / surcharge des en-têtes Supabase nécessaires
    incoming_headers["apikey"] = SUPABASE_SERVICE_KEY
    incoming_headers["Authorization"] = f"Bearer {SUPABASE_SERVICE_KEY}"
'''

NEW_HEADERS_BLOCK = '''    # Construction d'en-têtes propres pour l'appel vers Supabase.
    # On ne relaie pas les en-têtes spécifiques navigateur (Origin, Sec-*, User-Agent, etc.)
    # pour éviter les 400 HTML côté Cloudflare et limiter les informations exposées.
    outgoing_headers: Dict[str, str] = {
        "apikey": SUPABASE_SERVICE_KEY,
        "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
    }

    content_type = request.headers.get("content-type")
    if content_type:
        outgoing_headers["content-type"] = content_type

    accept = request.headers.get("accept")
    if accept:
        outgoing_headers["accept"] = accept

    range_header = request.headers.get("range")
    if range_header:
        outgoing_headers["range"] = range_header
'''


OLD_REQUEST_CALL = '                headers=incoming_headers,\n'
NEW_REQUEST_CALL = '                headers=outgoing_headers,\n'


def main() -> int:
    text = main_path.read_text(encoding="utf-8")

    if "outgoing_headers: Dict[str, str]" in text:
        print("supabase_proxy headers already tightened in main.py")
        return 0

    if OLD_HEADERS_BLOCK not in text:
        print("Original headers block for supabase_proxy not found in main.py")
        return 1

    text = text.replace(OLD_HEADERS_BLOCK, NEW_HEADERS_BLOCK)

    if OLD_REQUEST_CALL not in text:
        print("Original request call using incoming_headers not found in main.py")
        return 1

    text = text.replace(OLD_REQUEST_CALL, NEW_REQUEST_CALL)

    main_path.write_text(text, encoding="utf-8")
    print("Patched supabase_proxy to use minimal outgoing headers")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

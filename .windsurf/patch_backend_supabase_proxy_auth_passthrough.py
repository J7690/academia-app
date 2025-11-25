from __future__ import annotations

from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
main_path = BASE_DIR / "academia_bobodo_backend" / "main.py"

OLD_BLOCK = '''    # Construction d'en-têtes propres pour l'appel vers Supabase.
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

NEW_BLOCK = '''    # Construction d'en-têtes propres pour l'appel vers Supabase.
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
'''


def main() -> int:
    text = main_path.read_text(encoding="utf-8")

    if "incoming_auth = request.headers.get(\"authorization\")" in text:
        print("supabase_proxy auth passthrough already applied in main.py")
        return 0

    if OLD_BLOCK not in text:
        print("Original headers construction block not found in main.py")
        return 1

    new_text = text.replace(OLD_BLOCK, NEW_BLOCK)
    main_path.write_text(new_text, encoding="utf-8")
    print("Patched supabase_proxy to preserve Authorization from client when present")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

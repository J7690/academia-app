#!/usr/bin/env python3
"""Test simple du proxy Supabase exposé par le backend Bobodo sur Railway.

- Vérifie que l'URL /supabase/auth/v1/health répond bien via le backend.
- Utilise uniquement requests, comme les autres scripts de test .windsurf.
"""

from __future__ import annotations

import json

import requests

# URL du backend Bobodo déployé sur Railway
BACKEND_BASE_URL = "https://academia-app-production.up.railway.app"


def main() -> int:
    url = f"{BACKEND_BASE_URL}/supabase/auth/v1/health"
    print("[TEST] Proxy Supabase health:", url)

    try:
        resp = requests.get(url, timeout=20)
    except Exception as exc:  # pragma: no cover
        print("[ERROR] Exception réseau:", repr(exc))
        return 1

    print("[STATUS]", resp.status_code)
    # On affiche une version compacte du body pour inspection
    text = resp.text
    if len(text) > 800:
        text = text[:800] + "... (troncature)"
    try:
        data = resp.json()
        print("[BODY] JSON:", json.dumps(data, ensure_ascii=False, indent=2)[:800])
    except Exception:
        print("[BODY] RAW:", text)

    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())

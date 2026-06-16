#!/usr/bin/env python3
"""Test d'authentification Supabase via le proxy backend (/supabase/auth/v1/token).

Objectif: reproduire exactement l'appel de login (grant_type=password) que fait Flutter,
mais en passant par le proxy Python sur Railway, et inspecter la réponse brute.
"""

from __future__ import annotations

import json
from typing import Any, Dict

import requests

# Même compte de dev que les autres tests .windsurf
DEV_STUDENT_EMAIL = "nexiomgroup@gmail.com"
DEV_STUDENT_PASSWORD = "Wenden@Koote3"

# URL du proxy backend sur Railway
BACKEND_PROXY_AUTH_URL = (
    "https://academia-app-production.up.railway.app/"
    "supabase/auth/v1/token?grant_type=password"
)

# Clé anon publique (déjà utilisée dans d'autres scripts .windsurf)
SUPABASE_ANON_KEY = (
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9."
    "eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMwNTY1NjAsImV4cCI6MjA3ODYzMjU2MH0."
    "8Zm6i6UaOrEOUvOafHOXOf0UiPOdp7on-aajYASOdk8"
)


def main() -> int:
    headers: Dict[str, str] = {
        "apikey": SUPABASE_ANON_KEY,
        "Content-Type": "application/json",
        "Accept": "application/json",
    }
    payload: Dict[str, Any] = {
        "email": DEV_STUDENT_EMAIL,
        "password": DEV_STUDENT_PASSWORD,
    }

    print("[TEST] POST", BACKEND_PROXY_AUTH_URL)
    print("[HEADERS]", headers)
    print("[BODY]", payload)

    try:
        resp = requests.post(
            BACKEND_PROXY_AUTH_URL,
            headers=headers,
            json=payload,
            timeout=30,
        )
    except Exception as exc:  # pragma: no cover
        print("[ERROR] Exception réseau:", repr(exc))
        return 1

    print("[STATUS]", resp.status_code)
    print("[RESP_HEADERS]")
    for k, v in resp.headers.items():
        print(f"  {k}: {v}")

    text = resp.text
    if len(text) > 2000:
        text = text[:2000] + "... (troncature)"

    try:
        data = resp.json()
        print("[RESP_BODY_JSON]", json.dumps(data, ensure_ascii=False, indent=2)[:2000])
    except Exception:
        print("[RESP_BODY_RAW]", text)

    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())

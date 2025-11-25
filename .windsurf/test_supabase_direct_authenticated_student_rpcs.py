#!/usr/bin/env python3
"""Audit direct Supabase (sans proxy) avec authentification étudiant.

Objectif:
- Se connecter en tant qu'étudiant (email/password) directement sur Supabase.
- Récupérer un access_token (JWT).
- Appeler quelques RPC clés sans passer par le proxy pour voir si `not_authenticated` disparaît.

Aucune modification n'est faite côté base, on ne fait que des lectures.
"""

from __future__ import annotations

import json
from typing import Any, Dict

import requests

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SUPABASE_ANON_KEY = (
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9."
    "eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMwNTY1NjAsImV4cCI6MjA3ODYzMjU2MH0."
    "8Zm6i6UaOrEOUvOafHOXOf0UiPOdp7on-aajYASOdk8"
)

STUDENT_EMAIL = "nexiomgroup@gmail.com"
STUDENT_PASSWORD = "Wenden@Koote3"


def login_direct() -> str:
    url = f"{SUPABASE_URL}/auth/v1/token?grant_type=password"
    headers = {
        "apikey": SUPABASE_ANON_KEY,
        "Content-Type": "application/json",
        "Accept": "application/json",
    }
    body = {"email": STUDENT_EMAIL, "password": STUDENT_PASSWORD}

    print("[LOGIN_DIRECT] POST", url)
    try:
        resp = requests.post(url, headers=headers, json=body, timeout=30)
    except Exception as exc:  # pragma: no cover
        print("[LOGIN_DIRECT][ERROR]", repr(exc))
        raise

    print("[LOGIN_DIRECT][STATUS]", resp.status_code)
    data = resp.json()
    print("[LOGIN_DIRECT][BODY]", json.dumps(data, ensure_ascii=False, indent=2)[:2000])

    access_token = data.get("access_token")
    if not access_token:
        raise SystemExit("[LOGIN_DIRECT] Pas d'access_token dans la réponse")
    return access_token


def call_rpc_direct(name: str, jwt: str, params: Dict[str, Any] | None = None) -> None:
    url = f"{SUPABASE_URL}/rest/v1/rpc/{name}"
    headers = {
        "apikey": SUPABASE_ANON_KEY,
        "Authorization": f"Bearer {jwt}",
        "Content-Type": "application/json",
        "Accept": "application/json",
    }
    body = params or {}

    print(f"\n[RPC_DIRECT] {name}")
    print("[POST]", url)
    print("[HEADERS]", {k: headers[k] for k in ("apikey", "Authorization", "Content-Type", "Accept")})
    print("[BODY]", body)

    try:
        resp = requests.post(url, headers=headers, json=body, timeout=30)
    except Exception as exc:  # pragma: no cover
        print("[RPC_DIRECT][ERROR]", repr(exc))
        return

    print("[STATUS]", resp.status_code)
    try:
        data = resp.json()
        print("[RESP_BODY_JSON]", json.dumps(data, ensure_ascii=False, indent=2)[:2000])
    except Exception:
        text = resp.text
        if len(text) > 2000:
            text = text[:2000] + "... (troncature)"
        print("[RESP_BODY_RAW]", text)


def main() -> int:
    jwt = login_direct()

    # RPC qui retournait not_authenticated dans les tests automatiques
    call_rpc_direct("app_list_course_library", jwt)

    # RPC d'application étudiant pour vérifier le contexte utilisateur
    call_rpc_direct("app_list_student_applications", jwt)
    call_rpc_direct("app_list_student_courses", jwt)

    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())

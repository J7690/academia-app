#!/usr/bin/env python3
"""Audit Supabase via proxy Railway avec authentification étudiant.

Objectif:
- Se connecter en tant qu'étudiant directement sur Supabase pour obtenir un JWT.
- Réutiliser ce JWT pour appeler les mêmes RPC *via* le proxy
  https://academia-app-production.up.railway.app/supabase/rest/v1/rpc/...
- Comparer comportements direct vs proxy (notamment not_authenticated).

Aucune modification n'est faite côté base (RPC de lecture uniquement).
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

BACKEND_PROXY_BASE = "https://academia-app-production.up.railway.app/supabase/rest/v1/rpc"

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
    resp = requests.post(url, headers=headers, json=body, timeout=30)
    print("[LOGIN_DIRECT][STATUS]", resp.status_code)
    data = resp.json()
    print("[LOGIN_DIRECT][BODY]", json.dumps(data, ensure_ascii=False, indent=2)[:2000])

    access_token = data.get("access_token")
    if not access_token:
        raise SystemExit("[LOGIN_DIRECT] Pas d'access_token dans la réponse")
    return access_token


def call_rpc_via_proxy(name: str, jwt: str, params: Dict[str, Any] | None = None) -> None:
    url = f"{BACKEND_PROXY_BASE}/{name}"
    headers = {
        "apikey": SUPABASE_ANON_KEY,
        # On envoie ici le JWT étudiant comme le ferait Supabase Flutter.
        "Authorization": f"Bearer {jwt}",
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Origin": "http://localhost:54964",  # origine similaire à ton environnement dev
    }
    body = params or {}

    print(f"\n[RPC_PROXY] {name}")
    print("[POST]", url)
    print("[HEADERS]", {k: headers[k] for k in ("apikey", "Authorization", "Content-Type", "Accept", "Origin")})
    print("[BODY]", body)

    try:
        resp = requests.post(url, headers=headers, json=body, timeout=30)
    except Exception as exc:  # pragma: no cover
        print("[RPC_PROXY][ERROR]", repr(exc))
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

    # Même panel de RPC que pour le test direct.
    call_rpc_via_proxy("app_list_course_library", jwt)
    call_rpc_via_proxy("app_list_student_applications", jwt)
    call_rpc_via_proxy("app_list_student_courses", jwt)

    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())

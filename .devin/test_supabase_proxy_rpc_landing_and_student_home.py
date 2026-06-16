#!/usr/bin/env python3
"""Tests des RPC de landing et d'accueil étudiant via le proxy Supabase interne.

- app_public_landing_content
- app_public_student_home_content

Objectif: vérifier que ces RPC, utilisées sur la page d'accueil, fonctionnent correctement
via le proxy Python sur Railway et renvoient du JSON Supabase valide.
"""

from __future__ import annotations

import json
from typing import Any, Dict

import requests

BACKEND_BASE = "https://academia-app-production.up.railway.app/supabase/rest/v1/rpc"

SUPABASE_ANON_KEY = (
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9."
    "eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMwNTY1NjAsImV4cCI6MjA3ODYzMjU2MH0."
    "8Zm6i6UaOrEOUvOafHOXOf0UiPOdp7on-aajYASOdk8"
)


def call_rpc(name: str, params: Dict[str, Any] | None = None) -> None:
    url = f"{BACKEND_BASE}/{name}"
    headers: Dict[str, str] = {
        "apikey": SUPABASE_ANON_KEY,
        "Content-Type": "application/json",
        "Accept": "application/json",
    }
    body = params or {}

    print("\n[TEST RPC]", name)
    print("[POST]", url)
    print("[HEADERS]", headers)
    print("[BODY]", body)

    try:
        resp = requests.post(url, headers=headers, json=body, timeout=30)
    except Exception as exc:  # pragma: no cover
        print("[ERROR] Exception réseau:", repr(exc))
        return

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


def main() -> int:
    call_rpc("app_public_landing_content")
    call_rpc("app_public_student_home_content")
    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())

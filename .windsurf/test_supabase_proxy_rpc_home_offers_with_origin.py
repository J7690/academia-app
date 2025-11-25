#!/usr/bin/env python3
"""Test de la RPC app_list_home_offers via le proxy, en simulant un appel navigateur.

On ajoute un header Origin similaire à celui d'un front web (http://localhost:XXXX)
pour voir si cela provoque un 400 côté Supabase/Cloudflare.
"""

from __future__ import annotations

import json
from typing import Any, Dict

import requests

BACKEND_PROXY_RPC_URL = (
    "https://academia-app-production.up.railway.app/"
    "supabase/rest/v1/rpc/app_list_home_offers"
)

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
        # Simule un front local en dev
        "Origin": "http://localhost:55968",
    }
    payload: Dict[str, Any] = {}

    print("[TEST] POST", BACKEND_PROXY_RPC_URL)
    print("[HEADERS]", headers)
    print("[BODY]", payload)

    try:
        resp = requests.post(
            BACKEND_PROXY_RPC_URL,
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

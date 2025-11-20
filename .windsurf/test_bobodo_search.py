#!/usr/bin/env python3
"""Test de la RPC app_search_bobodo_knowledge pour les questions Nexiom/Academia.

Utilise la clé service_role (procédure primaire RPC) pour appeler directement la fonction.
"""

from __future__ import annotations

import json

import requests

import auto_supabase_import as sup


def call_search(query: str, category: str | None = None) -> None:
    payload: dict = {"p_query": query, "p_category": category}
    headers = {
        "apikey": sup.SUPABASE_SERVICE_KEY,  # type: ignore[attr-defined]
        "Authorization": f"Bearer {sup.SUPABASE_SERVICE_KEY}",  # type: ignore[attr-defined]
        "Content-Type": "application/json",
        "Accept": "application/json",
    }

    resp = requests.post(
        f"{sup.SUPABASE_URL}/rest/v1/rpc/app_search_bobodo_knowledge",  # type: ignore[attr-defined]
        headers=headers,
        json=payload,
        timeout=20,
    )

    print("=== QUERY:", query, "CATEGORY:", category)
    print("STATUS", resp.status_code)
    try:
        body = resp.json()
        print("BODY", json.dumps(body, ensure_ascii=False, indent=2)[:2000])
    except Exception:
        print("BODY_RAW", resp.text[:2000])


def main() -> int:
    tests = [
        ("nexiom group", None),
        ("nexiom", None),
        ("academia", None),
        ("bobodo", None),
        ("nexiom", "nexiom"),
        ("academia", "academia"),
    ]

    for q, cat in tests:
        call_search(q, cat)
        print()

    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())

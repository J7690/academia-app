#!/usr/bin/env python3
"""Lecture directe de app.bobodo_knowledge via API REST PostgREST.

Utilise la configuration validée d'auto_supabase_import (procédure secondaire .windsurf).
"""

from __future__ import annotations

import json

import requests

import auto_supabase_import as sup


def main() -> int:
    # Construction de l'URL selon _build_table_request (schéma "app")
    base_url = f"{sup.SUPABASE_URL}/rest/v1/bobodo_knowledge"  # type: ignore[attr-defined]

    headers = dict(sup.API_HEADERS)  # type: ignore[attr-defined]
    headers["Accept-Profile"] = "app"
    headers["Content-Profile"] = "app"
    headers.setdefault("Accept", "application/json")

    params = {
        "limit": 20,
        "order": "created_at.desc",
    }

    resp = requests.get(base_url, headers=headers, params=params, timeout=20)
    print("STATUS", resp.status_code)
    try:
        body = resp.json()
        print("BODY", json.dumps(body, ensure_ascii=False, indent=2)[:4000])
    except Exception:
        print("BODY_RAW", resp.text[:4000])

    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())

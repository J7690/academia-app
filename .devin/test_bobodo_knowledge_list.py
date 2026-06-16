#!/usr/bin/env python3
"""Audit de la table app.bobodo_knowledge via RPC execute_sql (procédure .windsurf).

Ce script NE MODIFIE PAS les données, il fait uniquement :
- un SELECT sur app.bobodo_knowledge
- via la fonction RPC execute_sql (service_role)
"""

from __future__ import annotations

import json

import requests

import auto_supabase_import as sup


def main() -> int:
    sql = (
        "SELECT id, category, title, tags, language, is_active, created_at "
        "FROM app.bobodo_knowledge ORDER BY created_at DESC LIMIT 50"
    )

    headers = {
        "apikey": sup.SUPABASE_SERVICE_KEY,  # type: ignore[attr-defined]
        "Authorization": f"Bearer {sup.SUPABASE_SERVICE_KEY}",  # type: ignore[attr-defined]
        "Content-Type": "application/json",
        "Accept": "application/json",
    }

    resp = requests.post(
        f"{sup.SUPABASE_URL}/rest/v1/rpc/execute_sql",  # type: ignore[attr-defined]
        headers=headers,
        json={"sql_query": sql},
        timeout=20,
    )

    print("STATUS", resp.status_code)
    try:
        body = resp.json()
        print("BODY", json.dumps(body, ensure_ascii=False, indent=2)[:4000])
    except Exception:
        print("BODY_RAW", resp.text[:4000])

    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())

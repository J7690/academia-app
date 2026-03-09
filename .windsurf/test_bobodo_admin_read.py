#!/usr/bin/env python3
"""Audit Bobodo via la RPC admin_execute_sql (procédure .windsurf).

- Lit le contenu réel de app.bobodo_knowledge
- Appelle la fonction app_search_bobodo_knowledge côté base

Ce script n'applique aucune modification, il fait uniquement des SELECT.
"""

from __future__ import annotations

import json
from typing import Any

import requests

from auto_supabase_import import SUPABASE_URL, SUPABASE_SERVICE_KEY


HEADERS = {
    "apikey": SUPABASE_SERVICE_KEY,
    "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
    "Content-Type": "application/json",
}


def run_sql(label: str, sql: str) -> None:
    url = f"{SUPABASE_URL}/rest/v1/rpc/admin_execute_sql"
    print("\n===", label, "===")
    print(sql)
    try:
        resp = requests.post(url, headers=HEADERS, json={"p_sql": sql}, timeout=30)
    except Exception as exc:
        print("[ERROR] Exception réseau:", exc)
        return

    print("STATUS", resp.status_code)
    try:
        body: Any = resp.json()
        print("BODY", json.dumps(body, ensure_ascii=False, indent=2)[:4000])
    except Exception:
        print("BODY_RAW", resp.text[:4000])


def main() -> int:
    # 1) Compter et lister les connaissances Bobodo
    run_sql(
        "COUNT app.bobodo_knowledge",
        "SELECT COUNT(*) AS count FROM app.bobodo_knowledge",
    )

    run_sql(
        "LIST app.bobodo_knowledge",
        "SELECT category, title, tags, language, is_active FROM app.bobodo_knowledge ORDER BY created_at DESC LIMIT 20",
    )

    # 2) Tester la fonction app_search_bobodo_knowledge côté base
    run_sql(
        "SEARCH nexion/nexiom",
        "SELECT app_search_bobodo_knowledge('nexiom', NULL) AS result",
    )

    run_sql(
        "SEARCH academia",
        "SELECT app_search_bobodo_knowledge('academia', NULL) AS result",
    )

    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())

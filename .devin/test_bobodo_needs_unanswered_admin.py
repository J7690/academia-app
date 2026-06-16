#!/usr/bin/env python3
"""Audit des besoins détectés et questions non couvertes Bobodo via admin_execute_sql.

- Lit le contenu réel de app.bobodo_detected_needs
- Lit le contenu réel de app.bobodo_unanswered_questions

Ce script suit les procédures .windsurf :
- utilisation de SUPABASE_URL et SUPABASE_SERVICE_KEY
- utilisation de la RPC admin_execute_sql
- uniquement des SELECT (aucune modification de données)
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
    # 1) Compter et lister les besoins détectés
    run_sql(
        "COUNT app.bobodo_detected_needs",
        "SELECT COUNT(*) AS count FROM app.bobodo_detected_needs;",
    )

    run_sql(
        "LIST app.bobodo_detected_needs",
        "SELECT created_at, category, question_text, need_summary FROM app.bobodo_detected_needs ORDER BY created_at DESC LIMIT 20;",
    )

    # 2) Compter et lister les questions non couvertes
    run_sql(
        "COUNT app.bobodo_unanswered_questions",
        "SELECT COUNT(*) AS count FROM app.bobodo_unanswered_questions;",
    )

    run_sql(
        "LIST app.bobodo_unanswered_questions",
        "SELECT created_at, category, status, question_text FROM app.bobodo_unanswered_questions ORDER BY created_at DESC LIMIT 20;",
    )

    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())

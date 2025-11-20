#!/usr/bin/env python3
"""Audit des tables app.bobodo_detected_needs et app.bobodo_unanswered_questions
via la RPC execute_sql (procédure .windsurf).

Ce script NE MODIFIE PAS les données, il fait uniquement des SELECT.
"""

from __future__ import annotations

import json

import requests

import auto_supabase_import as sup


def run_sql(label: str, sql: str) -> None:
    headers = {
        "apikey": sup.SUPABASE_SERVICE_KEY,  # type: ignore[attr-defined]
        "Authorization": f"Bearer {sup.SUPABASE_SERVICE_KEY}",  # type: ignore[attr-defined]
        "Content-Type": "application/json",
        "Accept": "application/json",
    }
    print("\n===", label, "===")
    print(sql)
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


def main() -> int:
    run_sql(
        "LIST app.bobodo_detected_needs",
        "SELECT id, created_at, category, question_text, need_summary FROM app.bobodo_detected_needs ORDER BY created_at DESC LIMIT 20",
    )

    run_sql(
        "LIST app.bobodo_unanswered_questions",
        "SELECT id, created_at, category, status, question_text FROM app.bobodo_unanswered_questions ORDER BY created_at DESC LIMIT 20",
    )

    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())

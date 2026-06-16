#!/usr/bin/env python3
"""Audit des tables et fonctions Supabase liées aux espaces Hero (Hero Studio Télé).

- Utilise la RPC execute_sql (comme audit_challenge_schema.py)
- Ne fait que des SELECT (aucune modification de données)
- Sert de base factuelle avant toute évolution du Hero Studio.
"""

from __future__ import annotations

import json
from typing import Any, Dict, List

import requests

from auto_supabase_import import SUPABASE_URL, RPC_HEADERS

EXECUTE_SQL_URL = f"{SUPABASE_URL}/rest/v1/rpc/execute_sql"


def execute_sql(label: str, sql: str) -> List[Dict[str, Any]]:
    print("\n===", label, "===")
    print(sql)
    resp = requests.post(
        EXECUTE_SQL_URL,
        headers=RPC_HEADERS,
        json={"sql_query": sql},
        timeout=60,
    )
    print("STATUS", resp.status_code)
    try:
        data = resp.json()
    except Exception:
        print("RAW", resp.text[:2000])
        return []

    if isinstance(data, dict) and "error" in data:
        print("ERROR_BODY", json.dumps(data, ensure_ascii=False, indent=2)[:2000])
        return []
    if isinstance(data, list):
        print(json.dumps(data, ensure_ascii=False, indent=2)[:2000])
        return data
    if data is None:
        print("(no rows)")
        return []
    print("UNEXPECTED", repr(data)[:2000])
    return []


def main() -> int:
    # 1) Lister les tables app.hero_*
    execute_sql(
        "TABLES_app_hero",
        """
        SELECT table_schema, table_name
        FROM information_schema.tables
        WHERE table_schema = 'app'
          AND table_name ILIKE 'hero%%'
        ORDER BY table_name
        """,
    )

    # 2) Décrire les tables clés si elles existent
    for table in (
        "hero_playlist",
        "hero_overlays",
        "hero_slots",
    ):
        execute_sql(
            f"COLUMNS_app.{table}",
            f"""
            SELECT column_name, data_type, is_nullable
            FROM information_schema.columns
            WHERE table_schema = 'app'
              AND table_name = '{table}'
            ORDER BY ordinal_position
            """,
        )

    # 3) Lister les fonctions (RPC) contenant 'hero' dans le schéma public
    execute_sql(
        "RPC_public_app_hero_functions",
        """
        SELECT routine_schema, routine_name, routine_type
        FROM information_schema.routines
        WHERE routine_schema = 'public'
          AND routine_name ILIKE 'app%hero%'
        ORDER BY routine_name
        """,
    )

    # 4) Échantillon éventuel des données hero_playlist / hero_overlays
    execute_sql(
        "SAMPLE_app.hero_playlist",
        """
        SELECT *
        FROM app.hero_playlist
        ORDER BY created_at DESC
        LIMIT 10
        """,
    )

    execute_sql(
        "SAMPLE_app.hero_overlays",
        """
        SELECT *
        FROM app.hero_overlays
        ORDER BY updated_at DESC
        LIMIT 10
        """,
    )

    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())

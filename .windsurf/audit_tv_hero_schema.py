#!/usr/bin/env python3
"""Audit des tables et fonctions Supabase liées au Studio Télé Hero.

- Utilise la RPC execute_sql via auto_supabase_import
- Ne fait que des SELECT (aucune modification de données)
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
    # 1) Vérifier l'existence des tables TV
    execute_sql(
        "TABLES_app_hero_tv",
        """
        SELECT table_schema, table_name
        FROM information_schema.tables
        WHERE table_schema = 'app'
          AND table_name IN ('hero_overlays_tv', 'hero_renders_tv')
        ORDER BY table_name
        """,
    )

    # 2) Décrire les colonnes principales
    for table in ("hero_overlays_tv", "hero_renders_tv"):
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

    # 3) Lister les fonctions TV (schémas app et public)
    execute_sql(
        "RPC_app_admin_tv_functions",
        """
        SELECT routine_schema, routine_name, specific_name
        FROM information_schema.routines
        WHERE routine_schema IN ('app', 'public')
          AND routine_name ILIKE 'app_admin_tv%'
        ORDER BY routine_schema, routine_name
        """,
    )

    # 4) Tester l'appel des RPC TV sur un UUID bidon
    execute_sql(
        "TEST_app_admin_tv_get_timeline",
        """
        SELECT public.app_admin_tv_get_timeline('00000000-0000-0000-0000-000000000000') AS result;
        """,
    )

    execute_sql(
        "TEST_app_admin_tv_request_render",
        """
        SELECT public.app_admin_tv_request_render('00000000-0000-0000-0000-000000000000') AS result;
        """,
    )

    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())

#!/usr/bin/env python3
"""Audit Supabase schema/RPCs for University mini-site ability to manage formations (programs).

Uses admin_execute_sql RPC via SupabaseAutoManager.
Outputs:
- Core tables presence
- Columns for app.programs (and related minisite tables)
- Candidate admin/upsert RPCs

No writes are performed.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any, Dict, List

import requests

sys.path.insert(0, str(Path(__file__).parent))
from supabase_auto_manager import SupabaseAutoManager


def exec_sql(manager: SupabaseAutoManager, sql: str) -> List[Dict[str, Any]]:
    url = f"{manager.url}/rest/v1/rpc/admin_execute_sql"
    r = requests.post(url, headers=manager.headers, json={"p_sql": sql}, timeout=45)
    r.raise_for_status()
    data = r.json()
    if isinstance(data, dict) and data.get("ok") is True and data.get("mode") == "select":
        rows = data.get("rows")
        if isinstance(rows, list):
            return rows
    return []


def table_exists(manager: SupabaseAutoManager, schema: str, table: str) -> bool:
    rows = exec_sql(
        manager,
        f"""
        SELECT 1
        FROM information_schema.tables
        WHERE table_schema = '{schema.replace("'", "''")}'
          AND table_name = '{table.replace("'", "''")}'
        LIMIT 1
        """.strip(),
    )
    return bool(rows)


def list_columns(manager: SupabaseAutoManager, schema: str, table: str) -> List[Dict[str, Any]]:
    return exec_sql(
        manager,
        f"""
        SELECT
          column_name,
          data_type,
          is_nullable,
          column_default
        FROM information_schema.columns
        WHERE table_schema = '{schema.replace("'", "''")}'
          AND table_name = '{table.replace("'", "''")}'
        ORDER BY ordinal_position
        """.strip(),
    )


def list_rpcs_like(manager: SupabaseAutoManager, patterns: List[str]) -> List[Dict[str, Any]]:
    cond = " OR ".join(
        [
            "LOWER(p.proname) LIKE '%" + p.lower().replace("'", "''") + "%'"
            for p in patterns
        ]
    )
    return exec_sql(
        manager,
        f"""
        SELECT
          n.nspname AS schema,
          p.proname AS name,
          pg_get_function_identity_arguments(p.oid) AS args
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname IN ('app','public')
          AND ({cond})
        ORDER BY n.nspname, p.proname
        """.strip(),
    )


def main() -> int:
    m = SupabaseAutoManager()

    print("=" * 80)
    print("AUDIT — University mini-site formations capability")
    print(f"Project: {m.url}")
    print("=" * 80)

    core_tables = [
        ("app", "universities"),
        ("app", "programs"),
        ("app", "university_site_config"),
        ("app", "university_site_blocks"),
        ("app", "university_site_banners"),
        ("app", "university_media"),
        ("app", "university_news"),
        ("app", "university_events"),
    ]

    print("\n[CHECK] Core tables existence:")
    core_result: List[Dict[str, Any]] = []
    for schema, table in core_tables:
        exists = table_exists(m, schema, table)
        core_result.append({"schema": schema, "table": table, "exists": exists})
        print(f"  - {schema}.{table}: {'OK' if exists else 'MISSING'}")

    # Columns for programs (formations)
    if table_exists(m, "app", "programs"):
        cols = list_columns(m, "app", "programs")
        print("\n[SCHEMA] app.programs columns:")
        for c in cols:
            print(
                f"  - {c['column_name']} ({c['data_type']}) nullable={c['is_nullable']} default={c['column_default']}"
            )
    else:
        print("\n[SCHEMA] app.programs not found; formations cannot be stored in DB.")

    # Also inspect university_site_config and blocks, since mini-site might render programs through blocks
    for t in ["university_site_config", "university_site_blocks"]:
        if table_exists(m, "app", t):
            cols = list_columns(m, "app", t)
            print(f"\n[SCHEMA] app.{t} columns:")
            for c in cols:
                print(
                    f"  - {c['column_name']} ({c['data_type']}) nullable={c['is_nullable']} default={c['column_default']}"
                )

    # Candidate RPCs
    patterns = [
        "university",
        "site",
        "program",
        "formation",
        "upsert",
        "admin",
    ]
    rpcs = list_rpcs_like(m, patterns)

    print("\n[RPC] Candidate RPCs (app/public) matching patterns:")
    for r in rpcs:
        print(f"  - {r['schema']}.{r['name']}({r['args']})")

    # Quick capability statement inputs
    print("\n[SUMMARY_JSON]")
    print(
        json.dumps(
            {
                "core_tables": core_result,
                "programs_columns_count": len(list_columns(m, "app", "programs"))
                if table_exists(m, "app", "programs")
                else 0,
                "candidate_rpcs_count": len(rpcs),
            },
            indent=2,
            ensure_ascii=False,
        )
    )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

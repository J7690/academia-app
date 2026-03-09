#!/usr/bin/env python3
"""Query university-linked accounts (emails) for IIM, ISTAPEM, UMET Burkina via admin_execute_sql.

Passwords are NOT retrievable in Supabase Auth (hashed) and should not be disclosed.
"""

from __future__ import annotations

import sys
from pathlib import Path
from typing import Any, Dict, List, Tuple

import requests

sys.path.insert(0, str(Path(__file__).parent))
from supabase_auto_manager import SupabaseAutoManager

TARGETS: List[Tuple[str, List[str]]] = [
    ("IIM", ["iim"]),
    ("ISTAPEM", ["istapem"]),
    ("UMET Burkina", ["umet", "burkina"]),
]


def exec_sql(manager: SupabaseAutoManager, sql: str) -> List[Dict[str, Any]]:
    url = f"{manager.url}/rest/v1/rpc/admin_execute_sql"
    r = requests.post(url, headers=manager.headers, json={"p_sql": sql}, timeout=30)
    r.raise_for_status()
    data = r.json()
    if isinstance(data, dict) and data.get("ok") is True and data.get("mode") == "select":
        rows = data.get("rows")
        if isinstance(rows, list):
            return rows
    return []


def build_where(tokens: List[str]) -> str:
    # Search across name/title/slug
    conds: List[str] = []
    for tok in tokens:
        tok_sql = tok.lower().replace("'", "''")
        conds.append(
            "LOWER(COALESCE(name::text, title::text, slug::text, '')) LIKE '%" + tok_sql + "%'"
        )
    return " AND ".join(conds) if conds else "TRUE"


def main() -> int:
    manager = SupabaseAutoManager()

    print("=" * 80)
    print("UNIVERSITY ACCOUNTS (EMAILS) — via admin_execute_sql")
    print(f"Project: {manager.url}")
    print("=" * 80)

    # Universities table
    uni_table = "app.universities"

    # Discover link tables with (university_id, user_id)
    link_tables = exec_sql(
        manager,
        """
        WITH uni_cols AS (
          SELECT table_name
          FROM information_schema.columns
          WHERE table_schema='app'
            AND column_name='university_id'
        ), user_cols AS (
          SELECT table_name
          FROM information_schema.columns
          WHERE table_schema='app'
            AND column_name='user_id'
        )
        SELECT u.table_name
        FROM uni_cols u
        JOIN user_cols x USING(table_name)
        ORDER BY u.table_name
        """.strip(),
    )

    if not link_tables:
        print("\n[ERROR] No link tables with (university_id, user_id) found in app schema.")
        return 1

    # For each target
    for label, tokens in TARGETS:
        where = build_where(tokens)

        print("\n" + "-" * 80)
        print(f"TARGET: {label}")
        print("-" * 80)

        uni_rows = exec_sql(
            manager,
            f"""
            SELECT id, name, slug
            FROM {uni_table}
            WHERE {where}
            ORDER BY created_at DESC NULLS LAST
            LIMIT 20
            """.strip(),
        )

        if not uni_rows:
            print("[RESULT] No matching university rows.")
            continue

        print(f"[RESULT] Matching universities ({len(uni_rows)}):")
        uni_ids: List[str] = []
        for r in uni_rows:
            uni_ids.append(str(r.get("id")))
            print(f"  - id={r.get('id')} name={r.get('name')} slug={r.get('slug')}")

        ids_sql = ",".join(["'" + u.replace("'", "''") + "'" for u in uni_ids])

        any_found = False
        for lt in link_tables:
            ltname = lt.get("table_name")
            if not ltname:
                continue
            link_table = f"app.{ltname}"

            rows = exec_sql(
                manager,
                f"""
                SELECT
                  l.university_id,
                  l.user_id,
                  u.email,
                  u.created_at,
                  u.last_sign_in_at
                FROM {link_table} l
                JOIN auth.users u ON u.id = l.user_id
                WHERE l.university_id IN ({ids_sql})
                ORDER BY u.created_at DESC
                LIMIT 200
                """.strip(),
            )

            if rows:
                any_found = True
                print(f"\n[RESULT] Linked accounts via {link_table} ({len(rows)}):")
                for a in rows:
                    print(
                        f"  - email={a.get('email')} user_id={a.get('user_id')} last_sign_in_at={a.get('last_sign_in_at')}"
                    )

        if not any_found:
            print("[RESULT] No linked accounts found via discovered link tables.")

    print("\n[SECURITY] Passwords are not retrievable from Supabase Auth. Use reset flow instead.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

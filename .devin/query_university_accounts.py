#!/usr/bin/env python3
"""Query university-linked accounts (emails) for IIM, ISTAPEM, UMET Burkina via admin_execute_sql.

Security: does NOT attempt to retrieve passwords (not possible / not appropriate).
"""

from __future__ import annotations

import sys
from pathlib import Path
from typing import Any, Dict, List

import requests

sys.path.insert(0, str(Path(__file__).parent))
from supabase_auto_manager import SupabaseAutoManager

TARGETS = [
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


def main() -> int:
    manager = SupabaseAutoManager()

    print("=" * 80)
    print("UNIVERSITY ACCOUNTS (EMAILS) — via admin_execute_sql")
    print(f"Project: {manager.url}")
    print("=" * 80)

    # 1) Discover university-related tables in app schema
    tables = exec_sql(
        manager,
        """
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = 'app'
          AND table_type = 'BASE TABLE'
          AND table_name ILIKE '%univers%'
        ORDER BY table_name
        """.strip(),
    )

    print("\n[DISCOVERY] app schema tables matching '%univers%':")
    for t in tables:
        print(f"  - {t.get('table_name')}")

    # 2) Find a likely universities table
    uni_candidates = exec_sql(
        manager,
        """
        SELECT table_name
        FROM information_schema.columns
        WHERE table_schema='app'
          AND column_name IN ('name','title','slug')
          AND table_name ILIKE '%univers%'
        GROUP BY table_name
        ORDER BY table_name
        """.strip(),
    )

    print("\n[DISCOVERY] candidate university tables (have name/title/slug):")
    for c in uni_candidates:
        print(f"  - {c.get('table_name')}")

    # Prefer app.universities if present
    uni_table = None
    for c in uni_candidates:
        if c.get("table_name") == "universities":
            uni_table = "app.universities"
            break
    if uni_table is None and uni_candidates:
        uni_table = f"app.{uni_candidates[0]['table_name']}"

    if not uni_table:
        print("\n[ERROR] No university table candidate found in app schema.")
        return 1

    print(f"\n[INFO] Using university table: {uni_table}")

    # 3) Discover link tables containing university_id + user_id
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

    print("\n[DISCOVERY] link tables with (university_id, user_id):")
    for lt in link_tables:
        print(f"  - app.{lt.get('table_name')}")

    # 4) For each target, locate university rows and linked users
    for label, tokens in TARGETS:
        where = " AND ".join([f"LOWER(COALESCE(name::text, title::text, slug::text, '')) LIKE '%{tok}%'"] for tok in tokens)
        # Above line is wrong due to stray bracket; build properly below.

    # Build per-target queries robustly
    for label, tokens in TARGETS:
        conds = []
        for tok in tokens:
            conds.append(
                "LOWER(COALESCE(name::text, title::text, slug::text, '')) LIKE '%" + tok.lower().replace("'", "''") + "%'")
        where = " AND ".join(conds) if conds else "TRUE"

        print("\n" + "-" * 80)
        print(f"TARGET: {label}")
        print("-" * 80)

        # University rows
        uni_rows = exec_sql(
            manager,
            f"""
            SELECT *
            FROM {uni_table}
            WHERE {where}
            ORDER BY 1
            LIMIT 20
            """.strip(),
        )

        if not uni_rows:
            print("[RESULT] No matching university rows.")
            continue

        # Try to print common fields
        print(f"[RESULT] Matching universities ({len(uni_rows)}):")
        for r in uni_rows:
            uid = r.get("id")
            name = r.get("name") or r.get("title") or r.get("slug")
            print(f"  - id={uid} name={name}")

        # For each found university id, attempt join via each link table
        uni_ids = [r.get("id") for r in uni_rows if r.get("id")]
        if not uni_ids:
            print("[WARN] Could not read university id field from rows.")
            continue

        ids_sql = ",".join(["'" + str(u).replace("'", "''") + "'" for u in uni_ids])

        any_found = False
        for lt in link_tables:
            ltname = lt.get("table_name")
            if not ltname:
                continue
            link_table = f"app.{ltname}"

            # Join to auth.users to get email
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
                        f"  - email={a.get('email')} user_id={a.get('user_id')} university_id={a.get('university_id')} last_sign_in_at={a.get('last_sign_in_at')}")

        if not any_found:
            print("[RESULT] No linked accounts found via discovered link tables.")

    print("\n[NOTE] Passwords cannot be retrieved from Supabase (hashed). Use password reset instead.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

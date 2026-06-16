#!/usr/bin/env python3
"""Discover how universities link to auth.users and print emails for target universities.

Passwords are not retrievable (hashed). This script only outputs emails.
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
    print("DISCOVERY — University -> auth.users links")
    print(f"Project: {manager.url}")
    print("=" * 80)

    # 1) Identify tables containing university_id
    uni_id_tables = exec_sql(
        manager,
        """
        SELECT table_schema, table_name
        FROM information_schema.columns
        WHERE table_schema='app'
          AND column_name='university_id'
        GROUP BY table_schema, table_name
        ORDER BY table_name
        """.strip(),
    )
    print("\n[DISCOVERY] Tables in app.* that contain university_id:")
    for t in uni_id_tables:
        print(f"  - {t['table_schema']}.{t['table_name']}")

    # 2) For those tables, list candidate user columns
    candidate_user_cols = exec_sql(
        manager,
        """
        SELECT table_name, column_name, data_type
        FROM information_schema.columns
        WHERE table_schema='app'
          AND table_name IN (
            SELECT table_name FROM information_schema.columns
            WHERE table_schema='app' AND column_name='university_id'
          )
          AND (
            column_name ILIKE '%user%id%'
            OR column_name IN (
              'user_id','owner_user_id','created_by_user_id','admin_user_id',
              'staff_user_id','teacher_user_id','reviewed_by_user_id'
            )
          )
        ORDER BY table_name, column_name
        """.strip(),
    )

    print("\n[DISCOVERY] Candidate user-id columns alongside university_id:")
    if not candidate_user_cols:
        print("  (none found)")
    else:
        for c in candidate_user_cols:
            print(f"  - app.{c['table_name']}.{c['column_name']} ({c['data_type']})")

    # 3) Special-case: university_staff table often links staff to auth.users
    print("\n[DISCOVERY] Columns for app.university_staff:")
    staff_cols = exec_sql(
        manager,
        """
        SELECT column_name, data_type
        FROM information_schema.columns
        WHERE table_schema='app' AND table_name='university_staff'
        ORDER BY ordinal_position
        """.strip(),
    )
    for c in staff_cols:
        print(f"  - {c['column_name']} ({c['data_type']})")

    # 4) For each target university, try to find staff emails from university_staff
    for label, tokens in TARGETS:
        where = build_where(tokens)
        print("\n" + "-" * 80)
        print(f"TARGET: {label}")
        print("-" * 80)

        uni_rows = exec_sql(
            manager,
            f"""
            SELECT id, name, slug
            FROM app.universities
            WHERE {where}
            ORDER BY created_at DESC NULLS LAST
            LIMIT 20
            """.strip(),
        )
        if not uni_rows:
            print("[RESULT] No matching university rows")
            continue

        uni_ids = [str(r['id']) for r in uni_rows if r.get('id')]
        print(f"[RESULT] Universities found: {len(uni_ids)}")
        for r in uni_rows:
            print(f"  - id={r.get('id')} name={r.get('name')} slug={r.get('slug')}")

        ids_sql = ",".join(["'" + u.replace("'", "''") + "'" for u in uni_ids])

        # Attempt: app.university_staff has a user-id-like column? We'll detect it.
        # Find any column in university_staff that looks like a UUID and contains 'user'.
        staff_user_cols = [c['column_name'] for c in staff_cols if 'user' in c['column_name'] and c['data_type'] == 'uuid']

        if staff_user_cols:
            # Try each possible staff user column
            for col in staff_user_cols:
                rows = exec_sql(
                    manager,
                    f"""
                    SELECT s.university_id, s.{col} as user_id, u.email, u.last_sign_in_at
                    FROM app.university_staff s
                    JOIN auth.users u ON u.id = s.{col}
                    WHERE s.university_id IN ({ids_sql})
                    ORDER BY u.created_at DESC
                    LIMIT 200
                    """.strip(),
                )
                if rows:
                    print(f"\n[RESULT] Staff accounts via app.university_staff.{col} ({len(rows)}):")
                    for a in rows:
                        print(f"  - email={a.get('email')} user_id={a.get('user_id')} last_sign_in_at={a.get('last_sign_in_at')}")
        else:
            print("[INFO] No uuid user columns found in app.university_staff.")

        # Fallback: university_staff may store email directly
        email_cols = [c['column_name'] for c in staff_cols if c['data_type'] in ('text','character varying') and 'mail' in c['column_name']]
        if email_cols:
            for col in email_cols:
                rows = exec_sql(
                    manager,
                    f"""
                    SELECT university_id, {col} as email
                    FROM app.university_staff
                    WHERE university_id IN ({ids_sql})
                      AND {col} IS NOT NULL AND {col} <> ''
                    ORDER BY {col}
                    LIMIT 200
                    """.strip(),
                )
                if rows:
                    print(f"\n[RESULT] Staff emails stored in university_staff.{col} ({len(rows)}):")
                    for a in rows:
                        print(f"  - email={a.get('email')}")

    print("\n[SECURITY] Passwords cannot be retrieved from Supabase Auth (hashed).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

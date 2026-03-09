#!/usr/bin/env python3
"""Verify marketplace categories + bookmarks migration.

Checks:
- tables/columns exist
- policies exist
- RPCs exist + signatures

Writes .windsurf/logs/audit_marketplace_categories_bookmarks_verify.json
"""

import json
from typing import Any, Dict, List, Tuple

import requests

from supabase_auto_manager import SupabaseAutoManager


def run_sql(m: SupabaseAutoManager, label: str, sql: str, timeout: int = 120) -> Dict[str, Any]:
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    resp = requests.post(url, headers=m.headers, json={"p_sql": sql}, timeout=timeout)
    try:
        data = resp.json()
    except Exception:
        return {"label": label, "http": resp.status_code, "ok": False, "raw": (resp.text or "")[:2000]}

    if isinstance(data, dict):
        rows = data.get("rows")
        return {
            "label": label,
            "http": resp.status_code,
            "ok": bool(data.get("ok")),
            "mode": data.get("mode"),
            "rows": rows if isinstance(rows, list) else [],
            "error": data.get("error"),
            "sqlstate": data.get("sqlstate"),
        }

    if isinstance(data, list):
        return {"label": label, "http": resp.status_code, "ok": True, "mode": "select", "rows": data}

    return {"label": label, "http": resp.status_code, "ok": False, "error": "unexpected_json_type"}


def main() -> int:
    m = SupabaseAutoManager()

    queries: List[Tuple[str, str]] = [
        (
            "TABLES_EXIST",
            """
            SELECT table_name
            FROM information_schema.tables
            WHERE table_schema = 'app'
              AND table_name IN ('marketplace_categories', 'marketplace_listing_bookmarks')
            ORDER BY table_name
            """.strip(),
        ),
        (
            "LISTINGS_COLUMNS",
            """
            SELECT column_name, data_type
            FROM information_schema.columns
            WHERE table_schema = 'app'
              AND table_name = 'marketplace_listings'
              AND column_name IN ('category_id', 'sub_category_id')
            ORDER BY column_name
            """.strip(),
        ),
        (
            "POLICIES",
            """
            SELECT schemaname, tablename, policyname, cmd, roles
            FROM pg_policies
            WHERE schemaname = 'app'
              AND (
                (tablename = 'marketplace_categories' AND policyname = 'public_select_active_marketplace_categories')
                OR (tablename = 'marketplace_listing_bookmarks' AND policyname = 'user_manage_own_marketplace_listing_bookmarks')
              )
            ORDER BY tablename, policyname
            """.strip(),
        ),
        (
            "RPC_EXISTS",
            """
            SELECT routine_name
            FROM information_schema.routines
            WHERE routine_schema = 'public'
              AND routine_name IN (
                'app_list_marketplace_categories',
                'app_marketplace_listing_toggle_bookmark',
                'app_student_list_bookmarked_marketplace_listings',
                'app_student_list_marketplace_listings'
              )
            ORDER BY routine_name
            """.strip(),
        ),
        (
            "RPC_SIGNATURES",
            """
            SELECT
              p.proname AS routine_name,
              pg_get_function_identity_arguments(p.oid) AS identity_args
            FROM pg_proc p
            JOIN pg_namespace n ON n.oid = p.pronamespace
            WHERE n.nspname = 'public'
              AND p.proname IN (
                'app_list_marketplace_categories',
                'app_marketplace_listing_toggle_bookmark',
                'app_student_list_bookmarked_marketplace_listings',
                'app_student_list_marketplace_listings'
              )
            ORDER BY p.proname, identity_args
            """.strip(),
        ),
    ]

    results: Dict[str, Any] = {}

    for label, sql in queries:
        print(f"Exécution: {label}...")
        res = run_sql(m, label, sql)
        results[label] = {
            "ok": res.get("ok"),
            "http": res.get("http"),
            "mode": res.get("mode"),
            "rows": res.get("rows"),
            "error": res.get("error"),
            "sqlstate": res.get("sqlstate"),
        }
        if res.get("ok"):
            print(f"  ✓ {label}: {len(res.get('rows') or [])} lignes")
        else:
            print(f"  ✗ {label}: {res.get('error')}")

    out_path = ".windsurf/logs/audit_marketplace_categories_bookmarks_verify.json"
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, indent=2)

    print(f"\n[OK] Résultats sauvegardés dans {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

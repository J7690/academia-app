#!/usr/bin/env python3
"""Audit Supabase for Marketplace: types & bookmarks.

Focus:
- whether there are existing type catalogs (career vs marketplace)
- existing bookmark/favorites tables and RPCs

Writes .windsurf/logs/audit_marketplace_types_bookmarks.json
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
            "TABLES_CANDIDATES",
            """
            SELECT table_schema, table_name
            FROM information_schema.tables
            WHERE table_schema IN ('app', 'public')
              AND table_type = 'BASE TABLE'
              AND (
                table_name ILIKE '%type%'
                OR table_name ILIKE '%bookmark%'
                OR table_name ILIKE '%favorite%'
                OR table_name ILIKE '%favour%'
                OR table_name ILIKE '%marketplace%'
              )
            ORDER BY table_schema, table_name
            """.strip(),
        ),
        (
            "OPPORTUNITIES_TYPE_DISTINCT",
            """
            SELECT type, COUNT(*) AS cnt
            FROM app.opportunities
            GROUP BY type
            ORDER BY cnt DESC, type
            """.strip(),
        ),
        (
            "MARKETPLACE_LISTINGS_TYPE_DISTINCT",
            """
            SELECT type, COUNT(*) AS cnt
            FROM app.marketplace_listings
            GROUP BY type
            ORDER BY cnt DESC, type
            """.strip(),
        ),
        (
            "OPPORTUNITIES_CATEGORY_DISTINCT",
            """
            SELECT category, COUNT(*) AS cnt
            FROM app.opportunities
            GROUP BY category
            ORDER BY cnt DESC, category
            """.strip(),
        ),
        (
            "MARKETPLACE_LISTINGS_CATEGORY_DISTINCT",
            """
            SELECT category, COUNT(*) AS cnt
            FROM app.marketplace_listings
            GROUP BY category
            ORDER BY cnt DESC, category
            """.strip(),
        ),
        (
            "FUNCTIONS_CANDIDATES",
            """
            SELECT routine_schema, routine_name
            FROM information_schema.routines
            WHERE routine_schema IN ('public')
              AND (
                routine_name ILIKE '%type%'
                OR routine_name ILIKE '%bookmark%'
                OR routine_name ILIKE '%favorite%'
                OR routine_name ILIKE '%marketplace%'
              )
            ORDER BY routine_schema, routine_name
            """.strip(),
        ),
        (
            "POLICIES_BOOKMARKS_TYPES",
            """
            SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
            FROM pg_policies
            WHERE schemaname = 'app'
              AND (
                tablename ILIKE '%bookmark%'
                OR tablename ILIKE '%favorite%'
                OR tablename ILIKE '%type%'
                OR tablename ILIKE '%marketplace%'
              )
            ORDER BY schemaname, tablename, policyname
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

    out_path = ".windsurf/logs/audit_marketplace_types_bookmarks.json"
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, indent=2)

    print(f"\n[OK] Résultats sauvegardés dans {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

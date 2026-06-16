#!/usr/bin/env python3
"""Audit how merchant_id relates to auth/users in current Supabase schema.

Checks:
- foreign keys referencing app.marketplace_listings.merchant_id
- likely merchant tables
- columns in app.merchants / app.merchant_profiles if exist

Writes .windsurf/logs/audit_marketplace_merchant_relation.json
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
            "LISTINGS_MERCHANT_COL",
            """
            SELECT column_name, data_type
            FROM information_schema.columns
            WHERE table_schema='app'
              AND table_name='marketplace_listings'
              AND column_name='merchant_id'
            """.strip(),
        ),
        (
            "FOREIGN_KEYS_ON_MERCHANT_ID",
            """
            SELECT
              tc.table_schema,
              tc.table_name,
              kcu.column_name,
              ccu.table_schema AS foreign_table_schema,
              ccu.table_name AS foreign_table_name,
              ccu.column_name AS foreign_column_name,
              tc.constraint_name
            FROM information_schema.table_constraints AS tc
            JOIN information_schema.key_column_usage AS kcu
              ON tc.constraint_name = kcu.constraint_name
             AND tc.table_schema = kcu.table_schema
            JOIN information_schema.constraint_column_usage AS ccu
              ON ccu.constraint_name = tc.constraint_name
             AND ccu.table_schema = tc.table_schema
            WHERE tc.constraint_type = 'FOREIGN KEY'
              AND tc.table_schema='app'
              AND tc.table_name='marketplace_listings'
              AND kcu.column_name='merchant_id'
            """.strip(),
        ),
        (
            "CANDIDATE_MERCHANT_TABLES",
            """
            SELECT table_schema, table_name
            FROM information_schema.tables
            WHERE table_schema='app'
              AND (
                table_name ILIKE '%merchant%'
                OR table_name ILIKE '%seller%'
              )
            ORDER BY table_name
            """.strip(),
        ),
        (
            "PUBLIC_ROUTINES_MERCHANT",
            """
            SELECT routine_name
            FROM information_schema.routines
            WHERE routine_schema='public'
              AND routine_name ILIKE '%merchant%'
            ORDER BY routine_name
            """.strip(),
        ),
    ]

    out: Dict[str, Any] = {}
    for label, sql in queries:
        print(f"Exécution: {label}...")
        res = run_sql(m, label, sql)
        out[label] = {
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

    out_path = ".windsurf/logs/audit_marketplace_merchant_relation.json"
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)

    print(f"\n[OK] Résultats sauvegardés dans {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

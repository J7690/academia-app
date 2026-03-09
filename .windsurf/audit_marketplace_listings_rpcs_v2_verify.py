#!/usr/bin/env python3
"""Verify marketplace_listings RPC v2 deployment.

Writes to .windsurf/logs/audit_marketplace_listings_rpcs_v2_verify.json
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
            "rows_count": len(rows) if isinstance(rows, list) else 0,
            "rows": rows if isinstance(rows, list) else [],
            "error": data.get("error"),
            "sqlstate": data.get("sqlstate"),
        }

    if isinstance(data, list):
        return {
            "label": label,
            "http": resp.status_code,
            "ok": True,
            "mode": "select",
            "rows_count": len(data),
            "rows": data,
            "error": None,
            "sqlstate": None,
        }

    return {
        "label": label,
        "http": resp.status_code,
        "ok": False,
        "mode": None,
        "rows_count": 0,
        "rows": [],
        "error": "unexpected_json_type",
        "sqlstate": None,
    }


def main() -> int:
    m = SupabaseAutoManager()

    queries: List[Tuple[str, str]] = [
        (
            "RPC_EXISTS",
            """
            SELECT routine_name
            FROM information_schema.routines
            WHERE routine_schema = 'public'
              AND routine_name IN (
                'app_student_list_marketplace_listings',
                'app_student_get_marketplace_listing_detail',
                'app_merchant_list_my_marketplace_listings',
                'app_merchant_upsert_marketplace_listing',
                'app_merchant_submit_marketplace_listing_for_review',
                'app_admin_list_pending_marketplace_listings',
                'app_admin_review_marketplace_listing',
                'app_student_create_marketplace_listing_inquiry'
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
                'app_student_list_marketplace_listings',
                'app_student_get_marketplace_listing_detail',
                'app_merchant_list_my_marketplace_listings',
                'app_merchant_upsert_marketplace_listing',
                'app_merchant_submit_marketplace_listing_for_review',
                'app_admin_list_pending_marketplace_listings',
                'app_admin_review_marketplace_listing',
                'app_student_create_marketplace_listing_inquiry'
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
            "http": res.get("http"),
            "ok": res.get("ok"),
            "mode": res.get("mode"),
            "rows_count": res.get("rows_count"),
            "rows": res.get("rows"),
            "error": res.get("error"),
            "sqlstate": res.get("sqlstate"),
        }
        if res.get("ok"):
            print(f"  ✓ {label}: {res.get('rows_count')} lignes")
        else:
            print(f"  ✗ {label}: erreur - {res.get('error')}")

    out_path = ".windsurf/logs/audit_marketplace_listings_rpcs_v2_verify.json"
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, indent=2)

    print(f"\n[OK] Résultats sauvegardés dans {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

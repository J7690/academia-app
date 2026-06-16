#!/usr/bin/env python3
"""Pre-audit Marketplace Phase 2 (RLS + RPC)

- Interroge Supabase via admin_execute_sql
- Capture l'état actuel: policies, fonctions utiles, colonnes, tables
- Consigne dans .windsurf/logs/
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
            "MARKETPLACE_TABLES",
            """
            SELECT table_schema, table_name
            FROM information_schema.tables
            WHERE table_schema = 'app'
              AND table_name IN (
                'merchant_profiles',
                'opportunity_inquiries',
                'opportunity_inquiry_messages',
                'opportunities'
              )
            ORDER BY table_name
            """.strip(),
        ),
        (
            "MARKETPLACE_POLICIES",
            """
            SELECT schemaname, tablename, policyname, roles, cmd, qual, with_check
            FROM pg_policies
            WHERE schemaname = 'app'
              AND tablename IN (
                'merchant_profiles',
                'opportunity_inquiries',
                'opportunity_inquiry_messages',
                'opportunities'
              )
            ORDER BY tablename, policyname
            """.strip(),
        ),
        (
            "ROLE_HELPERS_FUNCTIONS",
            """
            SELECT routine_name
            FROM information_schema.routines
            WHERE routine_schema = 'public'
              AND (
                routine_name ILIKE '%role%'
                OR routine_name ILIKE '%currentrole%'
                OR routine_name ILIKE '%get_current_role%'
              )
            ORDER BY routine_name
            """.strip(),
        ),
        (
            "EXISTING_MARKETPLACE_FUNCTIONS",
            """
            SELECT routine_name
            FROM information_schema.routines
            WHERE routine_schema = 'public'
              AND (
                routine_name ILIKE '%merchant%'
                OR routine_name ILIKE '%inquir%'
              )
            ORDER BY routine_name
            """.strip(),
        ),
        (
            "OPPORTUNITIES_MARKETPLACE_COLUMNS",
            """
            SELECT column_name, data_type, is_nullable, column_default
            FROM information_schema.columns
            WHERE table_schema = 'app'
              AND table_name = 'opportunities'
              AND column_name IN (
                'merchant_id',
                'review_status',
                'review_reason',
                'submitted_at',
                'reviewed_at',
                'reviewed_by',
                'price_from',
                'price_to',
                'currency',
                'min_order_qty',
                'lead_time_days',
                'is_ready_to_ship'
              )
            ORDER BY column_name
            """.strip(),
        ),
    ]

    results: Dict[str, Any] = {}
    for label, sql in queries:
        print(f"Exécution: {label}...")
        res = run_sql(m, label, sql)
        rows = res.get("rows")
        if not isinstance(rows, list):
            rows = []
        results[label] = {
            "http": res.get("http"),
            "ok": res.get("ok"),
            "mode": res.get("mode"),
            "rows_count": res.get("rows_count"),
            "rows": rows,
            "error": res.get("error"),
            "sqlstate": res.get("sqlstate"),
        }
        if res.get("ok"):
            print(f"  ✓ {label}: {res.get('rows_count')} lignes")
        else:
            print(f"  ✗ {label}: erreur - {res.get('error')}")

    out_path = ".windsurf/logs/audit_marketplace_phase2_precheck.json"
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, indent=2)

    print(f"\n[OK] Résultats sauvegardés dans {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

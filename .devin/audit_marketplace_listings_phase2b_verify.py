#!/usr/bin/env python3
"""Verify Phase 2B migration: marketplace_listings table + backfill + inquiry listing_id.

Writes to .windsurf/logs/audit_marketplace_listings_phase2b_verify.json
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
            "TABLE_EXISTS",
            """
            SELECT table_schema, table_name
            FROM information_schema.tables
            WHERE table_schema = 'app'
              AND table_name = 'marketplace_listings'
            """.strip(),
        ),
        (
            "LISTINGS_COLUMNS",
            """
            SELECT column_name, data_type, is_nullable, column_default
            FROM information_schema.columns
            WHERE table_schema = 'app'
              AND table_name = 'marketplace_listings'
            ORDER BY ordinal_position
            """.strip(),
        ),
        (
            "INQUIRIES_HAS_LISTING_ID",
            """
            SELECT column_name, data_type, is_nullable
            FROM information_schema.columns
            WHERE table_schema = 'app'
              AND table_name = 'opportunity_inquiries'
              AND column_name = 'listing_id'
            """.strip(),
        ),
        (
            "COUNTS",
            """
            SELECT
              (SELECT COUNT(*) FROM app.opportunities WHERE merchant_id IS NOT NULL) AS opportunities_marketplace_count,
              (SELECT COUNT(*) FROM app.marketplace_listings) AS listings_count,
              (SELECT COUNT(*) FROM app.opportunity_inquiries WHERE listing_id IS NOT NULL) AS inquiries_with_listing_id_count,
              (SELECT COUNT(*) FROM app.opportunity_inquiries) AS inquiries_total
            """.strip(),
        ),
        (
            "FK_INQUIRIES_LISTING_ID",
            """
            SELECT
              tc.table_name,
              kcu.column_name,
              ccu.table_name AS foreign_table_name,
              ccu.column_name AS foreign_column_name,
              tc.constraint_name
            FROM information_schema.table_constraints tc
            JOIN information_schema.key_column_usage kcu
              ON tc.constraint_name = kcu.constraint_name
              AND tc.table_schema = kcu.table_schema
            JOIN information_schema.constraint_column_usage ccu
              ON ccu.constraint_name = tc.constraint_name
              AND ccu.table_schema = tc.table_schema
            WHERE tc.constraint_type = 'FOREIGN KEY'
              AND tc.table_schema = 'app'
              AND tc.table_name = 'opportunity_inquiries'
              AND kcu.column_name = 'listing_id'
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

    out_path = ".windsurf/logs/audit_marketplace_listings_phase2b_verify.json"
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, indent=2)

    print(f"\n[OK] Résultats sauvegardés dans {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

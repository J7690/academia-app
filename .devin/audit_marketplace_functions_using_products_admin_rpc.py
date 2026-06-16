#!/usr/bin/env python3
"""Audit: find functions/views that reference marketplace_products or marketplace_order_items.

We need to decide whether to:
- change order_items.product_id FK to marketplace_listings(id)
OR
- map listings to products during checkout.

This audit lists routines whose source mentions these tables.
Writes results to .windsurf/logs/audit_marketplace_functions_using_products.json
"""

from __future__ import annotations

import json
from datetime import datetime
from pathlib import Path

import requests

from supabase_auto_manager import SupabaseAutoManager


def _rpc(manager: SupabaseAutoManager, sql: str) -> dict:
    sql = sql.strip()
    while sql.endswith(";"):
        sql = sql[:-1].rstrip()

    url = f"{manager.url}/rest/v1/rpc/admin_execute_sql"
    resp = requests.post(url, headers=manager.headers, json={"p_sql": sql}, timeout=90)

    out: dict = {
        "http": resp.status_code,
        "ok": resp.status_code == 200,
        "rows": [],
        "error": None,
        "sqlstate": None,
    }

    if resp.status_code != 200:
        out["error"] = resp.text
        return out

    data = resp.json()
    if isinstance(data, dict) and data.get("ok") is False:
        out["ok"] = False
        out["error"] = data.get("error")
        out["sqlstate"] = data.get("sqlstate")
        return out

    if isinstance(data, dict):
        out["rows"] = data.get("rows") if data.get("rows") is not None else (data.get("data") or [])
    elif isinstance(data, list):
        out["rows"] = data
    else:
        out["rows"] = []

    out["rows_count"] = len(out["rows"])
    return out


def main() -> int:
    manager = SupabaseAutoManager()
    winds_dir = Path(__file__).parent
    logs_dir = winds_dir / "logs"
    logs_dir.mkdir(parents=True, exist_ok=True)

    queries = {
        "ROUTINES_MENTIONING_PRODUCTS": """
SELECT
  r.routine_schema AS schema,
  r.routine_name AS name
FROM information_schema.routines r
WHERE r.routine_schema IN ('public', 'app')
  AND COALESCE(r.routine_definition, '') ILIKE '%marketplace_products%'
ORDER BY r.routine_schema, r.routine_name
LIMIT 200
""",
        "ROUTINES_MENTIONING_ORDER_ITEMS": """
SELECT
  r.routine_schema AS schema,
  r.routine_name AS name
FROM information_schema.routines r
WHERE r.routine_schema IN ('public', 'app')
  AND COALESCE(r.routine_definition, '') ILIKE '%marketplace_order_items%'
ORDER BY r.routine_schema, r.routine_name
LIMIT 200
""",
    }

    results: dict = {
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "queries": {},
    }

    for key, sql in queries.items():
        print(f"Exécution: {key}...")
        res = _rpc(manager, sql)
        results["queries"][key] = res
        if res.get("ok"):
            print(f"  ✓ {key}: {res.get('rows_count', 0)} lignes")
        else:
            print(f"  ✗ {key}: {res.get('error')}")

    out_path = logs_dir / "audit_marketplace_functions_using_products.json"
    out_path.write_text(json.dumps(results, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"\n[OK] Résultats sauvegardés dans {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

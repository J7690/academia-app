#!/usr/bin/env python3
"""Audit: why merchant/admin cannot see student orders.

Outputs:
- last orders with merchant_id
- merchant mapping for current merchant users
- routine definitions for merchant/admin order listing

Writes .windsurf/logs/audit_marketplace_orders_visibility.json
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
    m = SupabaseAutoManager()
    logs_dir = Path(__file__).parent / "logs"
    logs_dir.mkdir(parents=True, exist_ok=True)

    queries: dict[str, str] = {
        "LAST_ORDERS": """
SELECT
  o.id,
  o.student_id,
  o.merchant_id,
  o.status,
  o.total_amount,
  o.currency,
  o.created_at
FROM app.marketplace_orders o
ORDER BY o.created_at DESC
LIMIT 25
""",
        "ORDERS_WITH_MERCHANT": """
SELECT
  o.id AS order_id,
  o.status,
  o.total_amount,
  o.currency,
  o.created_at,
  m.id AS merchant_pk,
  m.owner_user_id AS merchant_owner_user_id,
  m.name AS merchant_name
FROM app.marketplace_orders o
LEFT JOIN app.marketplace_merchants m ON m.id = o.merchant_id
ORDER BY o.created_at DESC
LIMIT 25
""",
        "ROUTINE_DEF_app_merchant_list_my_marketplace_orders": """
SELECT pg_get_functiondef(p.oid) AS ddl
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname='public' AND p.proname='app_merchant_list_my_marketplace_orders'
LIMIT 1
""",
        "ROUTINE_DEF_app_merchant_get_marketplace_order_detail": """
SELECT pg_get_functiondef(p.oid) AS ddl
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname='public' AND p.proname='app_merchant_get_marketplace_order_detail'
LIMIT 1
""",
        "ROUTINE_DEF_app_admin_list_marketplace_orders": """
SELECT pg_get_functiondef(p.oid) AS ddl
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname='public' AND p.proname='app_admin_list_marketplace_orders'
LIMIT 1
""",
    }

    results: dict = {
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "queries": {},
    }

    for k, sql in queries.items():
        print(f"Run {k}...")
        results["queries"][k] = _rpc(m, sql)

    out_path = logs_dir / "audit_marketplace_orders_visibility.json"
    out_path.write_text(json.dumps(results, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"[OK] {out_path}")
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

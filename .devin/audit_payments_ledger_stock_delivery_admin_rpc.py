#!/usr/bin/env python3
"""Audit for payments/ledger/receipts/stock/delivery related schema in Supabase.

This avoids PowerShell quoting issues by running SQL through admin_execute_sql.
Writes .windsurf/logs/audit_payments_ledger_stock_delivery.json
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

    like_patterns = [
        "%payment%",
        "%transaction%",
        "%invoice%",
        "%receipt%",
        "%ledger%",
        "%payout%",
        "%wallet%",
        "%balance%",
        "%stock%",
        "%inventory%",
        "%delivery%",
        "%shipment%",
        "%refund%",
    ]

    like_filter = " OR ".join([f"name ILIKE '{p}'" for p in like_patterns])

    queries: dict[str, str] = {
        "TABLES_MATCHING": f"""
WITH t AS (
  SELECT table_schema AS schema, table_name AS name
  FROM information_schema.tables
  WHERE table_schema IN ('app','public')
    AND table_type='BASE TABLE'
)
SELECT * FROM t
WHERE {like_filter}
ORDER BY schema, name
""",
        "VIEWS_MATCHING": f"""
WITH v AS (
  SELECT table_schema AS schema, table_name AS name
  FROM information_schema.views
  WHERE table_schema IN ('app','public')
)
SELECT * FROM v
WHERE {like_filter}
ORDER BY schema, name
""",
        "ROUTINES_MATCHING": f"""
WITH r AS (
  SELECT routine_schema AS schema, routine_name AS name
  FROM information_schema.routines
  WHERE routine_schema IN ('app','public')
)
SELECT * FROM r
WHERE {like_filter}
ORDER BY schema, name
""",
    }

    results: dict = {
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "queries": {},
    }

    for k, sql in queries.items():
        print(f"Run {k}...")
        results["queries"][k] = _rpc(m, sql)

    out_path = logs_dir / "audit_payments_ledger_stock_delivery.json"
    out_path.write_text(json.dumps(results, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"[OK] {out_path}")
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

#!/usr/bin/env python3
"""Audit constraints for marketplace order/product tables.

Focus:
- app.marketplace_order_items foreign keys (product_id)
- app.marketplace_products constraints (PK/FK)
- app.marketplace_listings constraints (PK/FK) for potential mapping

Writes results to .windsurf/logs/audit_marketplace_orders_products_constraints.json
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
    resp = requests.post(url, headers=manager.headers, json={"p_sql": sql}, timeout=60)

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


def _constraints_sql(table: str) -> str:
    schema, name = table.split(".", 1)
    return f"""
SELECT
  con.conname AS constraint_name,
  con.contype AS constraint_type,
  pg_get_constraintdef(con.oid) AS definition
FROM pg_constraint con
JOIN pg_class rel ON rel.oid = con.conrelid
JOIN pg_namespace nsp ON nsp.oid = rel.relnamespace
WHERE nsp.nspname = '{schema}'
  AND rel.relname = '{name}'
ORDER BY con.conname
""".strip()


def main() -> int:
    manager = SupabaseAutoManager()
    winds_dir = Path(__file__).parent
    logs_dir = winds_dir / "logs"
    logs_dir.mkdir(parents=True, exist_ok=True)

    targets = [
        "app.marketplace_order_items",
        "app.marketplace_orders",
        "app.marketplace_products",
        "app.marketplace_listings",
    ]

    results: dict = {
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "constraints": {},
    }

    for t in targets:
        print(f"Exécution: CONSTRAINTS {t}...")
        res = _rpc(manager, _constraints_sql(t))
        results["constraints"][t] = res
        if res.get("ok"):
            print(f"  ✓ {t}: {res.get('rows_count', 0)} lignes")
        else:
            print(f"  ✗ {t}: {res.get('error')}")

    out_path = logs_dir / "audit_marketplace_orders_products_constraints.json"
    out_path.write_text(json.dumps(results, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"\n[OK] Résultats sauvegardés dans {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Dump full pg_get_functiondef for selected routines.

Writes results to .windsurf/logs/audit_marketplace_dump_functiondef.json
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

    funcs = [
        "app_list_student_marketplace_orders",
        "app_merchant_list_orders",
        "app_merchant_get_dashboard",
        "app_merchant_get_marketplace_order_detail",
        "app_student_get_marketplace_order_detail",
        "app_student_checkout_create_order_from_cart",
    ]

    results: dict = {
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "functions": {},
    }

    for f in funcs:
        print(f"Exécution: DDL {f}...")
        sql = f"""
SELECT pg_get_functiondef(p.oid) AS ddl
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = '{f}'
LIMIT 1
""".strip()
        res = _rpc(manager, sql)
        results["functions"][f] = res
        if res.get("ok"):
            print(f"  ✓ {f}: {res.get('rows_count', 0)} lignes")
        else:
            print(f"  ✗ {f}: {res.get('error')}")

    out_path = logs_dir / "audit_marketplace_dump_functiondef.json"
    out_path.write_text(json.dumps(results, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"\n[OK] Résultats sauvegardés dans {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

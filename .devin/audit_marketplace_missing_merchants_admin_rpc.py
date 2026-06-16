#!/usr/bin/env python3
"""Audit: merchants missing in app.marketplace_merchants for listings/cart.

Goal: explain why checkout returns merchant_not_found and provide concrete IDs.
Writes results to .windsurf/logs/audit_marketplace_missing_merchants.json
"""

from __future__ import annotations

import json
from datetime import datetime
from pathlib import Path

import requests

from supabase_auto_manager import SupabaseAutoManager


def _rpc_admin_execute_sql(manager: SupabaseAutoManager, sql: str) -> dict:
    sql = sql.strip()
    while sql.endswith(";"):
        sql = sql[:-1].rstrip()

    url = f"{manager.url}/rest/v1/rpc/admin_execute_sql"
    resp = requests.post(
        url,
        headers=manager.headers,
        json={"p_sql": sql},
        timeout=60,
    )
    out: dict = {
        "http": resp.status_code,
        "ok": resp.status_code == 200,
        "mode": "select",
        "rows": None,
        "error": None,
        "sqlstate": None,
    }

    if resp.status_code != 200:
        out["error"] = resp.text
        return out

    try:
        data = resp.json()
    except Exception:
        out["ok"] = False
        out["error"] = "non_json_response"
        return out

    if isinstance(data, dict) and data.get("ok") is False:
        out["ok"] = False
        out["error"] = data.get("error")
        out["sqlstate"] = data.get("sqlstate")
        return out

    # admin_execute_sql returns {ok:true, rows:[...]} or {ok:true, data:[...]}
    if isinstance(data, dict):
        out["rows"] = data.get("rows") if data.get("rows") is not None else data.get("data")
    else:
        out["rows"] = data

    if out["rows"] is None:
        out["rows"] = []

    return out


def main() -> int:
    manager = SupabaseAutoManager()
    winds_dir = Path(__file__).parent
    logs_dir = winds_dir / "logs"
    logs_dir.mkdir(parents=True, exist_ok=True)

    queries: dict[str, str] = {
        "MERCHANTS_COLUMNS": """
SELECT
  c.column_name,
  c.data_type,
  c.is_nullable,
  c.column_default
FROM information_schema.columns c
WHERE c.table_schema = 'app'
  AND c.table_name = 'marketplace_merchants'
ORDER BY c.ordinal_position;
""".strip(),
        "MERCHANTS_CONSTRAINTS": """
SELECT
  con.conname AS constraint_name,
  con.contype AS constraint_type,
  pg_get_constraintdef(con.oid) AS definition
FROM pg_constraint con
JOIN pg_class rel ON rel.oid = con.conrelid
JOIN pg_namespace nsp ON nsp.oid = rel.relnamespace
WHERE nsp.nspname = 'app'
  AND rel.relname = 'marketplace_merchants'
ORDER BY con.conname;
""".strip(),
        "MISSING_MERCHANTS_FROM_LISTINGS": """
SELECT
  l.merchant_id AS merchant_owner_user_id,
  COUNT(*) AS listings_count,
  MAX(l.created_at) AS latest_listing_at
FROM app.marketplace_listings l
LEFT JOIN app.marketplace_merchants m
  ON m.owner_user_id = l.merchant_id
WHERE l.merchant_id IS NOT NULL
  AND m.id IS NULL
GROUP BY l.merchant_id
ORDER BY latest_listing_at DESC
LIMIT 50;
""".strip(),
        "MISSING_MERCHANTS_PROFILES": """
SELECT
  mp.user_id,
  mp.display_name,
  mp.is_active,
  mp.is_verified
FROM app.merchant_profiles mp
WHERE mp.user_id IN (
  SELECT l.merchant_id
  FROM app.marketplace_listings l
  LEFT JOIN app.marketplace_merchants m ON m.owner_user_id = l.merchant_id
  WHERE l.merchant_id IS NOT NULL
    AND m.id IS NULL
  GROUP BY l.merchant_id
)
ORDER BY mp.display_name;
""".strip(),
    }

    results: dict[str, dict] = {
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "queries": {},
    }

    for key, sql in queries.items():
        print(f"Exécution: {key}...")
        res = _rpc_admin_execute_sql(manager, sql)
        if res.get("rows") is not None:
            res["rows_count"] = len(res.get("rows") or [])
        results["queries"][key] = res
        if res.get("ok"):
            print(f"  ✓ {key}: {res.get('rows_count', 0)} lignes")
        else:
            print(f"  ✗ {key}: {res.get('error')}")

    out_path = logs_dir / "audit_marketplace_missing_merchants.json"
    out_path.write_text(json.dumps(results, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"\n[OK] Résultats sauvegardés dans {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

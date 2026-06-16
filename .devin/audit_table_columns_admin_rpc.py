#!/usr/bin/env python3
"""Generic audit: list columns for a given table (schema.table) via admin_execute_sql.

Usage:
  python .windsurf/audit_table_columns_admin_rpc.py app.university_media

Writes .windsurf/logs/audit_table_columns_<schema>_<table>.json
"""

import json
import sys
from typing import Any, Dict

import requests

from supabase_auto_manager import SupabaseAutoManager


def run_sql(m: SupabaseAutoManager, sql: str, timeout: int = 120) -> Dict[str, Any]:
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    resp = requests.post(url, headers=m.headers, json={"p_sql": sql}, timeout=timeout)
    try:
        data = resp.json()
    except Exception:
        return {"http": resp.status_code, "ok": False, "raw": (resp.text or "")[:2000]}

    if isinstance(data, dict):
        rows = data.get("rows")
        return {
            "http": resp.status_code,
            "ok": bool(data.get("ok")),
            "mode": data.get("mode"),
            "rows": rows if isinstance(rows, list) else [],
            "error": data.get("error"),
            "sqlstate": data.get("sqlstate"),
        }

    if isinstance(data, list):
        return {"http": resp.status_code, "ok": True, "mode": "select", "rows": data}

    return {"http": resp.status_code, "ok": False, "error": "unexpected_json_type"}


def main() -> int:
    if len(sys.argv) != 2 or "." not in sys.argv[1]:
        print("Usage: python .windsurf/audit_table_columns_admin_rpc.py <schema.table>")
        return 1

    schema, table = sys.argv[1].split(".", 1)
    m = SupabaseAutoManager()

    sql = f"""
    SELECT column_name, data_type, is_nullable, column_default
    FROM information_schema.columns
    WHERE table_schema = '{schema}'
      AND table_name = '{table}'
    ORDER BY ordinal_position
    """.strip()

    res = run_sql(m, sql)

    out = {
        "schema": schema,
        "table": table,
        "result": res,
    }

    out_path = f".windsurf/logs/audit_table_columns_{schema}_{table}.json"
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)

    print(f"[OK] Saved {out_path}")
    if res.get("ok"):
        rows = res.get("rows") or []
        print(f"Columns: {len(rows)}")
        for r in rows:
            if isinstance(r, dict):
                print(f"- {r.get('column_name')} ({r.get('data_type')})")
    else:
        print(f"Error: {res.get('error')} ({res.get('sqlstate')})")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

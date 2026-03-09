#!/usr/bin/env python3
"""Dump storage.objects RLS policies (qual/with_check) via admin_execute_sql.

Writes .windsurf/logs/audit_storage_objects_policies_details.json
"""

import json
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
    m = SupabaseAutoManager()

    sql = """
    SELECT
      policyname,
      cmd,
      roles,
      qual,
      with_check
    FROM pg_policies
    WHERE schemaname='storage' AND tablename='objects'
    ORDER BY policyname
    """.strip()

    res = run_sql(m, sql)
    out_path = ".windsurf/logs/audit_storage_objects_policies_details.json"

    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(res, f, ensure_ascii=False, indent=2)

    print(f"[OK] Saved {out_path}")
    if res.get("ok"):
        for r in res.get("rows") or []:
            if isinstance(r, dict):
                print(f"- {r.get('policyname')} cmd={r.get('cmd')} roles={r.get('roles')} qual={r.get('qual')}")
    else:
        print(f"Error: {res.get('error')} {res.get('sqlstate')}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

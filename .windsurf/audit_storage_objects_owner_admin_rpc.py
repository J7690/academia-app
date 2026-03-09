#!/usr/bin/env python3
"""Audit who owns storage.objects and which role runs admin_execute_sql."""

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
            "rows": rows if isinstance(rows, list) else [],
            "error": data.get("error"),
            "sqlstate": data.get("sqlstate"),
        }

    if isinstance(data, list):
        return {"label": label, "http": resp.status_code, "ok": True, "mode": "select", "rows": data}

    return {"label": label, "http": resp.status_code, "ok": False, "error": "unexpected_json_type"}


def main() -> int:
    m = SupabaseAutoManager()

    queries: List[Tuple[str, str]] = [
        (
            "WHOAMI",
            """
            SELECT current_user, session_user
            """.strip(),
        ),
        (
            "STORAGE_OBJECTS_OWNER",
            """
            SELECT
              n.nspname AS schema,
              c.relname AS table,
              pg_get_userbyid(c.relowner) AS owner
            FROM pg_class c
            JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE n.nspname='storage' AND c.relname='objects'
            """.strip(),
        ),
    ]

    out: Dict[str, Any] = {}
    for label, sql in queries:
        res = run_sql(m, label, sql)
        out[label] = {
            "ok": res.get("ok"),
            "http": res.get("http"),
            "rows": res.get("rows"),
            "error": res.get("error"),
            "sqlstate": res.get("sqlstate"),
        }

    out_path = ".windsurf/logs/audit_storage_objects_owner.json"
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)

    print(f"[OK] Saved {out_path}")
    for k, v in out.items():
        print(k, v.get("rows"))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

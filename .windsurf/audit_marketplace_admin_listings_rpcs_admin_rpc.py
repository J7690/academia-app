#!/usr/bin/env python3
"""Audit existing admin marketplace listing RPCs.

Writes .windsurf/logs/audit_marketplace_admin_listings_rpcs.json
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
            "ADMIN_MARKETPLACE_LISTING_RPCS",
            """
            SELECT routine_name
            FROM information_schema.routines
            WHERE routine_schema='public'
              AND routine_name ILIKE 'app_admin_%marketplace%listing%'
            ORDER BY routine_name
            """.strip(),
        ),
    ]

    out: Dict[str, Any] = {}
    for label, sql in queries:
        print(f"Exécution: {label}...")
        res = run_sql(m, label, sql)
        out[label] = {
            "ok": res.get("ok"),
            "http": res.get("http"),
            "rows": res.get("rows"),
            "error": res.get("error"),
            "sqlstate": res.get("sqlstate"),
        }

    out_path = ".windsurf/logs/audit_marketplace_admin_listings_rpcs.json"
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)

    print(f"[OK] Saved {out_path}")
    rows = out["ADMIN_MARKETPLACE_LISTING_RPCS"].get("rows") or []
    print(f"RPCs: {len(rows)}")
    for r in rows:
        if isinstance(r, dict):
            print('-', r.get('routine_name'))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

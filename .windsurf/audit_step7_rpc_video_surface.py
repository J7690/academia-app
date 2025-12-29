#!/usr/bin/env python3
from __future__ import annotations

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

    return {"label": label, "http": resp.status_code, "ok": False, "error": "unexpected_json"}


def main() -> int:
    m = SupabaseAutoManager()

    queries: List[Tuple[str, str]] = [
        (
            "PUBLIC_RPCS_VIDEO_LIKE_NAMES",
            """
            SELECT routine_name, routine_type, data_type
            FROM information_schema.routines
            WHERE routine_schema = 'public'
              AND (
                routine_name ILIKE '%video%'
                OR routine_name ILIKE '%feed%'
                OR routine_name ILIKE '%landing%'
                OR routine_name ILIKE '%hero%'
                OR routine_name ILIKE '%university%'
                OR routine_name ILIKE '%challenge%'
              )
            ORDER BY routine_name
            """.strip(),
        ),
        (
            "PUBLIC_RPCS_DEFS_VIDEO_KEYWORDS",
            """
            SELECT n.nspname AS schema,
                   p.proname AS name,
                   pg_get_functiondef(p.oid) AS def
            FROM pg_proc p
            JOIN pg_namespace n ON n.oid = p.pronamespace
            WHERE n.nspname = 'public'
              AND (
                p.proname ILIKE '%video%'
                OR p.proname ILIKE '%feed%'
                OR p.proname ILIKE '%landing%'
                OR p.proname ILIKE '%hero%'
                OR p.proname ILIKE '%university%'
                OR p.proname ILIKE '%challenge%'
              )
            ORDER BY p.proname
            """.strip(),
        ),
    ]

    out: Dict[str, Any] = {}
    for label, sql in queries:
        out[label] = run_sql(m, label, sql, timeout=180)

    out_path = ".windsurf/logs/step7_rpc_video_surface.json"
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)

    print(f"[OK] wrote {out_path}")
    for k, v in out.items():
        rows = v.get("rows") if isinstance(v, dict) else None
        print(f"{k}: ok={v.get('ok')} rows={len(rows) if isinstance(rows, list) else 0}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
from __future__ import annotations

import json
from typing import Any, Dict

import requests

from supabase_auto_manager import SupabaseAutoManager


def run_sql(m: SupabaseAutoManager, sql: str, timeout: int = 60) -> Dict[str, Any]:
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    resp = requests.post(url, headers=m.headers, json={"p_sql": sql}, timeout=timeout)
    try:
        data = resp.json()
    except Exception:
        return {"http": resp.status_code, "ok": False, "raw": (resp.text or "")[:2000]}

    if isinstance(data, dict):
        # admin_execute_sql convention: top-level dict with ok/error fields
        return {"http": resp.status_code, **data}

    if isinstance(data, list):
        # SELECT mode: raw rows
        return {"http": resp.status_code, "ok": True, "mode": "select", "rows": data}

    return {"http": resp.status_code, "ok": False, "error": "unexpected_json"}


def main() -> int:
    m = SupabaseAutoManager()

    sql = """
        SELECT
          id,
          video_asset_id,
          media_type,
          title,
          sort_order,
          is_active,
          created_at,
          updated_at
        FROM app.landing_videos
        ORDER BY created_at DESC
        LIMIT 20
    """.strip()

    out = run_sql(m, sql)
    print(json.dumps(out, ensure_ascii=False, indent=2)[:6000])

    return 0 if out.get("ok") else 1


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
from __future__ import annotations

import json
from typing import Any, Dict

import requests

from supabase_auto_manager import SupabaseAutoManager


def admin_sql(m: SupabaseAutoManager, sql: str, timeout: int = 120) -> Dict[str, Any]:
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    resp = requests.post(url, headers=m.headers, json={"p_sql": sql}, timeout=timeout)
    try:
        data = resp.json()
    except Exception:
        return {"http": resp.status_code, "ok": False, "raw": (resp.text or "")[:2000]}

    if isinstance(data, dict):
        return {"http": resp.status_code, **data}
    if isinstance(data, list):
        return {"http": resp.status_code, "ok": True, "mode": "select", "rows": data}
    return {"http": resp.status_code, "ok": False, "error": "unexpected_json"}


def main() -> int:
    m = SupabaseAutoManager()

    # 1) pick a user id to simulate auth.uid()
    u = admin_sql(
        m,
        """
        SELECT id::text AS user_id
        FROM auth.users
        ORDER BY created_at DESC
        LIMIT 1
        """.strip(),
    )
    if not u.get("ok") or not u.get("rows"):
        print(json.dumps({"step": "pick_user", "result": u}, ensure_ascii=False, indent=2)[:4000])
        return 1

    user_id = u["rows"][0]["user_id"]

    # 2) call RPC in a single SELECT while setting JWT claim context
    res = admin_sql(
        m,
        f"""
        WITH _ AS (
          SELECT set_config('request.jwt.claim.sub', '{user_id}', true)
        )
        SELECT app_student_unified_video_feed(NULL, 5) AS payload
        """.strip(),
        timeout=180,
    )

    print(json.dumps({"simulated_user_id": user_id, "rpc": res}, ensure_ascii=False, indent=2)[:7000])
    return 0 if res.get("ok") else 1


if __name__ == "__main__":
    raise SystemExit(main())

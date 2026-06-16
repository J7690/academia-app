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
        return {"http": resp.status_code, "ok": False, "raw": (resp.text or '')[:2000]}

    if isinstance(data, dict):
        # admin_execute_sql convention: top-level dict with ok/error fields
        return {"http": resp.status_code, **data}

    if isinstance(data, list):
        # SELECT mode: raw rows
        return {"http": resp.status_code, "ok": True, "mode": "select", "rows": data}

    return {"http": resp.status_code, "ok": False, "error": "unexpected_json"}


def main() -> int:
    m = SupabaseAutoManager()

    checks = {
        "rpcs_free": """
            SELECT routine_name, data_type
            FROM information_schema.routines
            WHERE routine_schema = 'public'
              AND routine_name IN (
                'app_student_create_free_video',
                'app_student_set_free_video_main_renditions',
                'app_student_get_free_video'
              )
            ORDER BY routine_name
        """.strip(),
        "rpc_call_get_nonexistent": """
            SELECT app_student_get_free_video(gen_random_uuid()) AS payload
        """.strip(),
        "rpc_call_create_invalid_asset": """
            SELECT app_student_create_free_video(
                NULL::uuid,
                '{"best_url": "https://example.com/video.mp4", "poster_url": "https://example.com/poster.jpg"}'::jsonb,
                'Test Free',
                'Description de test'
            ) AS payload
        """.strip(),
        "feed_unified": """
            SELECT app_student_unified_video_feed(NULL::timestamptz, 5) AS payload
        """.strip(),
    }

    out: Dict[str, Any] = {}
    for label, sql in checks.items():
        out[label] = run_sql(m, sql)

    print(json.dumps(out, ensure_ascii=False, indent=2)[:6000])

    ok = True
    for label in checks.keys():
        if not out.get(label, {}).get("ok"):
            ok = False

    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())

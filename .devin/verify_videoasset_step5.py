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
        return {"http": resp.status_code, **data}

    # Back-compat if RPC returns raw list
    if isinstance(data, list):
        return {"http": resp.status_code, "ok": True, "mode": "select", "rows": data}

    return {"http": resp.status_code, "ok": False, "error": "unexpected_json"}


def main() -> int:
    m = SupabaseAutoManager()

    checks = {
        "tables": """
            SELECT table_name
            FROM information_schema.tables
            WHERE table_schema = 'app'
              AND table_name IN (
                'video_assets',
                'video_sources',
                'video_renditions',
                'video_asset_contexts',
                'video_processing_jobs'
              )
            ORDER BY table_name
        """.strip(),
        "rpcs": """
            SELECT routine_name, routine_type
            FROM information_schema.routines
            WHERE routine_schema = 'public'
              AND routine_name IN (
                'app_videoasset_create_upload_intent',
                'app_videoasset_register_uploaded_source',
                'app_videoasset_get_playback_manifest'
              )
            ORDER BY routine_name
        """.strip(),
        "policies": """
            SELECT tablename, policyname, cmd
            FROM pg_policies
            WHERE schemaname = 'app'
              AND tablename IN (
                'video_assets',
                'video_sources',
                'video_renditions',
                'video_asset_contexts',
                'video_processing_jobs'
              )
            ORDER BY tablename, policyname
        """.strip(),
    }

    out: Dict[str, Any] = {}
    for label, sql in checks.items():
        out[label] = run_sql(m, sql)

    print(json.dumps(out, ensure_ascii=False, indent=2)[:6000])

    ok = True
    for label in ("tables", "rpcs", "policies"):
        if not out.get(label, {}).get("ok"):
            ok = False

    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())

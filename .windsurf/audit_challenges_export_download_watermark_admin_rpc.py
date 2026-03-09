#!/usr/bin/env python3
"""Audit export/download + watermark (Challenges) via admin_execute_sql.
Lecture seule.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import requests

sys.path.insert(0, str(Path(__file__).parent))
from supabase_auto_manager import SupabaseAutoManager


def run_sql(label: str, sql: str) -> None:
    m = SupabaseAutoManager()
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    print(f"\n{'='*80}\n{label}\n{'='*80}")
    resp = requests.post(url, headers=m.headers, json={"p_sql": sql}, timeout=120)
    print("STATUS", resp.status_code)
    try:
        data = resp.json()
    except Exception:
        print(resp.text[:2000])
        return
    print(json.dumps(data, ensure_ascii=False, indent=2)[:3500])


def main() -> int:
    run_sql(
        "COLS_video_renditions",
        """SELECT column_name, data_type, is_nullable
            FROM information_schema.columns
            WHERE table_schema='app' AND table_name='video_renditions'
            ORDER BY ordinal_position""",
    )
    run_sql(
        "SAMPLE_renditions_urls",
        """SELECT id, video_asset_id, rendition_key, kind, status, public_url_hint, created_at
            FROM app.video_renditions
            WHERE public_url_hint IS NOT NULL
            ORDER BY created_at DESC
            LIMIT 10""",
    )
    run_sql(
        "RPC_feed_list",
        """SELECT routine_schema, routine_name
            FROM information_schema.routines
            WHERE routine_schema='public'
              AND routine_name IN ('app_student_unified_video_feed','app_student_list_user_videos')
            ORDER BY routine_name""",
    )
    run_sql(
        "SRC_unified_feed",
        """SELECT pg_get_functiondef(p.oid) AS src
            FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid
            WHERE n.nspname='public' AND p.proname='app_student_unified_video_feed'""",
    )
    run_sql(
        "SRC_list_user_videos",
        """SELECT pg_get_functiondef(p.oid) AS src
            FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid
            WHERE n.nspname='public' AND p.proname='app_student_list_user_videos'""",
    )
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

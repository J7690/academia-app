#!/usr/bin/env python3
"""Audit allow_download (download permissions) for challenge/free videos via admin_execute_sql.
Read-only.
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
    print(sql.strip())
    resp = requests.post(url, headers=m.headers, json={"p_sql": sql}, timeout=120)
    print("STATUS", resp.status_code)
    try:
        data = resp.json()
    except Exception:
        print(resp.text[:2000])
        return
    print(json.dumps(data, ensure_ascii=False, indent=2)[:4000])


def main() -> int:
    run_sql(
        "COLS_challenge_participations_download",
        """
        SELECT column_name, data_type, is_nullable, column_default
        FROM information_schema.columns
        WHERE table_schema='app' AND table_name='challenge_participations'
          AND column_name ILIKE '%download%'
        ORDER BY ordinal_position
        """,
    )

    run_sql(
        "COLS_free_videos_download",
        """
        SELECT column_name, data_type, is_nullable, column_default
        FROM information_schema.columns
        WHERE table_schema='app' AND table_name='free_videos'
          AND column_name ILIKE '%download%'
        ORDER BY ordinal_position
        """,
    )

    run_sql(
        "COLS_challenge_participations_owner",
        """
        SELECT column_name, data_type, is_nullable
        FROM information_schema.columns
        WHERE table_schema='app' AND table_name='challenge_participations'
          AND column_name IN ('user_id','is_active','is_deleted','deleted_at')
        ORDER BY ordinal_position
        """,
    )

    run_sql(
        "COLS_free_videos_owner",
        """
        SELECT column_name, data_type, is_nullable
        FROM information_schema.columns
        WHERE table_schema='app' AND table_name='free_videos'
          AND column_name IN ('user_id','is_active','is_deleted','deleted_at')
        ORDER BY ordinal_position
        """,
    )

    run_sql(
        "SRC_unified_feed_excerpt",
        """
        SELECT pg_get_functiondef(p.oid) AS src
        FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid
        WHERE n.nspname='public' AND p.proname='app_student_unified_video_feed'
        """,
    )

    run_sql(
        "SRC_list_user_videos_excerpt",
        """
        SELECT pg_get_functiondef(p.oid) AS src
        FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid
        WHERE n.nspname='public' AND p.proname='app_student_list_user_videos'
        """,
    )

    return 0


if __name__ == '__main__':
    raise SystemExit(main())

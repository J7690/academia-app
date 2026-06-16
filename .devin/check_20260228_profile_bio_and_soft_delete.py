#!/usr/bin/env python3
"""Vérifie que la migration 2026-02-28 est bien appliquée.

- colonnes ajoutées (bio/website_url, is_deleted/deleted_at)
- RPCs créées (update_profile, soft_delete, restore, recently_deleted)
- RPCs patchées (unified_feed, list_user_videos) contiennent le filtre is_deleted
"""

from __future__ import annotations

import json
from typing import Any, Dict

import requests

from supabase_auto_manager import SupabaseAutoManager


def run_sql(m: SupabaseAutoManager, sql: str, timeout: int = 120) -> Dict[str, Any]:
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    resp = requests.post(url, headers=m.headers, json={"p_sql": sql.rstrip().rstrip(";")}, timeout=timeout)
    try:
        data = resp.json()
    except Exception:
        return {"ok": False, "http": resp.status_code, "raw": (resp.text or "")[:2000]}

    if not isinstance(data, dict):
        return {"ok": False, "http": resp.status_code, "raw": str(data)[:2000]}

    if data.get("ok") is False:
        return {"ok": False, "http": resp.status_code, "error": data.get("error"), "sqlstate": data.get("sqlstate")}

    return {"ok": True, "http": resp.status_code, "rows": data.get("rows", [])}


def show(title: str, res: Dict[str, Any]) -> None:
    print("\n" + "=" * 100)
    print(title)
    print("=" * 100)
    if not res.get("ok"):
        print(json.dumps(res, ensure_ascii=False, indent=2)[:4000])
        return
    rows = res.get("rows")
    print(json.dumps(rows, ensure_ascii=False, indent=2)[:8000])


def main() -> int:
    m = SupabaseAutoManager()

    show(
        "COLUMNS app.students (bio, website_url)",
        run_sql(
            m,
            """
            SELECT column_name, data_type, is_nullable
            FROM information_schema.columns
            WHERE table_schema = 'app'
              AND table_name = 'students'
              AND column_name IN ('bio', 'website_url')
            ORDER BY column_name
            """.strip(),
        ),
    )

    show(
        "COLUMNS app.challenge_participations (is_deleted, deleted_at)",
        run_sql(
            m,
            """
            SELECT column_name, data_type, is_nullable, column_default
            FROM information_schema.columns
            WHERE table_schema = 'app'
              AND table_name = 'challenge_participations'
              AND column_name IN ('is_deleted', 'deleted_at')
            ORDER BY column_name
            """.strip(),
        ),
    )

    show(
        "COLUMNS app.free_videos (is_deleted, deleted_at)",
        run_sql(
            m,
            """
            SELECT column_name, data_type, is_nullable, column_default
            FROM information_schema.columns
            WHERE table_schema = 'app'
              AND table_name = 'free_videos'
              AND column_name IN ('is_deleted', 'deleted_at')
            ORDER BY column_name
            """.strip(),
        ),
    )

    show(
        "RPCs created", 
        run_sql(
            m,
            """
            SELECT p.proname
            FROM pg_proc p
            JOIN pg_namespace n ON n.oid = p.pronamespace
            WHERE n.nspname = 'public'
              AND p.proname IN (
                'app_student_update_my_profile',
                'app_student_soft_delete_video',
                'app_student_restore_video',
                'app_student_list_recently_deleted_videos'
              )
            ORDER BY p.proname
            """.strip(),
        ),
    )

    res = run_sql(
        m,
        """
        SELECT pg_get_functiondef(p.oid) AS def
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
          AND p.proname = 'app_student_unified_video_feed'
        """.strip(),
        timeout=180,
    )
    show("DEF app_student_unified_video_feed (excerpt)", res)

    res2 = run_sql(
        m,
        """
        SELECT pg_get_functiondef(p.oid) AS def
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
          AND p.proname = 'app_student_list_user_videos'
        """.strip(),
        timeout=180,
    )
    show("DEF app_student_list_user_videos (excerpt)", res2)

    return 0


if __name__ == '__main__':
    raise SystemExit(main())

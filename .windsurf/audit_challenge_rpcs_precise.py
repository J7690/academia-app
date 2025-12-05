#!/usr/bin/env python3
"""Audit ciblé des RPC et tables challenges/video dans Supabase via admin_execute_sql.

Lecture seule, aucun DDL/DML.
"""

from __future__ import annotations

import json
import requests

from supabase_auto_manager import SupabaseAutoManager


def run_sql(label: str, sql: str) -> None:
    m = SupabaseAutoManager()
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"

    print(f"\n=== {label} ===")
    print(sql)
    try:
        resp = requests.post(url, headers=m.headers, json={"p_sql": sql}, timeout=60)
    except Exception as exc:
        print(f"[ERROR] Réseau admin_execute_sql: {exc}")
        return

    print("STATUS", resp.status_code)
    try:
        data = resp.json()
    except Exception:
        print(resp.text[:2000])
        return

    print(json.dumps(data, ensure_ascii=False, indent=2)[:2000])


def main() -> int:
    # 1) Tables challenges vidéo
    run_sql(
        "TABLES_challenge_core",
        """
        SELECT table_schema, table_name
        FROM information_schema.tables
        WHERE table_schema = 'app'
          AND table_name IN (
            'challenge_participations',
            'challenge_participation_videos',
            'challenge_video_render_jobs'
          )
        ORDER BY table_name
        """,
    )

    # 2) RPC publiques critiques pour le pipeline vidéo étudiant
    run_sql(
        "RPC_challenge_student_core",
        """
        SELECT routine_schema, routine_name, specific_name
        FROM information_schema.routines
        WHERE routine_schema = 'public'
          AND routine_name IN (
            'app_student_submit_challenge',
            'app_student_add_challenge_video',
            'app_student_set_challenge_main_video',
            'app_student_challenge_video_feed'
          )
        ORDER BY routine_name
        """,
    )

    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())

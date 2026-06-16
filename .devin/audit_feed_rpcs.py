#!/usr/bin/env python3
"""Audit all RPCs used by the Challenge video feed screen.

Checks existence of every RPC called from student_challenges_provider.dart
for: like, unlike, favorite, unfavorite, comment, report, duo, share, feed.

Read-only — no DDL/DML.
"""

from __future__ import annotations

import json
import requests

from supabase_auto_manager import SupabaseAutoManager


def run_sql(label: str, sql: str) -> list | None:
    m = SupabaseAutoManager()

    print(f"\n=== {label} ===")

    # Try execute_sql first (returns rows)
    for rpc_name in ["execute_sql", "admin_execute_sql"]:
        url = f"{m.url}/rest/v1/rpc/{rpc_name}"
        param_key = "sql_query" if rpc_name == "execute_sql" else "p_sql"
        try:
            resp = requests.post(url, headers=m.headers, json={param_key: sql}, timeout=60)
        except Exception as exc:
            print(f"[ERROR] {rpc_name}: {exc}")
            continue

        if resp.status_code == 200:
            data = resp.json()
            if isinstance(data, list):
                print(f"[{rpc_name}] {len(data)} rows")
                for row in data:
                    print(f"  {row}")
                return data
            elif isinstance(data, dict):
                rows = data.get("rows") or data.get("data") or data.get("result")
                if rows and isinstance(rows, list):
                    print(f"[{rpc_name}] {len(rows)} rows")
                    for row in rows:
                        print(f"  {row}")
                    return rows
                print(f"[{rpc_name}] response: {json.dumps(data, ensure_ascii=False)[:1500]}")
                return []
        else:
            print(f"[{rpc_name}] STATUS {resp.status_code}: {resp.text[:500]}")

    return None


def main() -> int:
    # All RPCs called by the feed buttons
    rpcs = [
        # Feed
        'app_student_unified_video_feed',
        # Like / Unlike (challenge)
        'app_student_like_challenge_video',
        'app_student_unlike_challenge_video',
        # Like / Unlike (generic)
        'app_student_video_like',
        'app_student_video_unlike',
        # Favorite / Unfavorite (challenge)
        'app_student_favorite_challenge_video',
        'app_student_unfavorite_challenge_video',
        # Favorite / Unfavorite (generic)
        'app_student_video_favorite',
        'app_student_video_unfavorite',
        # Comments (challenge)
        'app_student_list_challenge_comments',
        'app_student_add_challenge_comment',
        # Comments (generic)
        'app_student_list_video_comments',
        'app_student_add_video_comment',
        # Report (challenge)
        'app_student_report_challenge_video',
        # Report (generic)
        'app_student_report_video',
        # Duo (challenge)
        'app_student_start_duo_challenge_video',
        # Duo (generic)
        'app_student_start_duo_video',
    ]

    rpc_list = ", ".join(f"'{r}'" for r in rpcs)

    run_sql(
        "CHECK_ALL_FEED_RPCS_EXIST",
        f"""
        SELECT routine_name
        FROM information_schema.routines
        WHERE routine_schema = 'public'
          AND routine_name IN ({rpc_list})
        ORDER BY routine_name
        """,
    )

    # Also check what parameters each existing RPC expects
    run_sql(
        "RPC_PARAMETERS",
        f"""
        SELECT r.routine_name, p.parameter_name, p.data_type, p.parameter_mode
        FROM information_schema.routines r
        LEFT JOIN information_schema.parameters p
          ON p.specific_name = r.specific_name
          AND p.specific_schema = r.specific_schema
        WHERE r.routine_schema = 'public'
          AND r.routine_name IN ({rpc_list})
          AND p.parameter_mode = 'IN'
        ORDER BY r.routine_name, p.ordinal_position
        """,
    )

    # Check tables used: video_likes, video_favorites, video_comments, video_reports
    run_sql(
        "CHECK_SOCIAL_TABLES",
        """
        SELECT table_schema, table_name
        FROM information_schema.tables
        WHERE table_schema = 'app'
          AND table_name IN (
            'video_likes', 'video_favorites', 'video_comments', 'video_reports',
            'challenge_video_likes', 'challenge_video_favorites',
            'challenge_video_comments', 'challenge_video_reports'
          )
        ORDER BY table_name
        """,
    )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

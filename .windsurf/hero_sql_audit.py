#!/usr/bin/env python3
"""Audit ciblé des surfaces Hero via admin_execute_sql.

Toutes les requêtes sont en lecture seule (SELECT).
"""
from __future__ import annotations

import json
from textwrap import dedent

import requests

from supabase_auto_manager import SupabaseAutoManager


QUERIES = [
    (
        "landing_config_columns",
        """
        SELECT table_schema, table_name, column_name, data_type
        FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'landing_config'
        ORDER BY ordinal_position;
        """,
    ),
    (
        "landing_config_sample",
        """
        SELECT id, hero_badge_text, hero_title, hero_subtitle,
               primary_color, secondary_color, accent_color,
               created_at, updated_at
        FROM app.landing_config
        ORDER BY created_at DESC
        LIMIT 3;
        """,
    ),
    (
        "func_app_admin_upsert_landing_config",
        """
        SELECT pg_get_functiondef(p.oid) AS definition
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
          AND p.proname = 'app_admin_upsert_landing_config';
        """,
    ),
    (
        "hero_playlist_landing_and_student_home",
        """
        SELECT slot, media_type, base_video_url, base_image_url,
               sort_order, is_active
        FROM app.hero_playlist
        WHERE slot IN ('landing_hero_main', 'student_home_hero_main')
        ORDER BY slot, sort_order
        LIMIT 10;
        """,
    ),
    (
        "student_home_videos_sample",
        """
        SELECT id, video_url, media_type, is_active, created_at
        FROM app.student_home_videos
        ORDER BY created_at DESC
        LIMIT 5;
        """,
    ),
    (
        "university_media_sample",
        """
        SELECT id, media_type, url, storage_path, is_active, created_at
        FROM app.university_media
        ORDER BY created_at DESC
        LIMIT 5;
        """,
    ),
]


def main() -> int:
    manager = SupabaseAutoManager()
    url = f"{manager.url}/rest/v1/rpc/admin_execute_sql"

    for label, sql in QUERIES:
        print("\n===== QUERY:", label, "=====")
        # admin_execute_sql enveloppe la requête dans un SELECT ... FROM (<p_sql>) t.
        # Il ne faut donc pas laisser de point-virgule final, sinon on obtient
        # un "syntax error at or near ';'" côté Postgres.
        clean_sql = dedent(sql).strip().rstrip(";")
        payload = {"p_sql": clean_sql}
        try:
            resp = requests.post(url, headers=manager.headers, json=payload, timeout=30)
        except Exception as exc:  # pragma: no cover
            print("[ERROR] Network error:", exc)
            continue

        print("HTTP", resp.status_code)
        try:
            data = resp.json()
        except Exception:
            print(resp.text[:1000])
            continue

        # admin_execute_sql (extend_*_return_rows) retourne normalement
        # { ok: bool, mode: 'select'|'exec', rows?: [...] }
        print(json.dumps(data, indent=2, ensure_ascii=False)[:4000])

    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())

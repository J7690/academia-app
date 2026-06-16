#!/usr/bin/env python3
"""Audit global des médias Mux dans Supabase (lecture seule).

Ce script utilise la RPC admin_execute_sql via SupabaseAutoManager pour repérer
les enregistrements qui référencent encore Mux (stream.mux.com) dans les
principales tables applicatives :
- app.course_resources
- app.landing_config
- app.landing_videos
- app.student_home_videos
- app.university_media

Aucune écriture n'est effectuée, c'est un audit pur.
"""

from __future__ import annotations

import json
from typing import List, Tuple

import requests

from supabase_auto_manager import SupabaseAutoManager


def run_sql(manager: SupabaseAutoManager, label: str, sql: str) -> None:
    base = manager.url
    headers = manager.headers
    url = f"{base}/rest/v1/rpc/admin_execute_sql"

    print(f"\n=== {label} ===")
    print(sql)

    try:
        r = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
    except Exception as exc:
        print(f"❌ Erreur réseau pour {label}: {exc}")
        return

    print("HTTP", r.status_code)
    try:
        data = r.json()
    except Exception:
        print(r.text[:1000])
        return

    # admin_execute_sql peut renvoyer soit un objet (avec ok/rows), soit
    # directement une liste de lignes. On gère les deux cas pour un audit lisible.
    if isinstance(data, dict):
        rows = data.get("rows")
        if rows is not None:
            print("rows (trunc):")
            print(json.dumps(rows, indent=2, ensure_ascii=False)[:1000])
        else:
            print(json.dumps(data, indent=2, ensure_ascii=False)[:1000])
    else:
        # Liste ou autre structure JSON
        print(json.dumps(data, indent=2, ensure_ascii=False)[:1000])


def main() -> int:
    m = SupabaseAutoManager()

    queries: List[Tuple[str, str]] = [
        (
            "course_resources_mux",
            """SELECT id, title, resource_type,
                       storage_bucket, storage_path,
                       external_url,
                       created_at
                FROM app.course_resources
                WHERE COALESCE(external_url, '') ILIKE '%stream.mux.com%'
                   OR COALESCE(storage_bucket, '') ILIKE '%stream.mux.com%'
                ORDER BY created_at DESC
                LIMIT 50""",
        ),
        (
            "landing_videos_mux",
            """SELECT id, title, video_url, is_active, created_at
                FROM app.landing_videos
                WHERE COALESCE(video_url, '') ILIKE '%stream.mux.com%'
                ORDER BY created_at DESC
                LIMIT 50""",
        ),
        (
            "landing_config_mux",
            """SELECT id, video_url, created_at, updated_at
                FROM app.landing_config
                WHERE COALESCE(video_url, '') ILIKE '%stream.mux.com%'
                ORDER BY created_at DESC
                LIMIT 20""",
        ),
        (
            "student_home_videos_mux",
            """SELECT id, title, video_url, is_active, created_at
                FROM app.student_home_videos
                WHERE COALESCE(video_url, '') ILIKE '%stream.mux.com%'
                ORDER BY created_at DESC
                LIMIT 50""",
        ),
        (
            "university_media_mux",
            """SELECT id, title, media_type, url, storage_path, is_active, created_at
                FROM app.university_media
                WHERE COALESCE(url, '') ILIKE '%stream.mux.com%'
                ORDER BY created_at DESC
                LIMIT 50""",
        ),
    ]

    for label, sql in queries:
        run_sql(m, label, sql)

    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())

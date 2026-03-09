#!/usr/bin/env python3
"""Audit des tables et fonctions Supabase pour le système de vidéo challenge.

Utilise la RPC execute_sql exposée par Supabase et les en-têtes RPC
standard définis dans .windsurf/auto_supabase_import.py.

Ne fait que des SELECT (aucune modification de données).
"""

from __future__ import annotations

import json
from typing import Any, Dict, List

import requests

from auto_supabase_import import SUPABASE_URL, RPC_HEADERS

EXECUTE_SQL_URL = f"{SUPABASE_URL}/rest/v1/rpc/execute_sql"


def execute_sql(label: str, sql: str) -> List[Dict[str, Any]]:
    print("\n===", label, "===")
    print(sql)
    resp = requests.post(
        EXECUTE_SQL_URL,
        headers=RPC_HEADERS,
        json={"sql_query": sql},
        timeout=60,
    )
    print("STATUS", resp.status_code)
    try:
        data = resp.json()
    except Exception:
        print("RAW", resp.text[:2000])
        return []

    # execute_sql renvoie typiquement une liste de lignes, ou un dict avec une clé error
    if isinstance(data, dict) and "error" in data:
        print("ERROR_BODY", json.dumps(data, ensure_ascii=False, indent=2)[:2000])
        return []
    if isinstance(data, list):
        print(json.dumps(data, ensure_ascii=False, indent=2)[:2000])
        return data
    if data is None:
        print("(no rows)")
        return []
    print("UNEXPECTED", repr(data)[:2000])
    return []


def main() -> int:
    # 1) Lister les tables app.challenge_*
    execute_sql(
        "TABLES_app_challenge",
        """
        SELECT table_schema, table_name
        FROM information_schema.tables
        WHERE table_schema = 'app'
          AND table_name LIKE 'challenge%'
        ORDER BY table_name
        """,
    )

    # 2) Décrire app.challenge_participations
    execute_sql(
        "COLUMNS_app.challenge_participations",
        """
        SELECT column_name, data_type, is_nullable
        FROM information_schema.columns
        WHERE table_schema = 'app'
          AND table_name = 'challenge_participations'
        ORDER BY ordinal_position
        """,
    )

    # 3) Lister les fonctions (RPC) app_*challenge* / app_*video* dans le schéma public
    execute_sql(
        "RPC_public_app_challenge_video_functions",
        """
        SELECT routine_schema, routine_name, routine_type
        FROM information_schema.routines
        WHERE routine_schema = 'public'
          AND (
            routine_name ILIKE 'app%challenge%'
            OR routine_name ILIKE 'app%video%'
          )
        ORDER BY routine_name
        """,
    )

    # 4) Lister quelques participations avec vidéo (submission_url ou video_url)
    execute_sql(
        "SAMPLE_participations_with_video",
        """
        SELECT
          id,
          challenge_id,
          user_id,
          status,
          submission_url,
          video_url,
          COALESCE(submitted_at, started_at) AS ts
        FROM app.challenge_participations
        WHERE is_active = TRUE
          AND (submission_url IS NOT NULL OR video_url IS NOT NULL)
        ORDER BY ts DESC
        LIMIT 10
        """,
    )

    # 5) Synthèse des flags video_url / submission_url sur les participations actives
    execute_sql(
        "SUMMARY_challenge_participations_video_flags",
        """
        SELECT
          COUNT(*) AS total,
          COUNT(*) FILTER (WHERE submission_url IS NOT NULL) AS with_submission,
          COUNT(*) FILTER (WHERE video_url IS NOT NULL) AS with_video,
          COUNT(*) FILTER (WHERE submission_url IS NOT NULL AND video_url IS NULL) AS submission_without_video,
          COUNT(*) FILTER (WHERE submission_url IS NOT NULL AND video_url = submission_url) AS video_equals_submission,
          COUNT(*) FILTER (WHERE video_url LIKE '%/renders/%') AS video_is_render
        FROM app.challenge_participations
        WHERE is_active = TRUE
        """,
    )

    # 6) Aperçu des vidéos associées aux participations
    execute_sql(
        "SAMPLE_challenge_participation_videos",
        """
        SELECT
          id,
          participation_id,
          video_url,
          thumbnail_url,
          created_at
        FROM app.challenge_participation_videos
        ORDER BY created_at DESC
        LIMIT 10
        """,
    )

    # 7) Synthèse et échantillon des jobs de rendu vidéo
    execute_sql(
        "SUMMARY_challenge_video_render_jobs",
        """
        SELECT status, COUNT(*) AS count
        FROM app.challenge_video_render_jobs
        GROUP BY status
        ORDER BY status
        """,
    )

    execute_sql(
        "SAMPLE_challenge_video_render_jobs",
        """
        SELECT
          id,
          participation_id,
          status,
          error_message,
          created_at,
          completed_at
        FROM app.challenge_video_render_jobs
        ORDER BY created_at DESC
        LIMIT 10
        """,
    )

    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())

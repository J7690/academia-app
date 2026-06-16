#!/usr/bin/env python3
"""Audit brut des colonnes Supabase — affiche le JSON brut pour debug."""

import requests
import json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
HEADERS = {
    "apikey": KEY,
    "Authorization": f"Bearer {KEY}",
    "Content-Type": "application/json",
    "Accept": "application/json",
}


def run_sql(label, sql):
    print(f"\n{'='*70}")
    print(f"  {label}")
    print(f"{'='*70}")
    resp = requests.post(
        f"{URL}/rest/v1/rpc/admin_execute_sql",
        headers=HEADERS,
        json={"p_sql": sql},
        timeout=30,
    )
    print(f"  Status: {resp.status_code}")
    try:
        data = resp.json()
        print(f"  Type: {type(data).__name__}")
        print(json.dumps(data, indent=2, ensure_ascii=False, default=str)[:3000])
    except Exception:
        print(f"  Raw: {resp.text[:2000]}")
    return resp


def main():
    # 1) Colonnes de challenge_participations
    run_sql("COLONNES: app.challenge_participations", """
        SELECT column_name, data_type, is_nullable
        FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'challenge_participations'
        ORDER BY ordinal_position
    """)

    # 2) Colonnes de free_videos
    run_sql("COLONNES: app.free_videos", """
        SELECT column_name, data_type, is_nullable
        FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'free_videos'
        ORDER BY ordinal_position
    """)

    # 3) Colonnes de challenges
    run_sql("COLONNES: app.challenges", """
        SELECT column_name, data_type, is_nullable
        FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'challenges'
        ORDER BY ordinal_position
    """)

    # 4) Toutes les tables du schema app
    run_sql("TOUTES LES TABLES schema 'app'", """
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = 'app'
        ORDER BY table_name
    """)

    # 5) Colonnes video_likes
    run_sql("COLONNES: app.video_likes", """
        SELECT column_name, data_type
        FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'video_likes'
        ORDER BY ordinal_position
    """)

    # 6) Colonnes video_comments
    run_sql("COLONNES: app.video_comments", """
        SELECT column_name, data_type
        FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'video_comments'
        ORDER BY ordinal_position
    """)

    # 7) Colonnes video_reports
    run_sql("COLONNES: app.video_reports", """
        SELECT column_name, data_type
        FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'video_reports'
        ORDER BY ordinal_position
    """)

    # 8) Colonnes challenge_favorites
    run_sql("COLONNES: app.challenge_favorites", """
        SELECT column_name, data_type
        FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'challenge_favorites'
        ORDER BY ordinal_position
    """)

    # 9) Colonnes challenge_video_overlays
    run_sql("COLONNES: app.challenge_video_overlays", """
        SELECT column_name, data_type
        FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'challenge_video_overlays'
        ORDER BY ordinal_position
    """)

    # 10) Colonnes free_video_overlays
    run_sql("COLONNES: app.free_video_overlays", """
        SELECT column_name, data_type
        FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'free_video_overlays'
        ORDER BY ordinal_position
    """)


if __name__ == "__main__":
    main()

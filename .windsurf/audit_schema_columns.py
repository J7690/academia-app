#!/usr/bin/env python3
"""Audit des colonnes réelles des tables Supabase vs colonnes utilisées dans les RPCs."""

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


def run_sql(sql: str):
    resp = requests.post(
        f"{URL}/rest/v1/rpc/admin_execute_sql",
        headers=HEADERS,
        json={"p_sql": sql},
        timeout=30,
    )
    if resp.status_code == 200:
        return resp.json()
    print(f"[ERROR {resp.status_code}] {resp.text[:500]}")
    return None


def main():
    # 1) Lister les colonnes de app.challenge_participations
    print("=" * 70)
    print("TABLE: app.challenge_participations")
    print("=" * 70)
    result = run_sql("""
        SELECT column_name, data_type, is_nullable
        FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'challenge_participations'
        ORDER BY ordinal_position
    """)
    if result:
        data = result if isinstance(result, list) else [result]
        for row in data:
            if isinstance(row, dict):
                print(f"  {row.get('column_name', '?'):40s} {row.get('data_type', '?'):20s} nullable={row.get('is_nullable', '?')}")
            else:
                print(f"  {row}")

    # 2) Lister les colonnes de app.free_videos
    print()
    print("=" * 70)
    print("TABLE: app.free_videos")
    print("=" * 70)
    result = run_sql("""
        SELECT column_name, data_type, is_nullable
        FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'free_videos'
        ORDER BY ordinal_position
    """)
    if result:
        data = result if isinstance(result, list) else [result]
        for row in data:
            if isinstance(row, dict):
                print(f"  {row.get('column_name', '?'):40s} {row.get('data_type', '?'):20s} nullable={row.get('is_nullable', '?')}")
            else:
                print(f"  {row}")

    # 3) Lister les colonnes de app.challenges
    print()
    print("=" * 70)
    print("TABLE: app.challenges")
    print("=" * 70)
    result = run_sql("""
        SELECT column_name, data_type, is_nullable
        FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'challenges'
        ORDER BY ordinal_position
    """)
    if result:
        data = result if isinstance(result, list) else [result]
        for row in data:
            if isinstance(row, dict):
                print(f"  {row.get('column_name', '?'):40s} {row.get('data_type', '?'):20s} nullable={row.get('is_nullable', '?')}")
            else:
                print(f"  {row}")

    # 4) Lister les colonnes de app.video_likes
    print()
    print("=" * 70)
    print("TABLE: app.video_likes")
    print("=" * 70)
    result = run_sql("""
        SELECT column_name, data_type, is_nullable
        FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'video_likes'
        ORDER BY ordinal_position
    """)
    if result:
        data = result if isinstance(result, list) else [result]
        for row in data:
            if isinstance(row, dict):
                print(f"  {row.get('column_name', '?'):40s} {row.get('data_type', '?'):20s} nullable={row.get('is_nullable', '?')}")
            else:
                print(f"  {row}")

    # 5) Lister les colonnes de app.video_comments
    print()
    print("=" * 70)
    print("TABLE: app.video_comments")
    print("=" * 70)
    result = run_sql("""
        SELECT column_name, data_type, is_nullable
        FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'video_comments'
        ORDER BY ordinal_position
    """)
    if result:
        data = result if isinstance(result, list) else [result]
        for row in data:
            if isinstance(row, dict):
                print(f"  {row.get('column_name', '?'):40s} {row.get('data_type', '?'):20s} nullable={row.get('is_nullable', '?')}")
            else:
                print(f"  {row}")

    # 6) Lister les colonnes de app.video_reports
    print()
    print("=" * 70)
    print("TABLE: app.video_reports")
    print("=" * 70)
    result = run_sql("""
        SELECT column_name, data_type, is_nullable
        FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'video_reports'
        ORDER BY ordinal_position
    """)
    if result:
        data = result if isinstance(result, list) else [result]
        for row in data:
            if isinstance(row, dict):
                print(f"  {row.get('column_name', '?'):40s} {row.get('data_type', '?'):20s} nullable={row.get('is_nullable', '?')}")
            else:
                print(f"  {row}")

    # 7) Lister les colonnes de app.challenge_favorites
    print()
    print("=" * 70)
    print("TABLE: app.challenge_favorites")
    print("=" * 70)
    result = run_sql("""
        SELECT column_name, data_type, is_nullable
        FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'challenge_favorites'
        ORDER BY ordinal_position
    """)
    if result:
        data = result if isinstance(result, list) else [result]
        for row in data:
            if isinstance(row, dict):
                print(f"  {row.get('column_name', '?'):40s} {row.get('data_type', '?'):20s} nullable={row.get('is_nullable', '?')}")
            else:
                print(f"  {row}")

    # 8) Lister les colonnes de app.challenge_video_overlays
    print()
    print("=" * 70)
    print("TABLE: app.challenge_video_overlays")
    print("=" * 70)
    result = run_sql("""
        SELECT column_name, data_type, is_nullable
        FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'challenge_video_overlays'
        ORDER BY ordinal_position
    """)
    if result:
        data = result if isinstance(result, list) else [result]
        for row in data:
            if isinstance(row, dict):
                print(f"  {row.get('column_name', '?'):40s} {row.get('data_type', '?'):20s} nullable={row.get('is_nullable', '?')}")
            else:
                print(f"  {row}")

    # 9) Lister les colonnes de app.free_video_overlays
    print()
    print("=" * 70)
    print("TABLE: app.free_video_overlays")
    print("=" * 70)
    result = run_sql("""
        SELECT column_name, data_type, is_nullable
        FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'free_video_overlays'
        ORDER BY ordinal_position
    """)
    if result:
        data = result if isinstance(result, list) else [result]
        for row in data:
            if isinstance(row, dict):
                print(f"  {row.get('column_name', '?'):40s} {row.get('data_type', '?'):20s} nullable={row.get('is_nullable', '?')}")
            else:
                print(f"  {row}")

    # 10) Lister TOUTES les tables du schema app
    print()
    print("=" * 70)
    print("TOUTES LES TABLES DU SCHEMA 'app'")
    print("=" * 70)
    result = run_sql("""
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = 'app'
        ORDER BY table_name
    """)
    if result:
        data = result if isinstance(result, list) else [result]
        for row in data:
            if isinstance(row, dict):
                print(f"  {row.get('table_name', '?')}")
            else:
                print(f"  {row}")


if __name__ == "__main__":
    main()

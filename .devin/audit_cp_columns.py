#!/usr/bin/env python3
"""Audit ciblé: colonnes de challenge_participations + free_videos + video_assets + video_sources."""

import requests
import json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
HEADERS = {
    "apikey": KEY,
    "Authorization": f"Bearer {KEY}",
    "Content-Type": "application/json",
}

def query(sql):
    r = requests.post(f"{URL}/rest/v1/rpc/execute_sql", headers=HEADERS, json={"sql_query": sql}, timeout=30)
    if r.status_code == 200:
        return r.json()
    return f"ERR {r.status_code}: {r.text[:300]}"

def show_cols(table):
    sql = f"SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='{table}' ORDER BY ordinal_position"
    rows = query(sql)
    print(f"\n=== app.{table} ===")
    if isinstance(rows, list):
        for r in rows:
            if isinstance(r, dict):
                print(f"  {r.get('column_name','?'):45s} {r.get('data_type','?')}")
    elif isinstance(rows, dict) and 'rows' in rows:
        for r in rows['rows']:
            print(f"  {r.get('column_name','?'):45s} {r.get('data_type','?')}")
    else:
        print(f"  {rows}")

if __name__ == "__main__":
    for t in [
        'challenge_participations',
        'free_videos',
        'video_assets',
        'video_sources',
        'video_renditions',
        'challenge_participation_videos',
    ]:
        show_cols(t)

    # Check: does challenge_participations have video_url or submission_url?
    print("\n\n=== RECHERCHE: colonnes contenant 'video' ou 'url' dans challenge_participations ===")
    rows = query("SELECT column_name FROM information_schema.columns WHERE table_schema='app' AND table_name='challenge_participations' AND (column_name LIKE '%video%' OR column_name LIKE '%url%' OR column_name LIKE '%submission%' OR column_name LIKE '%thumbnail%' OR column_name LIKE '%rendition%')")
    if isinstance(rows, list):
        for r in rows:
            print(f"  {r.get('column_name','?') if isinstance(r,dict) else r}")
    else:
        print(f"  {rows}")

    # Check: sample data from challenge_participations
    print("\n\n=== SAMPLE: 2 rows from challenge_participations ===")
    rows = query("SELECT id, user_id, challenge_id, video_asset_id, submission_text, started_at, submitted_at, moderation_status FROM app.challenge_participations LIMIT 2")
    if isinstance(rows, list):
        for r in rows:
            print(f"  {json.dumps(r, default=str)}")
    else:
        print(f"  {rows}")

    # Check: how video_assets links to URLs
    print("\n\n=== SAMPLE: 2 rows from video_assets ===")
    rows = query("SELECT * FROM app.video_assets LIMIT 2")
    if isinstance(rows, list):
        for r in rows:
            print(f"  {json.dumps(r, default=str)}")
    else:
        print(f"  {rows}")

    # Check: video_sources
    print("\n\n=== SAMPLE: 2 rows from video_sources ===")
    rows = query("SELECT * FROM app.video_sources LIMIT 2")
    if isinstance(rows, list):
        for r in rows:
            print(f"  {json.dumps(r, default=str)}")
    else:
        print(f"  {rows}")

    # Check: video_renditions
    print("\n\n=== SAMPLE: 2 rows from video_renditions ===")
    rows = query("SELECT * FROM app.video_renditions LIMIT 2")
    if isinstance(rows, list):
        for r in rows:
            print(f"  {json.dumps(r, default=str)}")
    else:
        print(f"  {rows}")

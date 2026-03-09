#!/usr/bin/env python3
"""Test direct du feed en exécutant la requête SQL interne (bypass auth check)."""

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
    return f"ERR {r.status_code}: {r.text[:500]}"

# Test 1: La sous-requête challenge_feed seule
print("=== TEST 1: Challenge feed (5 premiers) ===")
result = query("""
    SELECT
        cp.id AS video_id,
        cp.video_asset_id,
        (
            SELECT vr.public_url_hint
            FROM app.video_renditions vr
            WHERE vr.video_asset_id = cp.video_asset_id
              AND vr.status = 'ready'
            ORDER BY vr.created_at DESC
            LIMIT 1
        ) AS video_url,
        c.title AS challenge_title,
        cp.moderation_status
    FROM app.challenge_participations cp
    JOIN app.challenges c ON c.id = cp.challenge_id
    WHERE cp.is_active = TRUE
      AND cp.video_asset_id IS NOT NULL
    LIMIT 5
""")
if isinstance(result, list):
    for r in result:
        print(f"  {json.dumps(r, default=str)}")
else:
    print(f"  {result}")

# Test 2: La sous-requête free_feed seule
print("\n=== TEST 2: Free feed (5 premiers) ===")
result = query("""
    SELECT
        fv.id AS video_id,
        fv.video_asset_id,
        (
            SELECT vr.public_url_hint
            FROM app.video_renditions vr
            WHERE vr.video_asset_id = fv.video_asset_id
              AND vr.status = 'ready'
            ORDER BY vr.created_at DESC
            LIMIT 1
        ) AS video_url,
        fv.title,
        fv.moderation_status
    FROM app.free_videos fv
    WHERE fv.is_active = TRUE
      AND fv.video_asset_id IS NOT NULL
    LIMIT 5
""")
if isinstance(result, list):
    for r in result:
        print(f"  {json.dumps(r, default=str)}")
else:
    print(f"  {result}")

# Test 3: Compter les vidéos disponibles
print("\n=== TEST 3: Comptage ===")
result = query("""
    SELECT
        (SELECT COUNT(*) FROM app.challenge_participations WHERE is_active = TRUE AND video_asset_id IS NOT NULL) AS challenge_count,
        (SELECT COUNT(*) FROM app.free_videos WHERE is_active = TRUE AND video_asset_id IS NOT NULL) AS free_count,
        (SELECT COUNT(*) FROM app.video_renditions WHERE status = 'ready') AS renditions_count
""")
print(f"  {json.dumps(result, default=str)}")

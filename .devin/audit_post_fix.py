#!/usr/bin/env python3
"""Vérification post-fix: orphelines réparées + comptage feed."""

import requests, json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": KEY, "Authorization": f"Bearer {KEY}", "Content-Type": "application/json"}

def q(sql):
    r = requests.post(f"{URL}/rest/v1/rpc/execute_sql", headers=H, json={"sql_query": sql}, timeout=30)
    return r.json() if r.status_code == 200 else f"ERR {r.status_code}: {r.text[:300]}"

# 1) Orphelines restantes
print("=== FREE VIDEOS SANS video_asset_id (orphelines restantes) ===")
rows = q("SELECT COUNT(*) AS cnt FROM app.free_videos WHERE video_asset_id IS NULL AND is_active = TRUE")
print(f"  {json.dumps(rows, default=str)}")

# 2) Comptage feed
print("\n=== COMPTAGE FEED ===")
rows = q("""
    SELECT
        (SELECT COUNT(*) FROM app.free_videos WHERE is_active = TRUE) AS free_total,
        (SELECT COUNT(*) FROM app.free_videos WHERE is_active = TRUE AND video_asset_id IS NOT NULL) AS free_with_asset,
        (SELECT COUNT(*) FROM app.free_videos fv WHERE fv.is_active = TRUE AND fv.video_asset_id IS NOT NULL
           AND EXISTS (SELECT 1 FROM app.video_renditions vr WHERE vr.video_asset_id = fv.video_asset_id AND vr.status='ready')
        ) AS free_with_rendition,
        (SELECT COUNT(*) FROM app.challenge_participations WHERE is_active = TRUE AND video_asset_id IS NOT NULL) AS challenge_with_asset
""")
print(f"  {json.dumps(rows, default=str)}")

# 3) Les 5 dernières free_videos
print("\n=== 5 DERNIERES FREE VIDEOS ===")
rows = q("""
    SELECT fv.id, fv.video_asset_id, fv.is_active, fv.moderation_status, fv.created_at,
        (SELECT vr.public_url_hint FROM app.video_renditions vr WHERE vr.video_asset_id = fv.video_asset_id AND vr.status='ready' LIMIT 1) AS url
    FROM app.free_videos fv
    ORDER BY fv.created_at DESC LIMIT 5
""")
if isinstance(rows, list):
    for r in rows:
        print(f"  {json.dumps(r, default=str)}")

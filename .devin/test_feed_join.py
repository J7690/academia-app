#!/usr/bin/env python3
"""Vérifie la jointure free_videos → video_renditions."""
import requests, json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": KEY, "Authorization": f"Bearer {KEY}", "Content-Type": "application/json"}

def sql(q):
    r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": q.rstrip().rstrip(';')}, timeout=30)
    d = r.json()
    return d.get('rows', []) if isinstance(d, dict) and d.get('ok') else d

# Check renditions for each free_video asset
print("=== FREE VIDEOS → RENDITIONS JOIN ===")
rows = sql("""
    SELECT fv.id as fv_id, fv.video_asset_id,
           r.kind, r.status, r.width, LEFT(r.public_url_hint, 80) as url
    FROM app.free_videos fv
    LEFT JOIN app.video_renditions r ON r.video_asset_id = fv.video_asset_id AND r.status = 'ready'
    WHERE fv.is_active = TRUE AND fv.video_asset_id IS NOT NULL
    ORDER BY fv.created_at DESC, r.kind
    LIMIT 20
""")
if isinstance(rows, list):
    for r in rows:
        if isinstance(r, dict):
            print(f"  fv={str(r.get('fv_id',''))[:8]}.. asset={str(r.get('video_asset_id',''))[:8]}.. kind={str(r.get('kind','')):10s} w={r.get('width')} url={r.get('url','NULL')}")
        else:
            print(f"  {r}")
else:
    print(f"  RAW: {json.dumps(rows, default=str)[:1000]}")

# Check challenge_participations → renditions
print("\n=== CHALLENGE PARTICIPATIONS → RENDITIONS JOIN ===")
rows = sql("""
    SELECT cp.id as cp_id, cp.video_asset_id, c.is_active as ch_active,
           r.kind, r.status, r.width, LEFT(r.public_url_hint, 80) as url
    FROM app.challenge_participations cp
    JOIN app.challenges c ON c.id = cp.challenge_id
    LEFT JOIN app.video_renditions r ON r.video_asset_id = cp.video_asset_id AND r.status = 'ready'
    WHERE cp.is_active = TRUE AND cp.video_asset_id IS NOT NULL
    ORDER BY cp.started_at DESC, r.kind
    LIMIT 20
""")
if isinstance(rows, list):
    for r in rows:
        if isinstance(r, dict):
            print(f"  cp={str(r.get('cp_id',''))[:8]}.. asset={str(r.get('video_asset_id',''))[:8]}.. ch_active={r.get('ch_active')} kind={str(r.get('kind','')):10s} w={r.get('width')} url={r.get('url','NULL')}")
        else:
            print(f"  {r}")
else:
    print(f"  RAW: {json.dumps(rows, default=str)[:1000]}")

# Simulate the feed query (without auth check)
print("\n=== SIMULATED FEED (bypassing auth) ===")
rows = sql("""
    SELECT 'free' as vtype, fv.id, fv.video_asset_id,
        (SELECT r.public_url_hint FROM app.video_renditions r WHERE r.video_asset_id = fv.video_asset_id AND r.status = 'ready' AND r.kind IN ('hls','mp4') ORDER BY (r.kind='hls') DESC, COALESCE(r.width,0) DESC LIMIT 1) as best_url
    FROM app.free_videos fv
    WHERE fv.is_active = TRUE AND fv.video_asset_id IS NOT NULL
    AND COALESCE(fv.moderation_status, 'published') NOT IN ('blocked_ai', 'rejected')
    UNION ALL
    SELECT 'challenge' as vtype, cp.id, cp.video_asset_id,
        (SELECT r.public_url_hint FROM app.video_renditions r WHERE r.video_asset_id = cp.video_asset_id AND r.status = 'ready' AND r.kind IN ('hls','mp4') ORDER BY (r.kind='hls') DESC, COALESCE(r.width,0) DESC LIMIT 1) as best_url
    FROM app.challenge_participations cp
    JOIN app.challenges c ON c.id = cp.challenge_id
    WHERE cp.is_active = TRUE AND cp.video_asset_id IS NOT NULL
    AND COALESCE(cp.moderation_status, 'published') NOT IN ('blocked_ai', 'rejected')
    AND c.is_active = TRUE
    ORDER BY vtype
    LIMIT 20
""")
if isinstance(rows, list):
    count = 0
    for r in rows:
        if isinstance(r, dict):
            count += 1
            url = r.get('best_url', 'NULL')
            print(f"  {r.get('vtype','?'):10s} id={str(r.get('id',''))[:8]}.. best_url={str(url)[:80] if url else 'NULL'}")
    print(f"\n  TOTAL: {count} vidéos dans le feed simulé")
else:
    print(f"  RAW: {json.dumps(rows, default=str)[:1000]}")

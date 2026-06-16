#!/usr/bin/env python3
"""Vérifie les données disponibles pour le feed."""
import requests, json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": KEY, "Authorization": f"Bearer {KEY}", "Content-Type": "application/json"}

def sql(q):
    r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": q.rstrip().rstrip(';')}, timeout=30)
    d = r.json()
    if isinstance(d, dict) and d.get('ok') == False: return None, d.get('error')
    return d.get('rows', []) if isinstance(d, dict) else d, None

# 1. Free videos avec leurs renditions
print("=== FREE VIDEOS + RENDITIONS ===")
rows, err = sql("""
    SELECT fv.id, fv.video_asset_id, fv.is_active, fv.moderation_status,
           (SELECT COUNT(*) FROM app.video_renditions r WHERE r.video_asset_id = fv.video_asset_id AND r.status = 'ready') as ready_count,
           (SELECT r.public_url_hint FROM app.video_renditions r WHERE r.video_asset_id = fv.video_asset_id AND r.status = 'ready' AND r.kind IN ('hls','mp4') ORDER BY (r.kind='hls') DESC, COALESCE(r.width,0) DESC LIMIT 1) as best_url
    FROM app.free_videos fv
    WHERE fv.is_active = TRUE AND fv.video_asset_id IS NOT NULL
    ORDER BY fv.created_at DESC LIMIT 10
""")
if err: print(f"ERR: {err}")
elif rows:
    for r in rows:
        print(f"  id={str(r.get('id',''))[:8]}.. asset={str(r.get('video_asset_id',''))[:8]}.. active={r.get('is_active')} mod={r.get('moderation_status')} renditions={r.get('ready_count',0)} best_url={str(r.get('best_url',''))[:80]}")
else:
    print("  Aucune free video avec video_asset_id")

# 2. Challenge participations avec renditions
print("\n=== CHALLENGE PARTICIPATIONS + RENDITIONS ===")
rows, err = sql("""
    SELECT cp.id, cp.video_asset_id, cp.is_active, cp.moderation_status, c.is_active as challenge_active,
           (SELECT COUNT(*) FROM app.video_renditions r WHERE r.video_asset_id = cp.video_asset_id AND r.status = 'ready') as ready_count,
           (SELECT r.public_url_hint FROM app.video_renditions r WHERE r.video_asset_id = cp.video_asset_id AND r.status = 'ready' AND r.kind IN ('hls','mp4') ORDER BY (r.kind='hls') DESC, COALESCE(r.width,0) DESC LIMIT 1) as best_url
    FROM app.challenge_participations cp
    JOIN app.challenges c ON c.id = cp.challenge_id
    WHERE cp.is_active = TRUE AND cp.video_asset_id IS NOT NULL
    ORDER BY cp.started_at DESC LIMIT 10
""")
if err: print(f"ERR: {err}")
elif rows:
    for r in rows:
        print(f"  id={str(r.get('id',''))[:8]}.. asset={str(r.get('video_asset_id',''))[:8]}.. active={r.get('is_active')} ch_active={r.get('challenge_active')} mod={r.get('moderation_status')} renditions={r.get('ready_count',0)} best_url={str(r.get('best_url',''))[:80]}")
else:
    print("  Aucune participation avec video_asset_id")

# 3. Toutes les renditions
print("\n=== VIDEO RENDITIONS (échantillon) ===")
rows, err = sql("""
    SELECT r.video_asset_id, r.kind, r.status, r.width, r.public_url_hint
    FROM app.video_renditions r
    ORDER BY r.created_at DESC LIMIT 15
""")
if err: print(f"ERR: {err}")
elif rows:
    for r in rows:
        print(f"  asset={str(r.get('video_asset_id',''))[:8]}.. kind={r.get('kind'):10s} status={r.get('status'):8s} w={r.get('width')} url={str(r.get('public_url_hint',''))[:80]}")

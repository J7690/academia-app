#!/usr/bin/env python3
"""Trouver les free_videos sans rendition URL et chercher où leur URL est stockée."""

import requests
import json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
HEADERS = {"apikey": KEY, "Authorization": f"Bearer {KEY}", "Content-Type": "application/json"}

def q(sql):
    r = requests.post(f"{URL}/rest/v1/rpc/execute_sql", headers=HEADERS, json={"sql_query": sql}, timeout=30)
    return r.json() if r.status_code == 200 else f"ERR {r.status_code}: {r.text[:300]}"

# 1) Free videos sans rendition
print("=== FREE VIDEOS SANS RENDITION URL ===")
rows = q("""
    SELECT fv.id, fv.video_asset_id,
        (SELECT vr.public_url_hint FROM app.video_renditions vr WHERE vr.video_asset_id = fv.video_asset_id AND vr.status='ready' LIMIT 1) AS rendition_url,
        (SELECT vs.storage_path FROM app.video_sources vs WHERE vs.video_asset_id = fv.video_asset_id LIMIT 1) AS source_path,
        (SELECT vs.storage_bucket FROM app.video_sources vs WHERE vs.video_asset_id = fv.video_asset_id LIMIT 1) AS source_bucket
    FROM app.free_videos fv
    WHERE fv.is_active = TRUE AND fv.video_asset_id IS NOT NULL
    ORDER BY fv.created_at DESC
""")
if isinstance(rows, list):
    for r in rows:
        has_rendition = bool(r.get('rendition_url'))
        print(f"  id={r['id'][:12]}... asset={str(r.get('video_asset_id',''))[:12]}... rendition={'YES' if has_rendition else 'NO':3s} source_path={r.get('source_path','(none)')}")
else:
    print(f"  {rows}")

# 2) Chercher video_asset_contexts — peut contenir des URLs
print("\n=== TABLE: app.video_asset_contexts ===")
rows = q("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='video_asset_contexts' ORDER BY ordinal_position")
if isinstance(rows, list):
    for r in rows:
        print(f"  {r.get('column_name','?'):40s} {r.get('data_type','?')}")

# 3) Sample video_asset_contexts
print("\n=== SAMPLE: video_asset_contexts (5) ===")
rows = q("SELECT * FROM app.video_asset_contexts LIMIT 5")
if isinstance(rows, list):
    for r in rows:
        print(f"  {json.dumps(r, default=str)[:200]}")
else:
    print(f"  {rows}")

# 4) Chercher video_sources pour les free videos
print("\n=== VIDEO SOURCES pour free video assets ===")
rows = q("""
    SELECT vs.video_asset_id, vs.storage_bucket, vs.storage_path, vs.mime_type
    FROM app.video_sources vs
    WHERE vs.video_asset_id IN (
        SELECT fv.video_asset_id FROM app.free_videos fv WHERE fv.is_active = TRUE AND fv.video_asset_id IS NOT NULL
    )
""")
if isinstance(rows, list):
    for r in rows:
        print(f"  asset={str(r.get('video_asset_id',''))[:12]}... bucket={r.get('storage_bucket','')} path={r.get('storage_path','')}")
else:
    print(f"  {rows}")

# 5) Chercher video_renditions pour les free video assets
print("\n=== VIDEO RENDITIONS pour free video assets ===")
rows = q("""
    SELECT vr.video_asset_id, vr.rendition_key, vr.public_url_hint, vr.status, vr.storage_path
    FROM app.video_renditions vr
    WHERE vr.video_asset_id IN (
        SELECT fv.video_asset_id FROM app.free_videos fv WHERE fv.is_active = TRUE AND fv.video_asset_id IS NOT NULL
    )
""")
if isinstance(rows, list):
    for r in rows:
        print(f"  asset={str(r.get('video_asset_id',''))[:12]}... key={r.get('rendition_key','')} status={r.get('status','')} url={str(r.get('public_url_hint',''))[:80]}")
else:
    print(f"  {rows}")

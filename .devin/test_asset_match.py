#!/usr/bin/env python3
"""Vérifie si les video_asset_id des free_videos existent dans video_renditions."""
import requests, json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": KEY, "Authorization": f"Bearer {KEY}", "Content-Type": "application/json"}

def sql(q):
    r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": q.rstrip().rstrip(';')}, timeout=30)
    d = r.json()
    return d.get('rows', []) if isinstance(d, dict) and d.get('ok') else d

# 1. All video_asset_ids from free_videos
print("=== video_asset_id dans free_videos ===")
rows = sql("SELECT DISTINCT video_asset_id FROM app.free_videos WHERE video_asset_id IS NOT NULL")
fv_assets = set()
if isinstance(rows, list):
    for r in rows:
        aid = r.get('video_asset_id', '') if isinstance(r, dict) else str(r)
        fv_assets.add(aid)
        print(f"  {aid}")
print(f"  TOTAL: {len(fv_assets)} asset_ids distincts")

# 2. All video_asset_ids from video_renditions
print("\n=== video_asset_id dans video_renditions ===")
rows = sql("SELECT DISTINCT video_asset_id FROM app.video_renditions")
vr_assets = set()
if isinstance(rows, list):
    for r in rows:
        aid = r.get('video_asset_id', '') if isinstance(r, dict) else str(r)
        vr_assets.add(aid)
        print(f"  {aid}")
print(f"  TOTAL: {len(vr_assets)} asset_ids distincts")

# 3. Intersection
common = fv_assets & vr_assets
print(f"\n=== INTERSECTION ===")
print(f"  free_videos assets:     {len(fv_assets)}")
print(f"  video_renditions assets: {len(vr_assets)}")
print(f"  EN COMMUN:              {len(common)}")
if common:
    for c in common:
        print(f"    {c}")
else:
    print("  >>> AUCUN MATCH — les video_asset_id des free_videos ne sont PAS dans video_renditions <<<")

# 4. Check video_assets table
print("\n=== video_assets table ===")
rows = sql("SELECT id, source_url, status FROM app.video_assets LIMIT 10")
if isinstance(rows, list):
    for r in rows:
        if isinstance(r, dict):
            print(f"  id={r.get('id','')} status={r.get('status','')} src={str(r.get('source_url',''))[:80]}")
    print(f"  ({len(rows)} rows shown)")
else:
    print(f"  {rows}")

# 5. Check if free_video asset_ids exist in video_assets
print("\n=== free_video asset_ids dans video_assets? ===")
for aid in list(fv_assets)[:5]:
    rows = sql(f"SELECT id, status FROM app.video_assets WHERE id = '{aid}'")
    exists = len(rows) > 0 if isinstance(rows, list) else False
    print(f"  {aid} → {'EXISTE' if exists else 'INEXISTANT'}")

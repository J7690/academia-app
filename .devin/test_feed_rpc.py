#!/usr/bin/env python3
"""Test direct de la RPC feed après correction."""
import requests, json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": KEY, "Authorization": f"Bearer {KEY}", "Content-Type": "application/json"}

# Test via admin_execute_sql
r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H,
    json={"p_sql": "SELECT public.app_student_unified_video_feed(NULL, 5)"},
    timeout=30)
print("STATUS:", r.status_code)
d = r.json()
print("RAW:", json.dumps(d, indent=2, default=str)[:3000])

# Also check how many free_videos have video_asset_id with renditions
print("\n--- Free videos with renditions ---")
r2 = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H,
    json={"p_sql": """
        SELECT fv.id, fv.video_asset_id, fv.is_active, fv.moderation_status,
               (SELECT COUNT(*) FROM app.video_renditions r WHERE r.video_asset_id = fv.video_asset_id AND r.status = 'ready') as rendition_count,
               (SELECT r.public_url_hint FROM app.video_renditions r WHERE r.video_asset_id = fv.video_asset_id AND r.status = 'ready' LIMIT 1) as sample_url
        FROM app.free_videos fv
        WHERE fv.is_active = TRUE AND fv.video_asset_id IS NOT NULL
        ORDER BY fv.created_at DESC LIMIT 5
    """},
    timeout=30)
d2 = r2.json()
if isinstance(d2, dict) and 'rows' in d2:
    for row in d2['rows']:
        print(f"  id={row.get('id','?')[:8]}.. asset={row.get('video_asset_id','?')[:8]}.. renditions={row.get('rendition_count',0)} url={str(row.get('sample_url',''))[:80]}")
else:
    print("  RAW:", json.dumps(d2, indent=2, default=str)[:1000])

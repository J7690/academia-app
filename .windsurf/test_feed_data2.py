#!/usr/bin/env python3
"""Test données feed via requêtes simples."""
import requests, json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": KEY, "Authorization": f"Bearer {KEY}", "Content-Type": "application/json"}

def sql(q):
    r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": q.rstrip().rstrip(';')}, timeout=30)
    return r.json()

# Simple counts
print("1. COUNT free_videos:")
print(json.dumps(sql("SELECT COUNT(*) FROM app.free_videos"), default=str))

print("\n2. free_videos video_asset_id non null:")
print(json.dumps(sql("SELECT COUNT(*) FROM app.free_videos WHERE video_asset_id IS NOT NULL"), default=str))

print("\n3. free_videos is_active=true:")
print(json.dumps(sql("SELECT COUNT(*) FROM app.free_videos WHERE is_active = TRUE"), default=str))

print("\n4. video_renditions count:")
print(json.dumps(sql("SELECT COUNT(*) FROM app.video_renditions"), default=str))

print("\n5. video_renditions status=ready:")
print(json.dumps(sql("SELECT COUNT(*) FROM app.video_renditions WHERE status = 'ready'"), default=str))

print("\n6. free_videos ids + asset_ids:")
print(json.dumps(sql("SELECT id, video_asset_id, is_active, moderation_status FROM app.free_videos ORDER BY created_at DESC LIMIT 5"), default=str, indent=2))

print("\n7. renditions for first free_video asset:")
# Get first asset id
d = sql("SELECT video_asset_id FROM app.free_videos WHERE video_asset_id IS NOT NULL LIMIT 1")
print(f"  asset query result: {json.dumps(d, default=str)}")

#!/usr/bin/env python3
"""
Audit the actual RPC responses for the video upload pipeline.
Tests: app_videoasset_create_upload_intent, app_videoasset_get_playback_manifest,
       app_videoasset_get_playback_for_direct_url, app_student_create_free_video
"""
import sys
import json
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from supabase_auto_manager import SupabaseAutoManager
import requests

manager = SupabaseAutoManager()

def call_rpc(name, params):
    """Call an RPC as authenticated user (service_role)."""
    url = f"{manager.url}/rest/v1/rpc/{name}"
    r = requests.post(url, headers=manager.headers, json=params, timeout=20)
    return r.status_code, r.text[:1000]

def exec_sql(sql):
    url = f"{manager.url}/rest/v1/rpc/admin_execute_sql"
    r = requests.post(url, headers=manager.headers, json={"p_sql": sql}, timeout=20)
    if r.status_code == 200:
        data = r.json()
        if isinstance(data, dict) and "rows" in data:
            return data["rows"]
    return r.text[:500]

print("=" * 70)
print("AUDIT RPC RESPONSES — Video Upload Pipeline")
print("=" * 70)

# 1. Check function signatures
print("\n[1] Function signatures for video pipeline RPCs:")
funcs = [
    "app_videoasset_create_upload_intent",
    "app_videoasset_register_uploaded_source",
    "app_videoasset_get_playback_manifest",
    "app_videoasset_get_playback_for_direct_url",
    "app_student_create_free_video",
]
for f in funcs:
    rows = exec_sql(f"SELECT pg_get_function_arguments(p.oid) as args, pg_get_function_result(p.oid) as ret FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid WHERE n.nspname = 'public' AND p.proname = '{f}'")
    if isinstance(rows, list) and rows:
        for row in rows:
            print(f"  {f}({row.get('args','?')}) -> {row.get('ret','?')}")
    else:
        print(f"  {f}: NOT FOUND or error: {rows}")

# 2. Test app_videoasset_create_upload_intent with dummy data
print("\n[2] Testing app_videoasset_create_upload_intent:")
status, body = call_rpc("app_videoasset_create_upload_intent", {
    "p_origin": "student_free_video",
    "p_context_type": "free_video",
    "p_context_id": None,
    "p_role": "primary",
    "p_mime_type": "video/mp4",
    "p_expected_size": 1000000,
})
print(f"  Status: {status}")
print(f"  Response: {body}")

# 3. Test app_videoasset_get_playback_manifest with dummy UUID
print("\n[3] Testing app_videoasset_get_playback_manifest (dummy UUID):")
status, body = call_rpc("app_videoasset_get_playback_manifest", {
    "p_video_asset_id": "00000000-0000-0000-0000-000000000000",
})
print(f"  Status: {status}")
print(f"  Response: {body}")

# 4. Test app_videoasset_get_playback_for_direct_url with dummy URL
print("\n[4] Testing app_videoasset_get_playback_for_direct_url (dummy URL):")
status, body = call_rpc("app_videoasset_get_playback_for_direct_url", {
    "p_direct_url": "https://example.com/test.mp4",
})
print(f"  Status: {status}")
print(f"  Response: {body}")

# 5. Check recent video_assets to see if pipeline works
print("\n[5] Recent video_assets (last 5):")
rows = exec_sql("SELECT id, status, origin, created_at FROM app.video_assets ORDER BY created_at DESC LIMIT 5")
if isinstance(rows, list):
    for r in rows:
        print(f"  {r}")
else:
    print(f"  {rows}")

# 6. Check recent free_videos
print("\n[6] Recent free_videos (last 5):")
rows = exec_sql("SELECT id, student_id, title, playback, created_at FROM app.free_videos ORDER BY created_at DESC LIMIT 5")
if isinstance(rows, list):
    for r in rows:
        playback = r.get("playback", {})
        best_url = ""
        if isinstance(playback, dict):
            best_url = playback.get("best_url", "")
        elif isinstance(playback, str):
            try:
                p = json.loads(playback)
                best_url = p.get("best_url", "")
            except:
                best_url = playback[:100]
        print(f"  id={r.get('id','?')[:8]}... best_url={'[EMPTY]' if not best_url else best_url[:60]}... created={r.get('created_at','?')}")
else:
    print(f"  {rows}")

# 7. Check recent challenge_participations with video
print("\n[7] Recent challenge_participations with video (last 5):")
rows = exec_sql("SELECT id, student_id, challenge_id, video_url, created_at FROM app.challenge_participations WHERE video_url IS NOT NULL AND video_url != '' ORDER BY created_at DESC LIMIT 5")
if isinstance(rows, list):
    for r in rows:
        vid_url = r.get("video_url", "")
        print(f"  id={r.get('id','?')[:8]}... video_url={'[EMPTY]' if not vid_url else vid_url[:60]}... created={r.get('created_at','?')}")
else:
    print(f"  {rows}")

print("\n[DONE]")

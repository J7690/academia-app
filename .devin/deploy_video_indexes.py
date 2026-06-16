#!/usr/bin/env python3
"""Deploy missing indexes for video/studio tables via admin_execute_sql"""
import json, requests

CFG = json.load(open(r"c:\Users\fasop\AndroidStudioProjects\academia\.windsurf\supabase_permanent_config.json"))
H = {
    "apikey": CFG["service_role_key"],
    "Authorization": f"Bearer {CFG['service_role_key']}",
    "Content-Type": "application/json",
}

def sql(q):
    r = requests.post(f"{CFG['url']}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": q})
    d = r.json()
    if isinstance(d, str): d = json.loads(d)
    return d

indexes = [
    ("idx_video_assets_owner_user_id", "CREATE INDEX IF NOT EXISTS idx_video_assets_owner_user_id ON app.video_assets (owner_user_id)"),
    ("idx_video_assets_status", "CREATE INDEX IF NOT EXISTS idx_video_assets_status ON app.video_assets (status)"),
    ("idx_video_assets_created_at", "CREATE INDEX IF NOT EXISTS idx_video_assets_created_at ON app.video_assets (created_at DESC)"),
    ("idx_video_sources_video_asset_id", "CREATE INDEX IF NOT EXISTS idx_video_sources_video_asset_id ON app.video_sources (video_asset_id)"),
    ("idx_video_renditions_video_asset_id", "CREATE INDEX IF NOT EXISTS idx_video_renditions_video_asset_id ON app.video_renditions (video_asset_id)"),
    ("idx_video_renditions_key", "CREATE INDEX IF NOT EXISTS idx_video_renditions_key ON app.video_renditions (rendition_key)"),
    ("idx_free_videos_user_id", "CREATE INDEX IF NOT EXISTS idx_free_videos_user_id ON app.free_videos (user_id)"),
    ("idx_free_videos_video_asset_id", "CREATE INDEX IF NOT EXISTS idx_free_videos_video_asset_id ON app.free_videos (video_asset_id)"),
    ("idx_free_videos_active_moderation", "CREATE INDEX IF NOT EXISTS idx_free_videos_active_moderation ON app.free_videos (is_active, moderation_status)"),
    ("idx_free_video_overlays_fv_id", "CREATE INDEX IF NOT EXISTS idx_free_video_overlays_fv_id ON app.free_video_overlays (free_video_id)"),
    ("idx_challenge_participations_video_asset_id", "CREATE INDEX IF NOT EXISTS idx_challenge_participations_video_asset_id ON app.challenge_participations (video_asset_id)"),
    ("idx_challenge_participations_challenge_id", "CREATE INDEX IF NOT EXISTS idx_challenge_participations_challenge_id ON app.challenge_participations (challenge_id)"),
]

print(f"Deploying {len(indexes)} indexes...\n")
ok = 0
for name, ddl in indexes:
    r = sql(ddl)
    if r.get("ok"):
        print(f"  ✅ {name}")
        ok += 1
    else:
        print(f"  ❌ {name}: {r.get('error', '?')}")

print(f"\n{ok}/{len(indexes)} indexes créés avec succès.")

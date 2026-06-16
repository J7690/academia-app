"""Audit Part 3: Check exact RPCs called by Flutter for like/comment/createFreeVideo."""
import requests
SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": SERVICE_KEY, "Authorization": f"Bearer {SERVICE_KEY}", "Content-Type": "application/json"}

def sql(q, label=""):
    if label: print(f"\n  {label}")
    r = requests.post(f"{SUPABASE_URL}/rest/v1/rpc/execute_sql", headers=H, json={"sql_query": q})
    if r.status_code == 200:
        data = r.json()
        if isinstance(data, list):
            for row in data[:15]: print(f"    {row}")
            return data
        txt = str(data)
        for i in range(0, min(len(txt), 1500), 200):
            print(f"    {txt[i:i+200]}")
        return data
    print(f"    ❌ HTTP {r.status_code}: {r.text[:200]}")
    return None

# RPCs appelées par Flutter provider
rpcs = [
    'app_student_video_like',
    'app_student_video_unlike',
    'app_student_list_video_comments',
    'app_student_like_challenge_video',
    'app_student_unlike_challenge_video',
    'app_student_add_video_comment',
    'app_student_delete_video_comment',
    'app_student_create_free_video',
    'app_student_unified_video_feed',
    'challenge_game_start_live',
    'challenge_game_end_live',
    'challenge_game_list_live',
    'app_videoasset_create_upload_intent',
    'app_videoasset_register_uploaded_source',
]

print("=" * 70)
print("RPCs appelées par Flutter — Vérification existence")
print("=" * 70)

missing = []
for rpc in rpcs:
    result = sql(f"SELECT routine_name, routine_schema FROM information_schema.routines WHERE routine_name = '{rpc}'")
    if result:
        schema = result[0].get('routine_schema', '?')
        print(f"  ✅ {rpc} ({schema})")
    else:
        print(f"  ❌ {rpc} — MANQUANT!")
        missing.append(rpc)

# Check the GamePlayScreen _startGame flow - it does NOT use AutoRecordGameWrapper
print("\n" + "=" * 70)
print("Vérification: GamePlayScreen utilise-t-il AutoRecordGameWrapper ?")
print("=" * 70)
print("  → D'après le code Flutter, games_hub_screen._startGame() navigue vers")
print("    GamePlayScreen DIRECTEMENT, sans AutoRecordGameWrapper.")
print("  → GamePlayScreen._autoStartRecordingAndLive() gère le recording et live")
print("  → Le live est bien déclenché dans GamePlayScreen.initState")

# Check createFreeVideo params match
print("\n" + "=" * 70)
print("Vérification: provider.createFreeVideo params vs RPC params")
print("=" * 70)

sql("""
SELECT parameter_name, data_type, parameter_mode
FROM information_schema.parameters
WHERE specific_name IN (
    SELECT specific_name FROM information_schema.routines
    WHERE routine_name = 'app_student_create_free_video'
)
ORDER BY ordinal_position
""", "RPC app_student_create_free_video paramètres")

# check challenge_game_start_live returns
print("\n" + "=" * 70)
print("Test: challenge_game_start_live (sans auth)")
print("=" * 70)

r = requests.post(f"{SUPABASE_URL}/rest/v1/rpc/challenge_game_start_live", headers=H, json={
    'p_game_type': 'test', 'p_mode': 'solo'
})
print(f"  HTTP {r.status_code}: {r.text[:300]}")

# Check free_videos table content
sql("""
SELECT COUNT(*) as total,
       COUNT(video_asset_id) as with_asset,
       COUNT(*) FILTER (WHERE is_active) as active
FROM app.free_videos
""", "free_videos stats")

# Check if feed shows gameplay videos
sql("""
SELECT id, title, video_asset_id, moderation_status, created_at
FROM app.free_videos
WHERE is_active = TRUE AND video_asset_id IS NOT NULL
ORDER BY created_at DESC LIMIT 5
""", "Active free_videos avec video_asset")

print("\n" + "=" * 70)
print("BILAN")
print("=" * 70)
if missing:
    print(f"  {len(missing)} RPCs MANQUANTES:")
    for m in missing:
        print(f"    ❌ {m}")
else:
    print("  ✅ Toutes les RPCs existent")

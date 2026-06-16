"""
Audit Part 2: Détails sur les RPCs, la table free_videos réelle, et les tables social.
"""
import requests
import json

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
        # Print in chunks to avoid truncation
        for i in range(0, len(txt), 200):
            print(f"    {txt[i:i+200]}")
        return data
    print(f"    ❌ HTTP {r.status_code}: {r.text[:300]}")
    return None

# ── 1. Le VRAI nom de la table free_videos ──
print("=" * 70)
print("1. Trouver la vraie table free_videos")
print("=" * 70)

sql("""
SELECT table_schema, table_name FROM information_schema.tables
WHERE table_name LIKE '%free_video%'
ORDER BY table_schema, table_name
""", "Tables contenant 'free_video'")

sql("""
SELECT table_schema, table_name FROM information_schema.tables
WHERE table_name LIKE '%free%'
ORDER BY table_schema, table_name
""", "Tables contenant 'free'")

# La RPC app_student_create_free_video insère dans app.free_videos
sql("""
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema='app' AND table_name='free_videos'
ORDER BY ordinal_position
""", "Colonnes app.free_videos")

sql("""
SELECT id, user_id, title, video_asset_id, is_active, moderation_status, created_at
FROM app.free_videos
ORDER BY created_at DESC LIMIT 5
""", "5 dernières free_videos")

# ── 2. Source de challenge_game_start_live ──
print("\n" + "=" * 70)
print("2. Source challenge_game_start_live")
print("=" * 70)

sql("""
SELECT pg_get_functiondef(oid)
FROM pg_proc
WHERE proname = 'challenge_game_start_live'
""", "Source complète")

# ── 3. Source de challenge_game_end_live ──
print("\n" + "=" * 70)
print("3. Source challenge_game_end_live")
print("=" * 70)

sql("""
SELECT pg_get_functiondef(oid)
FROM pg_proc
WHERE proname = 'challenge_game_end_live'
""", "Source complète")

# ── 4. Source challenge_game_list_live ──
print("\n" + "=" * 70)
print("4. Source challenge_game_list_live")
print("=" * 70)

sql("""
SELECT pg_get_functiondef(oid)
FROM pg_proc
WHERE proname = 'challenge_game_list_live'
""", "Source complète")

# ── 5. Tables social: video_likes, video_comments ──
print("\n" + "=" * 70)
print("5. Tables social existantes")
print("=" * 70)

sql("""
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema='app' AND table_name='video_likes'
ORDER BY ordinal_position
""", "video_likes colonnes")

sql("""
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema='app' AND table_name='video_comments'
ORDER BY ordinal_position
""", "video_comments colonnes")

sql("""
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema='app' AND table_name='challenge_likes'
ORDER BY ordinal_position
""", "challenge_likes colonnes")

sql("""
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema='app' AND table_name='challenge_comments'
ORDER BY ordinal_position
""", "challenge_comments colonnes")

# ── 6. Feed RPC: app_student_unified_video_feed ──
print("\n" + "=" * 70)
print("6. Feed RPC: app_student_unified_video_feed")
print("=" * 70)

sql("""
SELECT pg_get_functiondef(oid)
FROM pg_proc
WHERE proname = 'app_student_unified_video_feed'
""", "Source complète")

# ── 7. Vérifier provider Flutter: createFreeVideo params ──
print("\n" + "=" * 70)
print("7. Vérifier si les RPCs de like/comment pour vidéos existent")
print("=" * 70)

for rpc in ['app_student_like_free_video', 'app_student_comment_free_video',
            'app_student_like_video', 'app_student_comment_video',
            'challenge_like_video', 'challenge_comment_video',
            'app_like_video', 'app_comment_video']:
    result = sql(f"""
    SELECT routine_name FROM information_schema.routines
    WHERE routine_name = '{rpc}'
    """)
    if result:
        print(f"    ✅ {rpc}")
    else:
        print(f"    ❌ {rpc}")

# ── 8. Colonnes challenge_game_live_sessions ──
print("\n" + "=" * 70)
print("8. challenge_game_live_sessions données")
print("=" * 70)

sql("""
SELECT status, COUNT(*) FROM app.challenge_game_live_sessions
GROUP BY status
""", "Sessions par statut")

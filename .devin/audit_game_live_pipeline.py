"""
AUDIT MINUTIEUX: Pipeline Jeu → Live → Feed
Interroge Supabase pour vérifier chaque composant.
"""
import requests
import json

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": SERVICE_KEY, "Authorization": f"Bearer {SERVICE_KEY}", "Content-Type": "application/json"}

issues = []

def sql(q, label=""):
    if label: print(f"\n  {label}")
    r = requests.post(f"{SUPABASE_URL}/rest/v1/rpc/execute_sql", headers=H, json={"sql_query": q})
    if r.status_code == 200:
        data = r.json()
        if isinstance(data, list):
            for row in data[:15]: print(f"    {row}")
            return data
        print(f"    {str(data)[:400]}")
        return data
    print(f"    ❌ HTTP {r.status_code}: {r.text[:300]}")
    return None

def rpc_test(name, params, label=""):
    if label: print(f"\n  {label}")
    r = requests.post(f"{SUPABASE_URL}/rest/v1/rpc/{name}", headers=H, json=params)
    print(f"    RPC {name}: HTTP {r.status_code}")
    if r.status_code == 200:
        data = r.json()
        print(f"    → {str(data)[:300]}")
        return data
    else:
        print(f"    → {r.text[:300]}")
        return None

# ================================================================
print("=" * 70)
print("AUDIT: Pipeline Jeu → Live → Feed (Supabase)")
print("=" * 70)

# ── 1. Table challenge_game_live_sessions ──
print("\n" + "─" * 70)
print("1. TABLE: challenge_game_live_sessions")
print("─" * 70)

cols = sql("""
SELECT column_name, data_type, column_default, is_nullable
FROM information_schema.columns
WHERE table_schema='app' AND table_name='challenge_game_live_sessions'
ORDER BY ordinal_position
""", "Colonnes")

if not cols:
    issues.append("❌ Table challenge_game_live_sessions INTROUVABLE")
else:
    col_names = [c['column_name'] for c in cols]
    print(f"\n    Colonnes: {col_names}")
    
    # Vérifier colonnes attendues
    expected = ['id', 'user_id', 'game_type', 'mode', 'status', 'livekit_room_name',
                'score_final', 'replay_video_asset_id', 'started_at', 'ended_at']
    for c in expected:
        if c not in col_names:
            issues.append(f"❌ Colonne manquante: challenge_game_live_sessions.{c}")
            print(f"    ⚠️ MANQUANT: {c}")

sql("""
SELECT status, COUNT(*) FROM app.challenge_game_live_sessions
GROUP BY status ORDER BY status
""", "Sessions par statut")

sql("""
SELECT id, user_id, game_type, mode, status, score_final, replay_video_asset_id,
       started_at, ended_at
FROM app.challenge_game_live_sessions
ORDER BY created_at DESC LIMIT 5
""", "5 dernières sessions")

# ── 2. RPC: challenge_game_start_live ──
print("\n" + "─" * 70)
print("2. RPC: challenge_game_start_live")
print("─" * 70)

sql("""
SELECT routine_name, routine_schema, data_type, specific_name
FROM information_schema.routines
WHERE routine_name = 'challenge_game_start_live'
""", "Existence RPC")

sql("""
SELECT parameter_name, data_type, parameter_mode
FROM information_schema.parameters
WHERE specific_name IN (
    SELECT specific_name FROM information_schema.routines
    WHERE routine_name = 'challenge_game_start_live'
)
ORDER BY ordinal_position
""", "Paramètres RPC")

# Lire la source de la function
sql("""
SELECT pg_get_functiondef(oid)
FROM pg_proc
WHERE proname = 'challenge_game_start_live'
LIMIT 1
""", "Source function")

# ── 3. RPC: challenge_game_end_live ──
print("\n" + "─" * 70)
print("3. RPC: challenge_game_end_live")
print("─" * 70)

sql("""
SELECT routine_name, routine_schema
FROM information_schema.routines
WHERE routine_name = 'challenge_game_end_live'
""", "Existence RPC")

sql("""
SELECT parameter_name, data_type, parameter_mode
FROM information_schema.parameters
WHERE specific_name IN (
    SELECT specific_name FROM information_schema.routines
    WHERE routine_name = 'challenge_game_end_live'
)
ORDER BY ordinal_position
""", "Paramètres RPC")

sql("""
SELECT pg_get_functiondef(oid)
FROM pg_proc
WHERE proname = 'challenge_game_end_live'
LIMIT 1
""", "Source function")

# ── 4. RPC: challenge_game_list_live ──
print("\n" + "─" * 70)
print("4. RPC: challenge_game_list_live")
print("─" * 70)

sql("""
SELECT routine_name, routine_schema
FROM information_schema.routines
WHERE routine_name = 'challenge_game_list_live'
""", "Existence RPC")

sql("""
SELECT pg_get_functiondef(oid)
FROM pg_proc
WHERE proname = 'challenge_game_list_live'
LIMIT 1
""", "Source function")

# Tester la RPC
rpc_test('challenge_game_list_live', {}, "Test appel RPC")

# ── 5. Feed: app_student_unified_video_feed ──
print("\n" + "─" * 70)
print("5. FEED: app_student_unified_video_feed / challenge_free_videos")
print("─" * 70)

sql("""
SELECT routine_name, routine_schema
FROM information_schema.routines
WHERE routine_name IN (
    'app_student_unified_video_feed',
    'app_student_create_free_video',
    'app_student_list_free_videos'
)
""", "RPCs Feed")

# Table challenge_free_videos
sql("""
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema='app' AND table_name='challenge_free_videos'
ORDER BY ordinal_position
""", "Table challenge_free_videos colonnes")

sql("""
SELECT id, user_id, title, video_asset_id, video_url, status, created_at
FROM app.challenge_free_videos
ORDER BY created_at DESC LIMIT 5
""", "5 dernières free_videos")

# ── 6. RPC: app_student_create_free_video ──
print("\n" + "─" * 70)
print("6. RPC: app_student_create_free_video (auto-publication)")
print("─" * 70)

sql("""
SELECT pg_get_functiondef(oid)
FROM pg_proc
WHERE proname = 'app_student_create_free_video'
LIMIT 1
""", "Source function")

sql("""
SELECT parameter_name, data_type, parameter_mode
FROM information_schema.parameters
WHERE specific_name IN (
    SELECT specific_name FROM information_schema.routines
    WHERE routine_name = 'app_student_create_free_video'
)
ORDER BY ordinal_position
""", "Paramètres")

# ── 7. Likes et commentaires sur vidéos ──
print("\n" + "─" * 70)
print("7. SOCIAL: Likes et commentaires sur vidéos")
print("─" * 70)

for t in ['challenge_likes', 'challenge_comments', 'challenge_video_likes', 'challenge_video_comments',
          'challenge_free_video_likes', 'challenge_free_video_comments']:
    result = sql(f"""
    SELECT table_schema, table_name FROM information_schema.tables
    WHERE table_name = '{t}'
    """)
    if result:
        print(f"    ✅ {t} existe")
    else:
        print(f"    ❌ {t} INTROUVABLE")
        issues.append(f"❌ Table {t} introuvable")

# Chercher toutes les tables de likes/comments
sql("""
SELECT table_schema, table_name FROM information_schema.tables
WHERE (table_name LIKE '%like%' OR table_name LIKE '%comment%')
AND table_schema IN ('app', 'public')
ORDER BY table_name
""", "Toutes les tables likes/comments")

# ── 8. Accès REST aux tables ──
print("\n" + "─" * 70)
print("8. Accès REST API aux tables critiques")
print("─" * 70)

for t in ['challenge_game_live_sessions', 'challenge_free_videos']:
    r1 = requests.get(f"{SUPABASE_URL}/rest/v1/{t}?select=id&limit=1", headers=H)
    r2 = requests.get(f"{SUPABASE_URL}/rest/v1/{t}?select=id&limit=1", headers={**H, "Accept-Profile": "app"})
    print(f"  {t}: public={r1.status_code}, app={r2.status_code}")

# ── 9. Vidéos gameplay dans le feed ──
print("\n" + "─" * 70)
print("9. Vidéos gameplay dans le feed existant")
print("─" * 70)

sql("""
SELECT id, user_id, title, video_asset_id, status, created_at
FROM app.challenge_free_videos
WHERE title LIKE '%ameplay%' OR title LIKE '%game%'
ORDER BY created_at DESC LIMIT 5
""", "Free videos avec 'gameplay/game' dans le titre")

# ── BILAN ──
print("\n" + "=" * 70)
print("BILAN DES INCOHÉRENCES")
print("=" * 70)
if issues:
    for issue in issues:
        print(f"  {issue}")
else:
    print("  Aucune incohérence détectée dans Supabase")

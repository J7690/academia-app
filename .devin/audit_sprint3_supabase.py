import json, requests
from supabase_auto_manager import SupabaseAutoManager

def q(m, label, sql):
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    r = requests.post(url, headers=m.headers, json={"p_sql": sql.strip()}, timeout=60)
    d = r.json() if r.text else {}
    print(f"\n=== {label} ===")
    if isinstance(d, list):
        for row in d:
            print(row)
    else:
        print(json.dumps(d, indent=2))

m = SupabaseAutoManager()

print("=== AUDIT SPRINT 3 — ANALYTICS / HEATMAPS / RETENTION ===\n")

# 1. Tables analytics existantes
q(m, "1. TABLES ANALYTICS/EVENTS/STATS", """
SELECT table_name
FROM information_schema.tables
WHERE table_schema IN ('public', 'app')
AND table_type = 'BASE TABLE'
AND (table_name LIKE '%analytic%' OR table_name LIKE '%event%' OR table_name LIKE '%stat%'
     OR table_name LIKE '%view%' OR table_name LIKE '%watch%' OR table_name LIKE '%heatmap%'
     OR table_name LIKE '%retention%' OR table_name LIKE '%engagement%')
ORDER BY table_name
""")

# 2. Tables liées aux likes, vues, favoris
q(m, "2. TABLES LIKES/VUES/FAVORIS", """
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'app'
AND (table_name LIKE '%like%' OR table_name LIKE '%view%' OR table_name LIKE '%favorite%'
     OR table_name LIKE '%comment%' OR table_name LIKE '%report%')
ORDER BY table_name
""")

# 3. Structure des tables d'engagement
q(m, "3. STRUCTURE CHALLENGE_LIKES", """
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'app' AND table_name = 'challenge_likes'
ORDER BY ordinal_position
""")

q(m, "4. STRUCTURE CHALLENGE_FAVORITES", """
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'app' AND table_name = 'challenge_favorites'
ORDER BY ordinal_position
""")

q(m, "5. STRUCTURE CHALLENGE_COMMENTS", """
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'app' AND table_name = 'challenge_comments'
ORDER BY ordinal_position
""")

# 6. RPCs analytics
q(m, "6. RPCs ANALYTICS/STATS", """
SELECT routine_name
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_type = 'FUNCTION'
AND (routine_name LIKE '%stat%' OR routine_name LIKE '%analytic%' OR routine_name LIKE '%count%'
     OR routine_name LIKE '%view%' OR routine_name LIKE '%watch%' OR routine_name LIKE '%engage%'
     OR routine_name LIKE '%leader%')
ORDER BY routine_name
""")

# 7. Source RPC leaderboard
q(m, "7. SOURCE RPC LEADERBOARD", """
SELECT LEFT(routine_definition, 600) as def_preview
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name = 'app_public_get_challenge_leaderboard'
""")

# 8. Source RPC my_challenge_stats
q(m, "8. SOURCE RPC MY_CHALLENGE_STATS", """
SELECT LEFT(routine_definition, 600) as def_preview
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name = 'app_student_get_my_challenge_stats'
""")

# 9. Tables video_upload_events ou similaire
q(m, "9. TABLES UPLOAD_EVENTS", """
SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'app'
AND table_name LIKE '%upload%'
ORDER BY table_name, ordinal_position
""")

# 10. Vérifier existence de video_views / watch_time
q(m, "10. TABLES VIDEO_VIEWS / WATCH", """
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'app'
AND (table_name LIKE '%video_view%' OR table_name LIKE '%watch%' OR table_name LIKE '%play%')
ORDER BY table_name
""")

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

print("=== AUDIT SPRINT 4 — SOCIAL FEATURES ===\n")

# 1. Tables réactions/likes/shares
q(m, "1. TABLES SOCIAL (likes, shares, reactions, duo)", """
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'app'
AND (table_name LIKE '%like%' OR table_name LIKE '%share%' OR table_name LIKE '%react%'
     OR table_name LIKE '%duo%' OR table_name LIKE '%follow%' OR table_name LIKE '%notif%')
ORDER BY table_name
""")

# 2. Structure challenge_likes
q(m, "2. STRUCTURE CHALLENGE_LIKES", """
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'app' AND table_name = 'challenge_likes'
ORDER BY ordinal_position
""")

# 3. RPCs social (like, unlike, share, follow, duo)
q(m, "3. RPCs SOCIAL", """
SELECT routine_name
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_type = 'FUNCTION'
AND (routine_name LIKE '%like%' OR routine_name LIKE '%share%' OR routine_name LIKE '%react%'
     OR routine_name LIKE '%duo%' OR routine_name LIKE '%follow%' OR routine_name LIKE '%favorite%')
ORDER BY routine_name
""")

# 4. Source RPC like
q(m, "4. SOURCE RPC LIKE_CHALLENGE_VIDEO", """
SELECT LEFT(routine_definition, 500) as def_preview
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name = 'app_student_like_challenge_video'
""")

# 5. Source RPC duo
q(m, "5. SOURCE RPC START_DUO_VIDEO", """
SELECT LEFT(routine_definition, 500) as def_preview
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name = 'app_student_start_duo_video'
""")

# 6. Tables notification
q(m, "6. TABLES NOTIFICATIONS", """
SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'app'
AND table_name LIKE '%notif%'
ORDER BY table_name, ordinal_position
LIMIT 30
""")

# 7. Tables follow/social
q(m, "7. TABLES FOLLOW/SOCIAL", """
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'app'
AND (table_name LIKE '%follow%' OR table_name LIKE '%social%' OR table_name LIKE '%friend%')
ORDER BY table_name
""")

# 8. Check if video_reactions exists
q(m, "8. TABLE VIDEO_REACTIONS", """
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'app'
AND table_name LIKE '%reaction%'
ORDER BY table_name
""")

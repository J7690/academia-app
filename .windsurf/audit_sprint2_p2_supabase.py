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

print("=== AUDIT SPRINT 2 PHASE P2 — PERFORMANCE CDN/CACHE/RENDITIONS ===\n")

# 1. Tables liées au stockage et renditions
q(m, "1. TABLES STORAGE & RENDITIONS", """
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
AND table_type = 'BASE TABLE'
AND (table_name LIKE '%video%' OR table_name LIKE '%rendition%' OR table_name LIKE '%cache%' OR table_name LIKE '%cdn%' OR table_name LIKE '%storage%')
ORDER BY table_name
""")

# 2. RPCs liées au playback et manifest
q(m, "2. RPCs PLAYBACK/MANIFEST", """
SELECT routine_name
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_type = 'FUNCTION'
AND (routine_name LIKE '%playback%' OR routine_name LIKE '%manifest%' OR routine_name LIKE '%rendition%' OR routine_name LIKE '%cache%')
ORDER BY routine_name
""")

# 3. Source de la RPC get_playback_manifest
q(m, "3. SOURCE RPC GET_PLAYBACK_MANIFEST", """
SELECT routine_definition
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name = 'app_videoasset_get_playback_manifest'
LIMIT 1
""")

# 4. Source de la RPC get_playback_for_direct_url
q(m, "4. SOURCE RPC GET_PLAYBACK_FOR_DIRECT_URL", """
SELECT routine_definition
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name = 'app_videoasset_get_playback_for_direct_url'
""")

# 5. RPCs liées au feed vidéo (pour lazy loading)
q(m, "5. RPCs FEED VIDEO", """
SELECT routine_name
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_type = 'FUNCTION'
AND (routine_name LIKE '%feed%' OR routine_name LIKE '%list%video%')
ORDER BY routine_name
""")

# 6. Source du feed unifié
q(m, "6. SOURCE RPC UNIFIED_VIDEO_FEED", """
SELECT LEFT(routine_definition, 800) as def_preview
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name = 'app_student_unified_video_feed'
""")

# 7. Source du challenge_video_feed
q(m, "7. SOURCE RPC CHALLENGE_VIDEO_FEED", """
SELECT LEFT(routine_definition, 800) as def_preview
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name = 'app_student_challenge_video_feed'
""")

# 8. Buckets storage existants
q(m, "8. STORAGE BUCKETS", """
SELECT id, name, public, file_size_limit, allowed_mime_types
FROM storage.buckets
ORDER BY name
""")

# 9. RPCs d'upload et video asset
q(m, "9. SOURCE RPC CREATE_UPLOAD_INTENT", """
SELECT LEFT(routine_definition, 600) as def_preview
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name = 'app_videoasset_create_upload_intent'
""")

# 10. Vérifier s'il existe des index pour performance
q(m, "10. INDEX SUR TABLES VIDEO", """
SELECT indexname, tablename, indexdef
FROM pg_indexes
WHERE schemaname = 'app'
AND (tablename LIKE '%video%' OR tablename LIKE '%challenge%')
ORDER BY tablename, indexname
LIMIT 20
""")

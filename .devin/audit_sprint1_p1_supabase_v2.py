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

print("=== AUDIT SPRINT 1 PHASE P1 - FUSION MULTI-SEGMENTS V2 ===\n")

# 1. Chercher toutes les tables liées aux vidéos
q(m, "1. TOUTES LES TABLES VIDEO", """
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND (table_name LIKE '%video%' OR table_name LIKE '%challenge%')
ORDER BY table_name
""")

# 2. Structure détaillée des tables challenges et challenge_participations
q(m, "2. STRUCTURE TABLE CHALLENGES", """
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'challenges'
ORDER BY ordinal_position
""")

q(m, "3. STRUCTURE TABLE CHALLENGE_PARTICIPATIONS", """
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'challenge_participations'
ORDER BY ordinal_position
""")

# 4. Rechercher les colonnes video_url et metadata
q(m, "4. COLONNES VIDEO_URL ET METADATA", """
SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public' 
AND (column_name LIKE '%video%' OR column_name = 'metadata')
ORDER BY table_name, column_name
""")

# 5. Lister toutes les RPCs liées aux vidéos/challenges
q(m, "5. RPCs VIDEO ET CHALLENGES", """
SELECT routine_name
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_type = 'FUNCTION'
AND (
    routine_name LIKE '%video%'
    OR routine_name LIKE '%challenge%'
    OR routine_name LIKE '%upload%'
)
ORDER BY routine_name
""")

# 6. Exemples de participations avec vidéos
q(m, "6. EXEMPLES PARTICIPATIONS AVEC VIDEOS", """
SELECT id, challenge_id, video_url, created_at
FROM challenge_participations
WHERE video_url IS NOT NULL
LIMIT 5
""")

# 7. Recherche spécifique Edge Functions
q(m, "7. EDGE FUNCTIONS CODE", """
SELECT id, name, source 
FROM edge_functions_code 
WHERE source LIKE '%segment%' 
   OR source LIKE '%merge%' 
   OR source LIKE '%concat%'
   OR source LIKE '%video%'
   OR name LIKE '%video%'
ORDER BY name
LIMIT 10
""")

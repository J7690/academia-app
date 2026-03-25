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

print("=== AUDIT SPRINT 1 PHASE P1 - ANALYSE DETAILLEE ===\n")

# 1. Lister toutes les tables du schéma public
q(m, "1. TOUTES LES TABLES PUBLIC", """
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_type = 'BASE TABLE'
ORDER BY table_name
LIMIT 50
""")

# 2. Chercher les RPCs spécifiques pour video asset et segments
q(m, "2. RPCs VIDEO ASSET DETAILS", """
SELECT routine_name
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_type = 'FUNCTION'
AND routine_name IN (
    'app_videoasset_create_upload_intent',
    'app_videoasset_register_uploaded_source',
    'app_student_add_challenge_video',
    'app_student_update_challenge_video_overlays'
)
ORDER BY routine_name
""")

# 3. Analyser la source d'une RPC vidéo
q(m, "3. SOURCE RPC ADD CHALLENGE VIDEO", """
SELECT routine_definition
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name = 'app_student_add_challenge_video'
""")

# 4. Chercher dans edge_functions_code
q(m, "4. EDGE FUNCTIONS NAMES", """
SELECT name 
FROM edge_functions_code 
ORDER BY name
LIMIT 20
""")

# 5. Tables avec colonnes video ou url
q(m, "5. TABLES AVEC COLONNES VIDEO", """
SELECT DISTINCT table_name
FROM information_schema.columns
WHERE table_schema = 'public'
AND (column_name LIKE '%video%' OR column_name LIKE '%url%')
ORDER BY table_name
LIMIT 20
""")

# 6. Structure de la table edge_functions_code
q(m, "6. STRUCTURE EDGE_FUNCTIONS_CODE", """
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'edge_functions_code'
ORDER BY ordinal_position
""")

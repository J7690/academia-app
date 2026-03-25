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

print("=== AUDIT EDGE FUNCTIONS POUR MULTI-SEGMENTS ===\n")

# 1. Lister toutes les Edge Functions
q(m, "1. LISTE EDGE FUNCTIONS", """
SELECT function_name, status, created_at
FROM edge_functions_code
ORDER BY function_name
""")

# 2. Chercher Edge Functions liées aux vidéos
q(m, "2. EDGE FUNCTIONS VIDEO", """
SELECT function_name, LEFT(function_code, 200) as code_preview
FROM edge_functions_code
WHERE function_name LIKE '%video%' 
   OR function_name LIKE '%transcode%'
   OR function_name LIKE '%merge%'
   OR function_name LIKE '%concat%'
   OR function_name LIKE '%segment%'
   OR function_name LIKE '%assemble%'
ORDER BY function_name
""")

# 3. Voir le code de assemble-video-chunks si existe
q(m, "3. CODE ASSEMBLE-VIDEO-CHUNKS", """
SELECT function_name, function_code
FROM edge_functions_code
WHERE function_name = 'assemble-video-chunks'
""")

# 4. Chercher toute fonction avec 'chunk' dans le nom ou code
q(m, "4. FONCTIONS AVEC CHUNK", """
SELECT function_name
FROM edge_functions_code
WHERE function_name LIKE '%chunk%'
   OR function_code LIKE '%chunk%'
ORDER BY function_name
""")

# 5. Vérifier si transcode-multi-resolution existe
q(m, "5. TRANSCODE MULTI-RESOLUTION", """
SELECT function_name, status, updated_at
FROM edge_functions_code
WHERE function_name = 'transcode-multi-resolution'
""")

# 6. Rechercher des fonctions de fusion/merge dans le code
q(m, "6. FONCTIONS FUSION/MERGE", """
SELECT function_name
FROM edge_functions_code
WHERE function_code LIKE '%ffmpeg%'
   AND (function_code LIKE '%concat%' OR function_code LIKE '%merge%')
ORDER BY function_name
""")

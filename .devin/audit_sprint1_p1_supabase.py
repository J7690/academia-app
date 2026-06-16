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

# Sprint 1 Phase P1 - Audit Supabase pour fusion multi-segments
# Objectif: Identifier les structures et fonctions liées aux segments vidéo et leur fusion

print("=== AUDIT SPRINT 1 PHASE P1 - FUSION MULTI-SEGMENTS ===\n")

# 1. Recherche des tables liées aux segments vidéo
tables_query = """
SELECT table_name, column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
AND (
    table_name LIKE '%segment%'
    OR table_name LIKE '%clip%'
    OR table_name LIKE '%part%'
    OR table_name LIKE '%merge%'
    OR table_name IN ('video_assets', 'video_sources', 'video_processing_jobs')
)
ORDER BY table_name, ordinal_position
"""
q(m, "1. TABLES POUR SEGMENTS VIDEO", tables_query)

# 2. Vérifier les colonnes de video_sources pour support multi-segments
video_sources_query = """
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'video_sources'
ORDER BY ordinal_position
"""
q(m, "2. STRUCTURE DE VIDEO_SOURCES", video_sources_query)

# 3. Recherche des RPCs pour fusion/merge
merge_rpcs = """
SELECT routine_name
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_type = 'FUNCTION'
AND (
    routine_name LIKE '%merge%'
    OR routine_name LIKE '%concat%'
    OR routine_name LIKE '%combine%'
    OR routine_name LIKE '%segment%'
    OR routine_name LIKE '%clip%'
)
ORDER BY routine_name
"""
q(m, "3. RPCs POUR FUSION/MERGE", merge_rpcs)

# 4. Vérifier video_processing_jobs pour types de jobs de fusion
job_types = """
SELECT DISTINCT job_type, status, COUNT(*) as count
FROM video_processing_jobs
GROUP BY job_type, status
ORDER BY job_type, status
"""
q(m, "4. TYPES DE JOBS DE TRAITEMENT", job_types)

# 5. Exemples de video_sources avec metadata
sources_metadata = """
SELECT id, video_asset_id, file_path, 
       metadata->>'segments' as segments,
       metadata->>'duration_ms' as duration_ms,
       metadata->>'source_type' as source_type
FROM video_sources
WHERE metadata IS NOT NULL
LIMIT 5
"""
q(m, "5. EXEMPLES VIDEO_SOURCES AVEC METADATA", sources_metadata)

# 6. Recherche dans les Edge Functions
edge_functions = """
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
AND table_name LIKE '%edge%function%'
"""
q(m, "6. EDGE FUNCTIONS POTENTIELLES", edge_functions)

# 7. Vérifier les politiques RLS sur video_sources
policies = """
SELECT policyname, permissive, cmd, qual, with_check
FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'video_sources'
"""
q(m, "7. POLITIQUES RLS VIDEO_SOURCES", policies)

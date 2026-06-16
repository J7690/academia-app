#!/usr/bin/env python3
"""
Audit Supabase — Système vidéo + Studio Academia
Exécute des requêtes SQL via la RPC admin_execute_sql pour inventorier
toutes les tables, RPCs, données et détecter les résidus/doublons.
"""
import json
import requests
import sys
from datetime import datetime

CONFIG = {
    "url": "https://thevdfcwlcqzdoybfvgs.supabase.co",
    "service_role_key": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
}

HEADERS = {
    "apikey": CONFIG["service_role_key"],
    "Authorization": f"Bearer {CONFIG['service_role_key']}",
    "Content-Type": "application/json",
    "Prefer": "return=representation"
}

def exec_sql(sql):
    """Execute SQL via admin_execute_sql RPC."""
    url = f"{CONFIG['url']}/rest/v1/rpc/admin_execute_sql"
    resp = requests.post(url, headers=HEADERS, json={"p_sql": sql})
    if resp.status_code != 200:
        return {"ok": False, "error": f"HTTP {resp.status_code}: {resp.text[:500]}"}
    data = resp.json()
    if isinstance(data, str):
        data = json.loads(data)
    return data

def section(title):
    print(f"\n{'='*70}")
    print(f"  {title}")
    print(f"{'='*70}")

results = {}

# =========================================================================
# 1. Tables liées au système vidéo
# =========================================================================
section("1. TABLES DU SYSTÈME VIDÉO (schema app)")

tables_sql = """
SELECT table_name, 
       (SELECT count(*) FROM information_schema.columns c 
        WHERE c.table_schema = t.table_schema AND c.table_name = t.table_name) as col_count
FROM information_schema.tables t
WHERE t.table_schema = 'app'
AND (
    t.table_name LIKE '%video%'
    OR t.table_name LIKE '%challenge%'
    OR t.table_name LIKE '%free_video%'
    OR t.table_name LIKE '%overlay%'
    OR t.table_name LIKE '%rendition%'
    OR t.table_name LIKE '%audio%'
    OR t.table_name LIKE '%sticker%'
    OR t.table_name LIKE '%studio%'
    OR t.table_name LIKE '%draft%'
    OR t.table_name LIKE '%render%'
    OR t.table_name LIKE '%segment%'
    OR t.table_name LIKE '%transcode%'
)
ORDER BY t.table_name
"""
r = exec_sql(tables_sql)
results["video_tables"] = r
if r.get("ok"):
    rows = r.get("rows", [])
    print(f"  Trouvé {len(rows)} tables :")
    for row in rows:
        print(f"    - {row['table_name']} ({row['col_count']} colonnes)")
else:
    print(f"  ERREUR: {r.get('error')}")

# =========================================================================
# 2. Colonnes détaillées des tables clés
# =========================================================================
section("2. COLONNES DES TABLES CLÉS")

key_tables = [
    'video_assets', 'video_sources', 'video_renditions',
    'challenge_participations', 'free_videos',
    'free_video_overlays', 'challenge_video_overlays',
]

for table in key_tables:
    cols_sql = f"""
    SELECT column_name, data_type, is_nullable, column_default
    FROM information_schema.columns
    WHERE table_schema = 'app' AND table_name = '{table}'
    ORDER BY ordinal_position
    """
    r = exec_sql(cols_sql)
    results[f"cols_{table}"] = r
    if r.get("ok"):
        rows = r.get("rows", [])
        if rows:
            print(f"\n  {table} ({len(rows)} colonnes):")
            for col in rows:
                nullable = "NULL" if col['is_nullable'] == 'YES' else "NOT NULL"
                default = f" DEFAULT {col['column_default']}" if col.get('column_default') else ""
                print(f"    {col['column_name']:30s} {col['data_type']:20s} {nullable}{default}")
        else:
            print(f"\n  {table} — TABLE NON TROUVÉE")
    else:
        print(f"\n  {table} — ERREUR: {r.get('error')}")

# =========================================================================
# 3. RPCs liées au système vidéo
# =========================================================================
section("3. RPCs LIÉES AU SYSTÈME VIDÉO")

rpcs_sql = """
SELECT routine_name, routine_schema
FROM information_schema.routines
WHERE routine_type = 'FUNCTION'
AND (routine_schema = 'public' OR routine_schema = 'app')
AND (
    routine_name LIKE '%video%'
    OR routine_name LIKE '%challenge%'
    OR routine_name LIKE '%overlay%'
    OR routine_name LIKE '%rendition%'
    OR routine_name LIKE '%transcode%'
    OR routine_name LIKE '%upload%'
    OR routine_name LIKE '%playback%'
    OR routine_name LIKE '%segment%'
    OR routine_name LIKE '%audio%'
    OR routine_name LIKE '%studio%'
    OR routine_name LIKE '%render%'
    OR routine_name LIKE '%draft%'
    OR routine_name LIKE '%sticker%'
    OR routine_name LIKE '%free_video%'
)
ORDER BY routine_schema, routine_name
"""
r = exec_sql(rpcs_sql)
results["video_rpcs"] = r
if r.get("ok"):
    rows = r.get("rows", [])
    print(f"  Trouvé {len(rows)} RPCs :")
    for row in rows:
        print(f"    [{row['routine_schema']}] {row['routine_name']}")
else:
    print(f"  ERREUR: {r.get('error')}")

# =========================================================================
# 4. Comptage des données dans les tables vidéo
# =========================================================================
section("4. COMPTAGE DES DONNÉES")

count_tables = [
    'video_assets', 'video_sources', 'video_renditions',
    'challenge_participations', 'free_videos',
    'free_video_overlays', 'challenge_video_overlays',
]
for table in count_tables:
    r = exec_sql(f"SELECT count(*) as cnt FROM app.{table}")
    if r.get("ok") and r.get("rows"):
        cnt = r["rows"][0]["cnt"]
        print(f"  {table:40s} → {cnt} lignes")
        results[f"count_{table}"] = cnt
    else:
        print(f"  {table:40s} → ERREUR ou table inexistante")
        results[f"count_{table}"] = "ERROR"

# =========================================================================
# 5. Détection d'orphelins et doublons
# =========================================================================
section("5. DÉTECTION ORPHELINS ET DOUBLONS")

# 5a. video_assets sans renditions
orphan_assets_sql = """
SELECT va.id, va.origin, va.status, va.created_at
FROM app.video_assets va
LEFT JOIN app.video_renditions vr ON vr.video_asset_id = va.id
WHERE vr.id IS NULL
ORDER BY va.created_at DESC
LIMIT 50
"""
r = exec_sql(orphan_assets_sql)
results["orphan_assets_no_renditions"] = r
if r.get("ok"):
    rows = r.get("rows", [])
    print(f"\n  5a. video_assets SANS renditions: {len(rows)}")
    for row in rows[:5]:
        print(f"      id={row['id']}, origin={row.get('origin')}, status={row.get('status')}")
    if len(rows) > 5:
        print(f"      ... et {len(rows)-5} de plus")

# 5b. video_assets sans sources
orphan_assets_src_sql = """
SELECT va.id, va.origin, va.status
FROM app.video_assets va
LEFT JOIN app.video_sources vs ON vs.video_asset_id = va.id
WHERE vs.id IS NULL
ORDER BY va.created_at DESC
LIMIT 50
"""
r = exec_sql(orphan_assets_src_sql)
results["orphan_assets_no_sources"] = r
if r.get("ok"):
    rows = r.get("rows", [])
    print(f"\n  5b. video_assets SANS sources: {len(rows)}")

# 5c. free_videos sans video_asset_id
orphan_fv_sql = """
SELECT fv.id, fv.user_id, fv.created_at
FROM app.free_videos fv
WHERE fv.video_asset_id IS NULL
"""
r = exec_sql(orphan_fv_sql)
results["orphan_free_videos_no_asset"] = r
if r.get("ok"):
    rows = r.get("rows", [])
    print(f"\n  5c. free_videos SANS video_asset_id: {len(rows)}")

# 5d. challenge_participations sans video_asset_id
orphan_cp_sql = """
SELECT cp.id, cp.user_id, cp.challenge_id, cp.created_at
FROM app.challenge_participations cp
WHERE cp.video_asset_id IS NULL AND cp.submitted_at IS NOT NULL
"""
r = exec_sql(orphan_cp_sql)
results["orphan_cp_no_asset"] = r
if r.get("ok"):
    rows = r.get("rows", [])
    print(f"\n  5d. challenge_participations soumises SANS video_asset_id: {len(rows)}")

# 5e. Doublons renditions (même video_asset_id + même rendition_key)
dup_renditions_sql = """
SELECT video_asset_id, rendition_key, count(*) as cnt
FROM app.video_renditions
GROUP BY video_asset_id, rendition_key
HAVING count(*) > 1
"""
r = exec_sql(dup_renditions_sql)
results["duplicate_renditions"] = r
if r.get("ok"):
    rows = r.get("rows", [])
    print(f"\n  5e. Doublons renditions (même asset+key): {len(rows)}")
    for row in rows[:5]:
        print(f"      asset={row['video_asset_id']}, key={row['rendition_key']}, count={row['cnt']}")

# 5f. Doublons sources
dup_sources_sql = """
SELECT video_asset_id, count(*) as cnt
FROM app.video_sources
GROUP BY video_asset_id
HAVING count(*) > 1
"""
r = exec_sql(dup_sources_sql)
results["duplicate_sources"] = r
if r.get("ok"):
    rows = r.get("rows", [])
    print(f"\n  5f. Doublons sources (même asset, multiple sources): {len(rows)}")

# =========================================================================
# 6. Edge Functions liées au vidéo
# =========================================================================
section("6. SUPABASE STORAGE BUCKETS")

buckets_sql = """
SELECT id, name, public, created_at
FROM storage.buckets
WHERE name LIKE '%video%' OR name LIKE '%segment%' OR name LIKE '%render%' 
   OR name LIKE '%challenge%' OR name LIKE '%studio%' OR name LIKE '%audio%'
   OR name LIKE '%upload%' OR name LIKE '%temp%' OR name LIKE '%media%'
ORDER BY name
"""
r = exec_sql(buckets_sql)
results["storage_buckets"] = r
if r.get("ok"):
    rows = r.get("rows", [])
    print(f"  Buckets vidéo: {len(rows)}")
    for row in rows:
        public = "PUBLIC" if row.get('public') else "PRIVATE"
        print(f"    {row['name']:30s} {public}")

# =========================================================================
# 7. Indexes et contraintes sur les tables vidéo
# =========================================================================
section("7. INDEXES SUR TABLES VIDÉO")

indexes_sql = """
SELECT indexname, tablename, indexdef
FROM pg_indexes
WHERE schemaname = 'app'
AND (tablename LIKE '%video%' OR tablename LIKE '%rendition%' 
     OR tablename LIKE '%overlay%' OR tablename LIKE '%challenge_participation%')
ORDER BY tablename, indexname
"""
r = exec_sql(indexes_sql)
results["video_indexes"] = r
if r.get("ok"):
    rows = r.get("rows", [])
    print(f"  {len(rows)} indexes trouvés:")
    for row in rows:
        print(f"    [{row['tablename']}] {row['indexname']}")

# =========================================================================
# 8. RLS policies sur les tables vidéo
# =========================================================================
section("8. RLS POLICIES")

rls_sql = """
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies
WHERE schemaname = 'app'
AND (tablename LIKE '%video%' OR tablename LIKE '%rendition%' 
     OR tablename LIKE '%overlay%' OR tablename LIKE '%free_video%')
ORDER BY tablename, policyname
"""
r = exec_sql(rls_sql)
results["video_rls"] = r
if r.get("ok"):
    rows = r.get("rows", [])
    print(f"  {len(rows)} policies trouvées:")
    for row in rows:
        print(f"    [{row['tablename']}] {row['policyname']} ({row['cmd']}) → {row['roles']}")

# =========================================================================
# 9. Triggers sur les tables vidéo
# =========================================================================
section("9. TRIGGERS")

triggers_sql = """
SELECT trigger_name, event_object_table, event_manipulation, action_timing
FROM information_schema.triggers
WHERE trigger_schema = 'app'
AND (event_object_table LIKE '%video%' OR event_object_table LIKE '%rendition%'
     OR event_object_table LIKE '%overlay%' OR event_object_table LIKE '%challenge%')
ORDER BY event_object_table, trigger_name
"""
r = exec_sql(triggers_sql)
results["video_triggers"] = r
if r.get("ok"):
    rows = r.get("rows", [])
    print(f"  {len(rows)} triggers trouvés:")
    for row in rows:
        print(f"    [{row['event_object_table']}] {row['trigger_name']} ({row['action_timing']} {row['event_manipulation']})")

# =========================================================================
# 10. Vérifier les statuts video_assets
# =========================================================================
section("10. DISTRIBUTION DES STATUTS VIDEO_ASSETS")

status_sql = """
SELECT status, count(*) as cnt
FROM app.video_assets
GROUP BY status
ORDER BY cnt DESC
"""
r = exec_sql(status_sql)
results["video_asset_statuses"] = r
if r.get("ok"):
    rows = r.get("rows", [])
    for row in rows:
        print(f"  {row['status']:25s} → {row['cnt']}")

# =========================================================================
# SAVE TO FILE
# =========================================================================
section("SAUVEGARDE DU RAPPORT")

output_path = r"c:\Users\fasop\AndroidStudioProjects\academia\.windsurf\logs\audit_video_studio_supabase.json"
import os
os.makedirs(os.path.dirname(output_path), exist_ok=True)

with open(output_path, "w", encoding="utf-8") as f:
    json.dump({
        "audit_date": datetime.now().isoformat(),
        "audit_type": "video_studio_supabase",
        "results": results
    }, f, indent=2, ensure_ascii=False, default=str)

print(f"  Rapport sauvegardé: {output_path}")
print(f"\n{'='*70}")
print("  AUDIT TERMINÉ")
print(f"{'='*70}")

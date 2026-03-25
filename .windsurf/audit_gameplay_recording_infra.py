#!/usr/bin/env python3
"""Audit Supabase pour la feature capture gameplay -> feed challenge.
Verifie: buckets storage, tables video_assets/free_videos/challenge_participations,
RPCs video upload/publish, et l'etat des donnees.
"""
import requests
import json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

HEADERS = {
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Content-Type": "application/json",
    "Accept": "application/json"
}

def exec_sql(sql):
    sql = sql.strip().rstrip(";")
    for rpc_name in ["admin_execute_sql", "execute_sql"]:
        try:
            r = requests.post(f"{URL}/rest/v1/rpc/{rpc_name}",
                              headers=HEADERS, json={"sql_query": sql}, timeout=30)
            if r.status_code == 200:
                return r.json()
            if "PGRST202" not in r.text:
                return {"rpc": rpc_name, "status": r.status_code, "body": r.text[:500]}
        except Exception as e:
            pass
    return {"error": "both RPCs failed"}

print("=" * 60)
print("1. BUCKETS Storage existants")
print("=" * 60)
result = exec_sql("""
SELECT id, name, public, file_size_limit, allowed_mime_types
FROM storage.buckets
ORDER BY name
""")
print(json.dumps(result, indent=2, default=str))

print("\n" + "=" * 60)
print("2. Tables video (video_assets, video_sources, video_renditions, free_videos)")
print("=" * 60)
for tbl in ['video_assets', 'video_sources', 'video_renditions', 'free_videos', 'challenge_participations']:
    result = exec_sql(f"SELECT count(*) as cnt FROM app.{tbl}")
    print(f"  app.{tbl}: {json.dumps(result, default=str)}")

print("\n" + "=" * 60)
print("3. Colonnes video_assets")
print("=" * 60)
result = exec_sql("""
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'app' AND table_name = 'video_assets'
ORDER BY ordinal_position
""")
print(json.dumps(result, indent=2, default=str))

print("\n" + "=" * 60)
print("4. Colonnes free_videos")
print("=" * 60)
result = exec_sql("""
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'app' AND table_name = 'free_videos'
ORDER BY ordinal_position
""")
print(json.dumps(result, indent=2, default=str))

print("\n" + "=" * 60)
print("5. RPCs video (videoasset, free_video, challenge_video)")
print("=" * 60)
result = exec_sql("""
SELECT routine_name
FROM information_schema.routines
WHERE routine_schema IN ('app', 'public')
  AND (routine_name ILIKE '%videoasset%'
    OR routine_name ILIKE '%free_video%'
    OR routine_name ILIKE '%challenge_video%')
ORDER BY routine_name
""")
print(json.dumps(result, indent=2, default=str))

print("\n" + "=" * 60)
print("6. RPCs unified feed")
print("=" * 60)
result = exec_sql("""
SELECT routine_name
FROM information_schema.routines
WHERE routine_schema IN ('app', 'public')
  AND routine_name ILIKE '%unified%feed%'
ORDER BY routine_name
""")
print(json.dumps(result, indent=2, default=str))

print("\n" + "=" * 60)
print("7. Edge Functions deployees")
print("=" * 60)
result = exec_sql("""
SELECT schema_name
FROM information_schema.schemata
WHERE schema_name ILIKE '%edge%' OR schema_name ILIKE '%function%'
""")
print(json.dumps(result, indent=2, default=str))

print("\n" + "=" * 60)
print("8. Colonnes challenge_participations (video_asset_id)")
print("=" * 60)
result = exec_sql("""
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'app' AND table_name = 'challenge_participations'
  AND column_name IN ('video_asset_id', 'submission_url', 'submission_text', 'moderation_status')
ORDER BY ordinal_position
""")
print(json.dumps(result, indent=2, default=str))

print("\nAudit termine.")

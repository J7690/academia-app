#!/usr/bin/env python3
"""Check which schema the critical tables live in, and list all app_* RPCs."""
import sys
import json
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from supabase_auto_manager import SupabaseAutoManager
import requests

manager = SupabaseAutoManager()
url = f"{manager.url}/rest/v1/rpc/admin_execute_sql"

def query(sql):
    r = requests.post(url, headers=manager.headers, json={"p_sql": sql}, timeout=20)
    if r.status_code != 200:
        print(f"HTTP {r.status_code}: {r.text[:300]}")
        return None
    data = r.json()
    if isinstance(data, dict) and "rows" in data:
        return data["rows"]
    return data

# 1. Find tables across ALL schemas
print("=" * 70)
print("1. SEARCHING CRITICAL TABLES ACROSS ALL SCHEMAS")
print("=" * 70)
tables = [
    "challenges", "challenge_participations", "student_free_videos",
    "video_comments", "video_likes", "video_favorites", "video_reports",
    "video_assets", "video_asset_sources", "video_asset_renditions",
]
tlist = ", ".join([f"'{t}'" for t in tables])
rows = query(f"SELECT table_schema, table_name FROM information_schema.tables WHERE table_name IN ({tlist}) ORDER BY table_schema, table_name")
if rows:
    for r in rows:
        print(f"  {r.get('table_schema','?')}.{r.get('table_name','?')}")
else:
    print("  [NONE FOUND] — tables do not exist in any schema")
    # List all schemas
    schemas = query("SELECT schema_name FROM information_schema.schemata ORDER BY schema_name")
    if schemas:
        print(f"\n  Available schemas: {[s.get('schema_name') for s in schemas]}")

# 2. List ALL app_* functions
print("\n" + "=" * 70)
print("2. ALL app_student_* and app_videoasset_* FUNCTIONS IN DB")
print("=" * 70)
funcs = query("SELECT proname FROM pg_proc WHERE pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public') AND (proname LIKE 'app_student_%' OR proname LIKE 'app_videoasset_%' OR proname LIKE 'app_public_%') ORDER BY proname")
if funcs:
    for f in funcs:
        print(f"  {f.get('proname','?')}")
    print(f"\n  Total: {len(funcs)} functions")
else:
    print("  [NONE FOUND]")

# 3. List ALL schemas with table counts
print("\n" + "=" * 70)
print("3. SCHEMAS WITH TABLE COUNTS")
print("=" * 70)
schema_counts = query("SELECT table_schema, count(*) as cnt FROM information_schema.tables WHERE table_type = 'BASE TABLE' GROUP BY table_schema ORDER BY cnt DESC")
if schema_counts:
    for s in schema_counts:
        print(f"  {s.get('table_schema','?')}: {s.get('cnt','?')} tables")

# 4. List tables in 'app' schema if it exists
print("\n" + "=" * 70)
print("4. TABLES IN NON-PUBLIC SCHEMAS (looking for challenge/video tables)")
print("=" * 70)
all_tables = query("SELECT table_schema, table_name FROM information_schema.tables WHERE table_type = 'BASE TABLE' AND table_schema NOT IN ('pg_catalog', 'information_schema') AND (table_name LIKE '%challenge%' OR table_name LIKE '%video%' OR table_name LIKE '%free_video%') ORDER BY table_schema, table_name")
if all_tables:
    for t in all_tables:
        print(f"  {t.get('table_schema','?')}.{t.get('table_name','?')}")
else:
    print("  [NONE FOUND]")

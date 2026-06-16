#!/usr/bin/env python3
"""
Fix 1: Drop the overloaded app_videoasset_get_playback_manifest (2-arg version)
Fix 2: Audit actual column names in free_videos and challenge_participations
"""
import sys
import json
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from supabase_auto_manager import SupabaseAutoManager
import requests

manager = SupabaseAutoManager()
url_rpc = f"{manager.url}/rest/v1/rpc/admin_execute_sql"


def exec_sql(sql):
    r = requests.post(url_rpc, headers=manager.headers, json={"p_sql": sql}, timeout=20)
    data = r.json()
    return data


# ── Fix 1: Drop the 2-arg overload ──
print("=" * 70)
print("FIX 1: Drop overloaded app_videoasset_get_playback_manifest")
print("=" * 70)

# First, list both overloads
result = exec_sql(
    "SELECT p.oid, pg_get_function_arguments(p.oid) as args "
    "FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid "
    "WHERE n.nspname = 'public' AND p.proname = 'app_videoasset_get_playback_manifest'"
)
print(f"Current overloads: {json.dumps(result, indent=2)}")

# Drop the 2-arg version (with p_client_capabilities)
print("\nDropping 2-arg version...")
drop_result = exec_sql(
    "DROP FUNCTION IF EXISTS public.app_videoasset_get_playback_manifest(uuid, jsonb)"
)
print(f"Drop result: {drop_result}")

# Verify only 1 remains
result2 = exec_sql(
    "SELECT pg_get_function_arguments(p.oid) as args "
    "FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid "
    "WHERE n.nspname = 'public' AND p.proname = 'app_videoasset_get_playback_manifest'"
)
print(f"After fix: {json.dumps(result2, indent=2)}")

# ── Fix 2: Audit column names ──
print("\n" + "=" * 70)
print("FIX 2: Audit column names in critical tables")
print("=" * 70)

tables_to_check = [
    "app.free_videos",
    "app.challenge_participations",
    "app.video_comments",
    "app.video_likes",
    "app.video_favorites",
    "app.challenges",
    "app.video_assets",
]

for table in tables_to_check:
    schema, tname = table.split(".")
    cols = exec_sql(
        f"SELECT column_name, data_type FROM information_schema.columns "
        f"WHERE table_schema = '{schema}' AND table_name = '{tname}' "
        f"ORDER BY ordinal_position"
    )
    rows = cols.get("rows", []) if isinstance(cols, dict) else []
    print(f"\n  {table} ({len(rows)} columns):")
    for c in rows:
        print(f"    {c.get('column_name')}: {c.get('data_type')}")

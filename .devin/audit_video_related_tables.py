#!/usr/bin/env python3
"""Audit all video-related tables to understand the exact schema."""
import sys
import json
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from supabase_auto_manager import SupabaseAutoManager
import requests

manager = SupabaseAutoManager()

def exec_sql(sql):
    r = requests.post(f"{manager.url}/rest/v1/rpc/admin_execute_sql",
                      headers=manager.headers, json={"p_sql": sql}, timeout=20)
    data = r.json()
    return data.get("rows", []) if isinstance(data, dict) else []

# Tables to fully audit
tables = [
    "app.free_videos",
    "app.free_video_overlays",
    "app.free_video_render_jobs",
    "app.challenge_participations",
    "app.challenge_participation_videos",
    "app.challenge_video_overlays",
    "app.challenge_video_assets",
    "app.video_assets",
    "app.video_sources",
    "app.video_renditions",
]

for table in tables:
    schema, tname = table.split(".")
    cols = exec_sql(
        f"SELECT column_name, data_type, is_nullable "
        f"FROM information_schema.columns "
        f"WHERE table_schema = '{schema}' AND table_name = '{tname}' "
        f"ORDER BY ordinal_position"
    )
    print(f"\n{'='*60}")
    print(f"{table} ({len(cols)} columns)")
    print("=" * 60)
    for c in cols:
        print(f"  {c['column_name']:30s} {c['data_type']:30s} {'NULL' if c['is_nullable']=='YES' else 'NOT NULL'}")

# Check how the unified feed RPC resolves video URLs
print(f"\n{'='*60}")
print("CHECKING app_student_unified_video_feed source code")
print("=" * 60)
src = exec_sql(
    "SELECT pg_get_functiondef(p.oid) as src "
    "FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid "
    "WHERE n.nspname = 'public' AND p.proname = 'app_student_unified_video_feed'"
)
if src:
    code = src[0].get("src", "")
    # Print first 3000 chars
    print(code[:3000])
    if len(code) > 3000:
        print(f"\n... ({len(code)} total chars)")

# Check app_student_list_user_videos source
print(f"\n{'='*60}")
print("CHECKING app_student_list_user_videos source code")
print("=" * 60)
src2 = exec_sql(
    "SELECT pg_get_functiondef(p.oid) as src "
    "FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid "
    "WHERE n.nspname = 'public' AND p.proname = 'app_student_list_user_videos'"
)
if src2:
    code2 = src2[0].get("src", "")
    print(code2[:3000])
else:
    print("  [NOT FOUND]")

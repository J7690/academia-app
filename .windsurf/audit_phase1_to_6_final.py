#!/usr/bin/env python3
"""
Audit rigoureux Phase 1-6 : vérifie TOUTES les RPC Flutter vs Supabase DB.
Utilise admin_execute_sql via SupabaseAutoManager (.windsurf).
"""
from __future__ import annotations

import json
import sys
import time
from pathlib import Path

import requests

# Import SupabaseAutoManager from .windsurf
sys.path.insert(0, str(Path(__file__).parent))
from supabase_auto_manager import SupabaseAutoManager


# ALL RPC names called from Flutter providers (challenges + videoasset + services)
ALL_RPCS = [
    "app_public_get_challenge_leaderboard",
    "app_student_add_challenge_comment",
    "app_student_add_challenge_video",
    "app_student_add_video_comment",
    "app_student_create_free_video",
    "app_student_delete_video_comment",
    "app_student_favorite_challenge_video",
    "app_student_get_challenge_video",
    "app_student_get_free_video",
    "app_student_get_my_challenge_stats",
    "app_student_join_challenge",
    "app_student_like_challenge_video",
    "app_student_list_challenge_comments",
    "app_student_list_challenge_video_render_jobs",
    "app_student_list_challenges",
    "app_student_list_free_video_render_jobs",
    "app_student_list_my_challenge_participations",
    "app_student_list_my_challenge_videos",
    "app_student_list_user_videos",
    "app_student_list_video_comments",
    "app_student_mark_challenge_completed",
    "app_student_report_challenge_video",
    "app_student_report_video",
    "app_student_set_free_video_main_renditions",
    "app_student_start_duo_challenge_video",
    "app_student_start_duo_video",
    "app_student_submit_challenge",
    "app_student_unfavorite_challenge_video",
    "app_student_unified_video_feed",
    "app_student_unlike_challenge_video",
    "app_student_update_challenge_video_overlays",
    "app_student_update_free_video_overlays",
    "app_student_video_favorite",
    "app_student_video_like",
    "app_student_video_unfavorite",
    "app_student_video_unlike",
    "app_videoasset_create_upload_intent",
    "app_videoasset_get_playback_for_direct_url",
    "app_videoasset_get_playback_manifest",
    "app_videoasset_register_uploaded_source",
]

CRITICAL_TABLES = [
    "challenges",
    "challenge_participations",
    "student_free_videos",
    "video_comments",
    "video_likes",
    "video_favorites",
    "video_reports",
    "video_assets",
    "video_asset_sources",
    "video_asset_renditions",
]


def exec_sql(manager, sql, retries=3):
    """Execute SQL via admin_execute_sql RPC with retry."""
    url = f"{manager.url}/rest/v1/rpc/admin_execute_sql"
    for attempt in range(retries):
        try:
            resp = requests.post(
                url,
                headers=manager.headers,
                json={"p_sql": sql},
                timeout=20,
            )
            if resp.status_code == 200:
                return resp.json()
            else:
                return {"error": resp.status_code, "body": resp.text[:300]}
        except Exception as e:
            if attempt < retries - 1:
                time.sleep(2)
                continue
            return {"error": str(e)}
    return None


def parse_rows(result):
    """Extract row data from admin_execute_sql response."""
    if result is None:
        return []
    if isinstance(result, list):
        return result
    if isinstance(result, dict):
        if "data" in result and isinstance(result["data"], list):
            return result["data"]
        if "rows" in result and isinstance(result["rows"], list):
            return result["rows"]
    return []


def main():
    manager = SupabaseAutoManager()

    print("=" * 70)
    print("AUDIT RIGOUREUX — RPC Flutter vs Supabase DB (Phase 1-6)")
    print(f"URL: {manager.url}")
    print("=" * 70)

    # ── 1. Test connectivity ──
    print("\n[0/3] Testing admin_execute_sql connectivity...")
    test = exec_sql(manager, "SELECT 1 as ok")
    if test is None or (isinstance(test, dict) and "error" in test):
        print(f"[FATAL] admin_execute_sql not reachable: {test}")
        sys.exit(1)
    print(f"  [OK] Connected. Response: {test}")

    # ── 2. Check all RPCs in one query ──
    print("\n[1/3] Checking all RPCs...")
    rpc_list = ", ".join([f"''{r}''" for r in ALL_RPCS])
    sql = (
        "SELECT p.proname as name "
        "FROM pg_proc p "
        "JOIN pg_namespace n ON p.pronamespace = n.oid "
        f"WHERE n.nspname = ''public'' AND p.proname IN ({rpc_list}) "
        "ORDER BY p.proname"
    )
    result = exec_sql(manager, sql)
    rows = parse_rows(result)

    found_names = set()
    for row in rows:
        if isinstance(row, dict):
            name = row.get("name") or row.get("proname")
            if name:
                found_names.add(name)

    if not found_names and rows:
        # Maybe the response format is different, print it for debug
        print(f"  [DEBUG] Raw response: {json.dumps(result, default=str)[:500]}")

    missing_rpcs = []
    found_rpcs = []
    for rpc_name in ALL_RPCS:
        if rpc_name in found_names:
            found_rpcs.append(rpc_name)
            print(f"  [OK]      {rpc_name}")
        else:
            missing_rpcs.append(rpc_name)
            print(f"  [MISSING] {rpc_name}")

    # ── 3. Check critical tables ──
    print(f"\n[2/3] Checking critical tables...")
    table_list = ", ".join([f"''{t}''" for t in CRITICAL_TABLES])
    table_sql = (
        "SELECT table_name FROM information_schema.tables "
        f"WHERE table_schema = ''public'' AND table_name IN ({table_list}) "
        "ORDER BY table_name"
    )
    table_result = exec_sql(manager, table_sql)
    table_rows = parse_rows(table_result)

    found_tables = set()
    for row in table_rows:
        if isinstance(row, dict):
            t = row.get("table_name")
            if t:
                found_tables.add(t)

    missing_tables = []
    for t in CRITICAL_TABLES:
        if t in found_tables:
            print(f"  [OK]      {t}")
        else:
            missing_tables.append(t)
            print(f"  [MISSING] {t}")

    # ── 4. Summary ──
    print(f"\n[3/3] SUMMARY")
    print("=" * 70)
    print(f"RPCs:   {len(found_rpcs)}/{len(ALL_RPCS)} found, {len(missing_rpcs)} MISSING")
    print(f"Tables: {len(found_tables)}/{len(CRITICAL_TABLES)} found, {len(missing_tables)} MISSING")

    if missing_rpcs:
        print(f"\n{'='*70}")
        print("MISSING RPCs (MUST BE CREATED):")
        print("=" * 70)
        for m in missing_rpcs:
            print(f"  - {m}")

    if missing_tables:
        print(f"\n{'='*70}")
        print("MISSING TABLES (MUST BE CREATED):")
        print("=" * 70)
        for t in missing_tables:
            print(f"  - {t}")

    if not missing_rpcs and not missing_tables:
        print("\n[ALL CLEAR] Everything is deployed correctly.")

    return len(missing_rpcs) + len(missing_tables)


if __name__ == "__main__":
    count = main()
    sys.exit(1 if count > 0 else 0)

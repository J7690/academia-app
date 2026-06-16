"""
Audit rigoureux Phase 1-6 : vérifie que TOUTES les RPC appelées côté Flutter
existent réellement dans la base Supabase, via execute_sql RPC admin.
"""
import requests
import json
import sys

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

HEADERS = {
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Content-Type": "application/json"
}

# All RPC names called from student_challenges_provider.dart
CHALLENGE_RPCS = [
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
    "app_videoasset_get_playback_for_direct_url",
    "app_videoasset_get_playback_manifest",
]

# VideoAsset upload service RPCs
VIDEOASSET_RPCS = [
    "app_videoasset_create_upload_intent",
    "app_videoasset_register_uploaded_source",
]

# All RPCs to check
ALL_RPCS = CHALLENGE_RPCS + VIDEOASSET_RPCS


def execute_sql(sql):
    resp = requests.post(
        f"{URL}/rest/v1/rpc/execute_sql",
        headers=HEADERS,
        json={"sql_query": sql},
    )
    if resp.status_code != 200:
        print(f"  [HTTP {resp.status_code}] {resp.text[:200]}")
        return None
    return resp.json()


def check_function_exists(name):
    sql = f"""
    SELECT p.proname, pg_get_function_arguments(p.oid) as args,
           pg_get_function_result(p.oid) as return_type
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public' AND p.proname = '{name}';
    """
    result = execute_sql(sql)
    if result is None:
        return None
    if isinstance(result, list) and len(result) > 0:
        return result
    if isinstance(result, dict) and result.get("rows"):
        return result["rows"]
    return None


def main():
    print("=" * 70)
    print("AUDIT RIGOUREUX — RPC Flutter vs Supabase DB")
    print("=" * 70)

    # Test execute_sql connectivity
    test = execute_sql("SELECT 1 as ok")
    if test is None:
        print("\n[FATAL] execute_sql RPC not reachable. Aborting.")
        sys.exit(1)
    print(f"\n[OK] execute_sql connectivity verified: {test}\n")

    missing = []
    found = []
    errors = []

    for rpc_name in ALL_RPCS:
        result = check_function_exists(rpc_name)
        if result:
            found.append(rpc_name)
            print(f"  [EXISTS] {rpc_name}")
        elif result is None:
            errors.append(rpc_name)
            print(f"  [ERROR]  {rpc_name} — could not check")
        else:
            missing.append(rpc_name)
            print(f"  [MISSING] {rpc_name}")

    print("\n" + "=" * 70)
    print(f"SUMMARY: {len(found)} found, {len(missing)} MISSING, {len(errors)} errors")
    print("=" * 70)

    if missing:
        print("\nMISSING RPCs (must be created):")
        for m in missing:
            print(f"  - {m}")

    if errors:
        print("\nERROR RPCs (could not verify):")
        for e in errors:
            print(f"  - {e}")

    # Also check critical tables
    print("\n" + "=" * 70)
    print("CHECKING CRITICAL TABLES")
    print("=" * 70)

    tables = [
        "challenges", "challenge_participations", "student_free_videos",
        "video_comments", "video_likes", "video_favorites", "video_reports",
        "video_assets", "video_asset_sources", "video_asset_renditions",
    ]
    for t in tables:
        sql = f"SELECT EXISTS(SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='{t}') as exists_flag"
        result = execute_sql(sql)
        if result and isinstance(result, list) and len(result) > 0:
            exists = result[0].get("exists_flag", False)
            status = "[EXISTS]" if exists else "[MISSING]"
        else:
            status = "[ERROR]"
        print(f"  {status} {t}")

    print("\n[DONE] Audit complete.")


if __name__ == "__main__":
    main()

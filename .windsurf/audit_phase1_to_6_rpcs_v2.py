"""
Audit rigoureux Phase 1-6 : vérifie TOUTES les RPC Flutter vs Supabase DB.
Utilise execute_sql RPC admin avec retry et gestion d'erreur robuste.
"""
import requests
import json
import sys
import time

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

HEADERS = {
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Content-Type": "application/json"
}

# ALL RPC names called from Flutter (challenges + videoasset)
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
    "challenges", "challenge_participations", "student_free_videos",
    "video_comments", "video_likes", "video_favorites", "video_reports",
    "video_assets", "video_asset_sources", "video_asset_renditions",
]


def execute_sql(sql, retries=3):
    for attempt in range(retries):
        try:
            resp = requests.post(
                f"{URL}/rest/v1/rpc/execute_sql",
                headers=HEADERS,
                json={"sql_query": sql},
                timeout=15,
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


def main():
    print("=" * 70)
    print("AUDIT RIGOUREUX — RPC Flutter vs Supabase DB (Phase 1-6)")
    print("=" * 70)

    # Single batch query: check ALL functions at once
    rpc_list_sql = ", ".join([f"'{r}'" for r in ALL_RPCS])
    sql = f"""
    SELECT p.proname as name,
           pg_get_function_arguments(p.oid) as args,
           pg_get_function_result(p.oid) as return_type
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public'
      AND p.proname IN ({rpc_list_sql})
    ORDER BY p.proname;
    """

    print("\n[1/3] Checking all RPCs in a single query...")
    result = execute_sql(sql)

    if result is None or (isinstance(result, dict) and "error" in result):
        print(f"\n[FATAL] execute_sql failed: {result}")
        print("Trying alternative approach via list_tables_detailed...")
        # Fallback: try a simpler query
        result2 = execute_sql("SELECT proname FROM pg_proc WHERE pronamespace = (SELECT oid FROM pg_namespace WHERE nspname='public') AND proname LIKE 'app_%' ORDER BY proname;")
        if result2 is None or (isinstance(result2, dict) and "error" in result2):
            print(f"[FATAL] Fallback also failed: {result2}")
            sys.exit(1)
        result = result2

    # Parse result
    found_names = set()
    if isinstance(result, list):
        for row in result:
            if isinstance(row, dict):
                name = row.get("name") or row.get("proname")
                if name:
                    found_names.add(name)
    elif isinstance(result, dict) and "rows" in result:
        for row in result["rows"]:
            name = row.get("name") or row.get("proname")
            if name:
                found_names.add(name)

    print(f"\nFound {len(found_names)} app_* functions in DB.\n")

    missing = []
    found = []
    for rpc_name in ALL_RPCS:
        if rpc_name in found_names:
            found.append(rpc_name)
            print(f"  [OK]      {rpc_name}")
        else:
            missing.append(rpc_name)
            print(f"  [MISSING] {rpc_name}")

    # Check tables
    print(f"\n[2/3] Checking critical tables...")
    table_list_sql = ", ".join([f"'{t}'" for t in CRITICAL_TABLES])
    table_sql = f"""
    SELECT table_name FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name IN ({table_list_sql})
    ORDER BY table_name;
    """
    table_result = execute_sql(table_sql)
    found_tables = set()
    if isinstance(table_result, list):
        for row in table_result:
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

    # Summary
    print(f"\n[3/3] SUMMARY")
    print("=" * 70)
    print(f"RPCs:   {len(found)}/{len(ALL_RPCS)} found, {len(missing)} MISSING")
    print(f"Tables: {len(found_tables)}/{len(CRITICAL_TABLES)} found, {len(missing_tables)} MISSING")

    if missing:
        print(f"\n{'='*70}")
        print("MISSING RPCs (MUST BE CREATED):")
        print("="*70)
        for m in missing:
            print(f"  - {m}")

    if missing_tables:
        print(f"\n{'='*70}")
        print("MISSING TABLES (MUST BE CREATED):")
        print("="*70)
        for t in missing_tables:
            print(f"  - {t}")

    if not missing and not missing_tables:
        print("\n[ALL CLEAR] No missing RPCs or tables. Everything is deployed correctly.")

    return len(missing) + len(missing_tables)


if __name__ == "__main__":
    exit_code = main()
    sys.exit(1 if exit_code > 0 else 0)

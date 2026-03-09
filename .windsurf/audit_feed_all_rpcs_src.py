#!/usr/bin/env python3
"""Check source of ALL feed interaction RPCs to see which are disabled."""
import requests
from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()
    url = f"{m.url}/rest/v1/rpc/execute_sql"
    rpcs = [
        'app_student_unlike_challenge_video',
        'app_student_video_unlike',
        'app_student_favorite_challenge_video',
        'app_student_unfavorite_challenge_video',
        'app_student_video_favorite',
        'app_student_video_unfavorite',
        'app_student_report_challenge_video',
        'app_student_report_video',
        'app_student_list_challenge_comments',
        'app_student_list_video_comments',
        'app_student_start_duo_challenge_video',
        'app_student_start_duo_video',
    ]
    for r in rpcs:
        sql = f"SELECT prosrc FROM pg_proc WHERE proname = '{r}' LIMIT 1"
        resp = requests.post(url, headers=m.headers, json={"sql_query": sql}, timeout=60)
        if resp.status_code == 200:
            data = resp.json()
            if isinstance(data, list) and data:
                src = data[0].get('prosrc', '').strip()
                disabled = 'legacy_rpc_disabled' in src
                print(f"{'DISABLED' if disabled else 'ACTIVE  '} | {r}")
                if not disabled:
                    print(f"  {src[:200]}")
            else:
                print(f"MISSING  | {r}")
        else:
            print(f"ERROR    | {r} -> {resp.status_code}")

if __name__ == "__main__":
    main()

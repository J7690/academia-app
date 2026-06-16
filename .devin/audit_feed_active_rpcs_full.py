#!/usr/bin/env python3
"""Get full source of active RPCs to use as template for recreating disabled ones."""
import requests
from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()
    url = f"{m.url}/rest/v1/rpc/execute_sql"
    rpcs = [
        'app_student_unlike_challenge_video',
        'app_student_video_unlike',
        'app_student_unfavorite_challenge_video',
        'app_student_video_unfavorite',
    ]
    for r in rpcs:
        sql = f"SELECT prosrc FROM pg_proc WHERE proname = '{r}' LIMIT 1"
        resp = requests.post(url, headers=m.headers, json={"sql_query": sql}, timeout=60)
        if resp.status_code == 200:
            data = resp.json()
            if isinstance(data, list) and data:
                src = data[0].get('prosrc', '').strip()
                print(f"\n{'='*60}")
                print(f"=== {r} ===")
                print(f"{'='*60}")
                print(src)

if __name__ == "__main__":
    main()

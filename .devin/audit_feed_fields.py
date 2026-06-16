#!/usr/bin/env python3
"""Check what fields the unified video feed returns, especially video_url, has_liked, etc."""

from __future__ import annotations
import json, requests
from supabase_auto_manager import SupabaseAutoManager

def main() -> int:
    m = SupabaseAutoManager()

    # 1) Check the source code of app_student_unified_video_feed
    url = f"{m.url}/rest/v1/rpc/execute_sql"
    sql = """
    SELECT prosrc
    FROM pg_proc
    WHERE proname = 'app_student_unified_video_feed'
    LIMIT 1
    """
    resp = requests.post(url, headers=m.headers, json={"sql_query": sql}, timeout=60)
    if resp.status_code == 200:
        data = resp.json()
        if isinstance(data, list) and data:
            src = data[0].get('prosrc', '')
            print("=== app_student_unified_video_feed SOURCE ===")
            print(src[:5000])
        else:
            print("No source found")
    else:
        print(f"ERROR {resp.status_code}: {resp.text[:500]}")

    # 2) Check source of like RPC
    for rpc in ['app_student_like_challenge_video', 'app_student_video_like',
                'app_student_add_challenge_comment', 'app_student_add_video_comment']:
        sql2 = f"SELECT prosrc FROM pg_proc WHERE proname = '{rpc}' LIMIT 1"
        resp2 = requests.post(url, headers=m.headers, json={"sql_query": sql2}, timeout=60)
        if resp2.status_code == 200:
            data2 = resp2.json()
            if isinstance(data2, list) and data2:
                src2 = data2[0].get('prosrc', '')
                print(f"\n=== {rpc} SOURCE ===")
                print(src2[:3000])

    return 0

if __name__ == "__main__":
    raise SystemExit(main())

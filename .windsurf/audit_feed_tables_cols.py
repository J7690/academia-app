#!/usr/bin/env python3
"""Get column info for all social tables used by feed interactions."""
import requests
from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()
    url = f"{m.url}/rest/v1/rpc/execute_sql"
    tables = [
        'challenge_likes', 'video_likes', 'challenge_favorites', 'video_favorites',
        'video_comments', 'video_reports',
    ]
    for t in tables:
        sql = f"""
        SELECT column_name, data_type, is_nullable, column_default
        FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = '{t}'
        ORDER BY ordinal_position
        """
        resp = requests.post(url, headers=m.headers, json={"sql_query": sql}, timeout=60)
        if resp.status_code == 200:
            data = resp.json()
            if isinstance(data, list) and data:
                print(f"\n=== app.{t} ===")
                for row in data:
                    print(f"  {row['column_name']:30s} {row['data_type']:30s} null={row['is_nullable']}  default={row.get('column_default','')}")
            else:
                print(f"\nMISSING: app.{t}")

if __name__ == "__main__":
    main()

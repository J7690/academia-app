#!/usr/bin/env python3
"""Deploy community_stories schema to Supabase via admin_execute_sql"""
import requests, json, sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()
    sql_file = Path(__file__).parent / "sql" / "community_stories_schema.sql"
    sql = sql_file.read_text(encoding="utf-8")

    # Split by semicolons and execute each statement
    statements = [s.strip() for s in sql.split(";") if s.strip() and not s.strip().startswith("--")]

    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    all_ok = True

    for idx, stmt in enumerate(statements, 1):
        print(f"\n--- Statement {idx}/{len(statements)} ---")
        print(stmt[:200] + "..." if len(stmt) > 200 else stmt)

        try:
            resp = requests.post(url, headers=m.headers, json={"p_sql": stmt}, timeout=30)
            print(f"  Status: {resp.status_code}")
            data = resp.json() if resp.status_code == 200 else resp.text[:300]
            if isinstance(data, dict):
                if data.get("ok") == True:
                    print(f"  OK: {data.get('mode', '?')} affected={data.get('affected_rows', '?')}")
                elif "error" in data:
                    err = data.get("error", "")
                    if "already exists" in str(err):
                        print(f"  SKIP (already exists)")
                    else:
                        print(f"  ERROR: {err}")
                        all_ok = False
                else:
                    print(f"  Result: {json.dumps(data, default=str)[:200]}")
            else:
                print(f"  Result: {str(data)[:200]}")
        except Exception as e:
            print(f"  EXCEPTION: {e}")
            all_ok = False

    print(f"\n{'='*50}")
    print("ALL OK" if all_ok else "SOME ERRORS")
    return 0 if all_ok else 1

if __name__ == "__main__":
    sys.exit(main())

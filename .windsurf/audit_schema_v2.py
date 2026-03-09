#!/usr/bin/env python3
"""Audit Supabase schema — essaie plusieurs RPCs pour obtenir les colonnes réelles."""

import requests
import json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
HEADERS = {
    "apikey": KEY,
    "Authorization": f"Bearer {KEY}",
    "Content-Type": "application/json",
    "Accept": "application/json",
}


def try_rpc(rpc_name, payload):
    """Try calling an RPC and return the JSON response."""
    resp = requests.post(
        f"{URL}/rest/v1/rpc/{rpc_name}",
        headers=HEADERS,
        json=payload,
        timeout=30,
    )
    return resp.status_code, resp.json() if resp.status_code == 200 else resp.text[:500]


def main():
    # Strategy 1: Try execute_sql (old RPC that returns query results)
    print("=== Strategy 1: execute_sql ===")
    code, data = try_rpc("execute_sql", {
        "sql_query": "SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='challenge_participations' ORDER BY ordinal_position"
    })
    print(f"  Status: {code}")
    print(f"  Response: {json.dumps(data, indent=2, ensure_ascii=False, default=str)[:2000]}")

    if code != 200 or not isinstance(data, (list, dict)):
        # Strategy 2: Try admin_execute_sql with explicit JSONB wrapping
        print("\n=== Strategy 2: admin_execute_sql with JSONB wrapper ===")
        code, data = try_rpc("admin_execute_sql", {
            "p_sql": "SELECT JSONB_AGG(JSONB_BUILD_OBJECT('col', column_name, 'type', data_type)) FROM information_schema.columns WHERE table_schema='app' AND table_name='challenge_participations'"
        })
        print(f"  Status: {code}")
        print(f"  Response: {json.dumps(data, indent=2, ensure_ascii=False, default=str)[:2000]}")

    # Now let's get all the tables we need
    tables = [
        'challenge_participations',
        'free_videos',
        'challenges',
        'video_likes',
        'video_comments',
        'video_reports',
        'challenge_favorites',
        'challenge_video_overlays',
        'free_video_overlays',
        'challenge_likes',
    ]

    print("\n\n" + "=" * 70)
    print("  AUDIT COMPLET DES COLONNES (via execute_sql)")
    print("=" * 70)

    for table in tables:
        sql = f"SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='{table}' ORDER BY ordinal_position"
        code, data = try_rpc("execute_sql", {"sql_query": sql})
        print(f"\n--- app.{table} (status={code}) ---")
        if code == 200 and isinstance(data, list) and data:
            # execute_sql returns a list of dicts or a JSONB blob
            for row in data:
                if isinstance(row, dict):
                    col = row.get('column_name', row.get('col', '?'))
                    dtype = row.get('data_type', row.get('type', '?'))
                    print(f"  {col:40s} {dtype}")
                else:
                    print(f"  {row}")
        elif code == 200 and isinstance(data, dict):
            # Might be wrapped
            rows = data.get('rows', data.get('data', [data]))
            if isinstance(rows, list):
                for row in rows:
                    if isinstance(row, dict):
                        col = row.get('column_name', row.get('col', '?'))
                        dtype = row.get('data_type', row.get('type', '?'))
                        print(f"  {col:40s} {dtype}")
            else:
                print(f"  RAW: {json.dumps(data, default=str)[:500]}")
        else:
            print(f"  ERROR: {data}")

    # Also list all tables in app schema
    print(f"\n--- ALL TABLES in schema 'app' ---")
    sql = "SELECT table_name FROM information_schema.tables WHERE table_schema='app' ORDER BY table_name"
    code, data = try_rpc("execute_sql", {"sql_query": sql})
    if code == 200 and isinstance(data, list):
        for row in data:
            if isinstance(row, dict):
                print(f"  {row.get('table_name', '?')}")
            else:
                print(f"  {row}")
    elif code == 200 and isinstance(data, dict):
        rows = data.get('rows', [])
        if isinstance(rows, list):
            for row in rows:
                if isinstance(row, dict):
                    print(f"  {row.get('table_name', '?')}")
        else:
            print(f"  RAW: {json.dumps(data, default=str)[:1000]}")
    else:
        print(f"  ERROR: {data}")


if __name__ == "__main__":
    main()

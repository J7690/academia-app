#!/usr/bin/env python3
"""Dump pg_get_functiondef for specific functions via admin_execute_sql.

We use this because apply_one_sql_via_admin_rpc may hide SELECT outputs.
"""

from __future__ import annotations

import json
import requests

from supabase_auto_manager import SupabaseAutoManager


def run(sql: str) -> None:
    m = SupabaseAutoManager()
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    resp = requests.post(url, headers=m.headers, json={"p_sql": sql.strip()}, timeout=60)
    print("\n=== SQL ===")
    print(sql.strip())
    print("HTTP", resp.status_code)
    if resp.status_code != 200:
        print(resp.text[:2000])
        return
    try:
        payload = resp.json()
    except Exception:
        print(resp.text[:2000])
        return
    print(json.dumps(payload, indent=2, ensure_ascii=False)[:20000])


def main() -> None:
    run(
        """
        SELECT pg_get_functiondef(p.oid) AS ddl
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
          AND p.proname = 'app_videoasset_get_playback_manifest'
          AND p.oid::regprocedure::text = 'app_videoasset_get_playback_manifest(uuid)'
        """
    )

    run(
        """
        SELECT pg_get_functiondef(p.oid) AS ddl
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
          AND p.proname = 'app_videoasset_get_playback_for_direct_url'
          AND p.oid::regprocedure::text = 'app_videoasset_get_playback_for_direct_url(text)'
        """
    )


if __name__ == '__main__':
    main()

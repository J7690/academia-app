#!/usr/bin/env python3
"""Dump overloads + functiondefs for app_videoasset_get_playback_manifest.

Uses admin_execute_sql and prints JSON for verifiable audit.
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
        SELECT
          n.nspname AS schema,
          p.proname AS function_name,
          p.oid::regprocedure::text AS signature,
          r.rolname AS owner,
          p.prosecdef AS security_definer
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        JOIN pg_roles r ON r.oid = p.proowner
        WHERE p.proname = 'app_videoasset_get_playback_manifest'
        ORDER BY n.nspname, p.oid::regprocedure::text
        """
    )

    run(
        """
        SELECT pg_get_functiondef(p.oid) AS ddl
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE p.proname = 'app_videoasset_get_playback_manifest'
        ORDER BY n.nspname, p.oid::regprocedure::text
        """
    )


if __name__ == '__main__':
    main()

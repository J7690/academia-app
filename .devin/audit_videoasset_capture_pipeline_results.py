#!/usr/bin/env python3
"""Re-run key SELECT audits for VideoAsset capture pipeline with full output.

The generic apply_one_sql_via_admin_rpc helper may hide SELECT outputs depending on parsing.
This script executes each SELECT via admin_execute_sql and prints rows.
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
        print(resp.text[:1200])
        return
    try:
        payload = resp.json()
    except Exception:
        print(resp.text[:1200])
        return
    print(json.dumps(payload, indent=2, ensure_ascii=False)[:12000])


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
        WHERE p.proname IN (
          'app_videoasset_create_upload_intent',
          'app_videoasset_register_uploaded_source',
          'app_videoasset_get_playback_for_direct_url',
          'app_videoasset_get_playback_manifest'
        )
        ORDER BY n.nspname, p.proname, p.oid::regprocedure::text
        """
    )

    run(
        """
        SELECT table_schema, table_name
        FROM information_schema.tables
        WHERE table_name IN (
          'video_assets',
          'video_sources',
          'video_renditions',
          'video_asset_contexts',
          'video_processing_jobs'
        )
          AND table_schema IN ('app', 'public')
        ORDER BY table_schema, table_name
        """
    )

    # NOTE: Other deep-dive queries exist in sql_changes/audit_videoasset_capture_pipeline.sql
    # Keep this script focused to avoid truncation in terminal output.


if __name__ == '__main__':
    main()

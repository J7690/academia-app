#!/usr/bin/env python3
"""Runtime verification after fixing playback manifest RPC.

Prints actual outputs for:
- public.app_videoasset_get_playback_manifest(uuid)
- public.app_videoasset_get_playback_for_direct_url(text)

Uses admin_execute_sql so results are verifiable.
"""

from __future__ import annotations

import os
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
    target = (os.environ.get('VIDEO_ASSET_ID') or '').strip()
    forced_uuid_sql = f"'{target}'::uuid" if target else "NULL::uuid"

    run(
        f"""
        WITH chosen AS (
          SELECT COALESCE(
            {forced_uuid_sql},
            (SELECT id FROM app.video_assets WHERE deleted_at IS NULL ORDER BY created_at DESC LIMIT 1)
          ) AS id
        )
        SELECT id AS picked_video_asset_id FROM chosen
        """
    )

    # Inspect asset row
    run(
        f"""
        WITH chosen AS (
          SELECT COALESCE(
            {forced_uuid_sql},
            (SELECT id FROM app.video_assets WHERE deleted_at IS NULL ORDER BY created_at DESC LIMIT 1)
          ) AS id
        )
        SELECT a.*
        FROM app.video_assets a
        WHERE a.id = (SELECT id FROM chosen)
        """
    )

    # Columns: app.video_sources
    run(
        """
        SELECT column_name, data_type
        FROM information_schema.columns
        WHERE table_schema='app'
          AND table_name='video_sources'
        ORDER BY ordinal_position
        """
    )

    # Columns: app.video_renditions
    run(
        """
        SELECT column_name, data_type
        FROM information_schema.columns
        WHERE table_schema='app'
          AND table_name='video_renditions'
        ORDER BY ordinal_position
        """
    )

    # Inspect latest sources (do not assume a specific 'role' column exists)
    run(
        f"""
        WITH chosen AS (
          SELECT COALESCE(
            {forced_uuid_sql},
            (SELECT id FROM app.video_assets WHERE deleted_at IS NULL ORDER BY created_at DESC LIMIT 1)
          ) AS id
        )
        SELECT s.*
        FROM app.video_sources s
        WHERE s.video_asset_id = (SELECT id FROM chosen)
        ORDER BY s.created_at DESC
        LIMIT 5
        """
    )

    # Inspect latest renditions
    run(
        f"""
        WITH chosen AS (
          SELECT COALESCE(
            {forced_uuid_sql},
            (SELECT id FROM app.video_assets WHERE deleted_at IS NULL ORDER BY created_at DESC LIMIT 1)
          ) AS id
        )
        SELECT r.*
        FROM app.video_renditions r
        WHERE r.video_asset_id = (SELECT id FROM chosen)
        ORDER BY r.created_at DESC
        LIMIT 5
        """
    )

    # Call manifest for chosen asset
    run(
        f"""
        WITH chosen AS (
          SELECT COALESCE(
            {forced_uuid_sql},
            (SELECT id FROM app.video_assets WHERE deleted_at IS NULL ORDER BY created_at DESC LIMIT 1)
          ) AS id
        )
        SELECT public.app_videoasset_get_playback_manifest((SELECT id FROM chosen)) AS manifest
        """
    )


if __name__ == '__main__':
    main()

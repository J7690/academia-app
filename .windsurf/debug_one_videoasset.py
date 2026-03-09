#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from textwrap import dedent

import requests

from supabase_auto_manager import SupabaseAutoManager


QUERIES = [
    (
        "video_asset_row",
        """
        SELECT id, status, origin, context_type, context_id,
               created_at, updated_at
        FROM app.video_assets
        WHERE id = %s::uuid
        """,
    ),
    (
        "video_jobs_for_asset",
        """
        SELECT id, job_type, status, created_at, updated_at
        FROM app.video_processing_jobs
        WHERE video_asset_id = %s::uuid
        ORDER BY created_at
        """,
    ),
    (
        "video_renditions_for_asset",
        """
        SELECT id, kind, status, storage_bucket, storage_path,
               public_url_hint, width, height, created_at, updated_at
        FROM app.video_renditions
        WHERE video_asset_id = %s::uuid
        ORDER BY kind, created_at
        """,
    ),
    (
        "hero_playlist_refs_for_asset",
        """
        SELECT id, slot, media_type, sort_order, is_active,
               base_video_url, base_image_url, video_asset_id, created_at
        FROM app.hero_playlist
        WHERE video_asset_id = %s::uuid
        ORDER BY created_at
        """,
    ),
]


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: debug_one_videoasset.py <video_asset_id>")
        return 1

    asset_id = sys.argv[1].strip()
    if not asset_id:
        print("video_asset_id is empty")
        return 1

    manager = SupabaseAutoManager()
    url = f"{manager.url}/rest/v1/rpc/admin_execute_sql"

    for label, sql_tpl in QUERIES:
        print("\n===== QUERY:", label, "for", asset_id, "=====")
        # admin_execute_sql enveloppe la requête dans un SELECT ... FROM (<p_sql>) t.
        # Pas de point-virgule final.
        sql = dedent(sql_tpl % ("'" + asset_id.replace("'", "''") + "'"))
        payload = {"p_sql": sql.strip().rstrip(";")}
        try:
            resp = requests.post(url, headers=manager.headers, json=payload, timeout=30)
        except Exception as exc:
            print("[ERROR] Network error:", exc)
            continue

        print("HTTP", resp.status_code)
        try:
            data = resp.json()
        except Exception:
            print(resp.text[:2000])
            continue

        print(json.dumps(data, indent=2, ensure_ascii=False)[:6000])

    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())

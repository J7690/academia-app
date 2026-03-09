#!/usr/bin/env python3
"""Backfill landing hero video_asset_id from latest uploaded landing-media video.

Read-only steps:
- Find latest landing_config row
- Find latest video file in storage.objects for bucket landing-media
- Resolve video_asset_id via public.app_videoasset_get_playback_for_direct_url(public_url)

Write steps (via admin_execute_sql):
- UPDATE app.landing_config.video_asset_id
- UPSERT app.video_asset_contexts (context_type='landing_config', role='hero')

Then verifies by calling public.app_public_landing_content() and printing config.playback.best_url.

This mutates the database.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import requests

sys.path.insert(0, str(Path(__file__).parent))
from supabase_auto_manager import SupabaseAutoManager

VIDEO_EXTS = (".mp4", ".mov", ".webm", ".m4v")


def admin_exec(m: SupabaseAutoManager, sql: str) -> Dict[str, Any]:
    r = requests.post(
        f"{m.url}/rest/v1/rpc/admin_execute_sql",
        headers=m.headers,
        json={"p_sql": sql},
        timeout=60,
    )
    r.raise_for_status()
    data = r.json()
    if not isinstance(data, dict) or data.get("ok") is not True:
        raise RuntimeError(f"admin_execute_sql failed: {data}")
    return data


def admin_rows(m: SupabaseAutoManager, sql: str) -> List[Dict[str, Any]]:
    data = admin_exec(m, sql)
    rows = data.get("rows")
    return rows if isinstance(rows, list) else []


def build_public_object_url(m: SupabaseAutoManager, bucket: str, object_name: str) -> str:
    # object_name is the storage.objects.name (path inside bucket)
    name = object_name.lstrip("/")
    return f"{m.url}/storage/v1/object/public/{bucket}/{name}"


def pick_latest_video_object(objs: List[Dict[str, Any]]) -> Optional[Dict[str, Any]]:
    for o in objs:
        name = (o.get("name") or "").lower()
        if any(name.endswith(ext) for ext in VIDEO_EXTS):
            return o
    return None


def esc_sql_literal(value: str) -> str:
    return value.replace("'", "''")


def main() -> int:
    m = SupabaseAutoManager()

    cfg = admin_rows(
        m,
        """
        SELECT id, video_asset_id, created_at, updated_at
        FROM app.landing_config
        ORDER BY created_at DESC
        LIMIT 1
        """.strip(),
    )
    if not cfg:
        print("[ERROR] No app.landing_config row found")
        return 1

    config_id = str(cfg[0]["id"])
    print("[INFO] landing_config latest:")
    print(json.dumps(cfg[0], indent=2, ensure_ascii=False))

    # List latest storage objects in landing-media
    objs = admin_rows(
        m,
        """
        SELECT name, bucket_id, created_at, updated_at, metadata
        FROM storage.objects
        WHERE bucket_id = 'landing-media'
        ORDER BY created_at DESC
        LIMIT 200
        """.strip(),
    )

    latest_video = pick_latest_video_object(objs)
    if not latest_video:
        print("[ERROR] No video object found in storage.objects for bucket landing-media")
        print("[HINT] Upload a .mp4/.mov/.webm into Landing first.")
        return 1

    object_name = str(latest_video["name"])
    public_url = build_public_object_url(m, "landing-media", object_name)
    print("[INFO] latest landing-media video object:")
    print(json.dumps(latest_video, indent=2, ensure_ascii=False))
    print("[INFO] public_url:")
    print(public_url)

    # Resolve playback manifest
    public_url_sql = public_url.replace("'", "''")
    playback_rows = admin_rows(
        m,
        f"SELECT public.app_videoasset_get_playback_for_direct_url('{public_url_sql}') AS payload",
    )
    if not playback_rows or not isinstance(playback_rows[0].get("payload"), dict):
        print("[ERROR] Invalid playback resolver response")
        print(json.dumps(playback_rows, indent=2, ensure_ascii=False))
        return 1

    payload = playback_rows[0]["payload"]
    video_asset_id: Optional[str] = None

    if payload.get("success") is True:
        manifest = payload.get("manifest")
        if isinstance(manifest, dict):
            raw = (manifest.get("video_asset_id") or "").strip()
            if raw:
                video_asset_id = raw

    if not video_asset_id:
        # Common case when calling from admin_execute_sql: auth.uid() is NULL, so RPC returns not_authenticated.
        # Fallback (SQL-only): create a synthetic VideoAsset + MP4 rendition pointing to the uploaded file.
        # This allows app_public_landing_content() to compute playback.best_url from app.video_renditions.
        if payload.get("error") not in ("not_authenticated", "not_authorized", None):
            print("[WARN] Playback resolver returned non-success (unexpected). Proceeding with fallback.")
        else:
            print("[INFO] Playback resolver not usable in admin context (not_authenticated). Using SQL fallback.")

        object_name_sql = esc_sql_literal(object_name)
        public_url_hint_sql = esc_sql_literal(public_url)
        config_id_sql = esc_sql_literal(config_id)

        # DO block starts with DO -> admin_execute_sql exec mode
        admin_exec(
            m,
            f"""
            DO $$
            DECLARE
              v_asset_id uuid := gen_random_uuid();
            BEGIN
              INSERT INTO app.video_assets (
                id,
                owner_user_id,
                origin,
                status,
                canonical_type,
                duration_ms,
                width,
                height,
                rotation,
                has_audio,
                created_at,
                updated_at
              ) VALUES (
                v_asset_id,
                NULL,
                'landing-media',
                'ready',
                'video',
                NULL,
                NULL,
                NULL,
                NULL,
                FALSE,
                NOW(),
                NOW()
              );

              INSERT INTO app.video_renditions (
                id,
                video_asset_id,
                rendition_key,
                kind,
                width,
                height,
                bitrate_kbps,
                fps,
                codec,
                storage_bucket,
                storage_path,
                public_url_hint,
                status,
                error,
                created_at
              ) VALUES (
                gen_random_uuid(),
                v_asset_id,
                'landing-media:' || '{object_name_sql}',
                'mp4',
                NULL,
                NULL,
                NULL,
                NULL,
                NULL,
                'landing-media',
                '{object_name_sql}',
                '{public_url_hint_sql}',
                'ready',
                NULL,
                NOW()
              );

              UPDATE app.landing_config
              SET video_asset_id = v_asset_id,
                  updated_at = NOW()
              WHERE id = '{config_id_sql}'::uuid;

              INSERT INTO app.video_asset_contexts (id, video_asset_id, context_type, context_id, role, created_at)
              VALUES (
                gen_random_uuid(),
                v_asset_id,
                'landing_config',
                '{config_id_sql}'::uuid,
                'hero',
                NOW()
              )
              ON CONFLICT (context_type, context_id, role) DO UPDATE
                SET video_asset_id = EXCLUDED.video_asset_id;
            END $$;
            """.strip(),
        )

        # Reload config to get the new video_asset_id
        cfg2 = admin_rows(
            m,
            f"""
            SELECT video_asset_id
            FROM app.landing_config
            WHERE id = '{esc_sql_literal(config_id)}'::uuid
            LIMIT 1
            """.strip(),
        )
        if cfg2 and cfg2[0].get("video_asset_id"):
            video_asset_id = str(cfg2[0]["video_asset_id"]).strip()

    if not video_asset_id:
        print("[ERROR] Unable to determine or create video_asset_id")
        print(json.dumps(payload, indent=2, ensure_ascii=False))
        return 1

    print("[INFO] landing hero video_asset_id:")
    print(video_asset_id)

    # Note: landing_config/context were updated either by resolver path (not used here) or by fallback.

    # Verify landing content now returns best_url
    verify = admin_rows(m, "SELECT public.app_public_landing_content() AS payload")
    payload2 = verify[0].get("payload") if verify else None
    best_url = None
    if isinstance(payload2, dict):
        cfg2 = payload2.get("config")
        if isinstance(cfg2, dict):
            pb = cfg2.get("playback")
            if isinstance(pb, dict):
                best_url = pb.get("best_url")

    print("[VERIFY] config.playback.best_url=")
    print(best_url)

    return 0


if __name__ == '__main__':
    raise SystemExit(main())

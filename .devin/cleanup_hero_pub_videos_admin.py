#!/usr/bin/env python3
from __future__ import annotations

import json
from typing import Any, Dict

import requests

from supabase_auto_manager import SupabaseAutoManager


def run_sql(m: SupabaseAutoManager, sql: str, timeout: int = 90) -> Dict[str, Any]:
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    resp = requests.post(url, headers=m.headers, json={"p_sql": sql}, timeout=timeout)
    try:
        data = resp.json()
    except Exception:
        return {"http": resp.status_code, "ok": False, "raw": (resp.text or "")[:2000]}

    if isinstance(data, dict):
        return {"http": resp.status_code, **data}

    if isinstance(data, list):
        return {"http": resp.status_code, "ok": True, "mode": "select", "rows": data}

    return {"http": resp.status_code, "ok": False, "error": "unexpected_json"}


def main() -> int:
    m = SupabaseAutoManager()

    # 1) Prévisualisation des items candidats
    preview_sql = """
    WITH hp AS (
      SELECT id, slot, media_type, base_image_url, base_video_url, is_active, sort_order, title
      FROM app.hero_playlist
      WHERE slot IN ('landing_hero_main', 'student_home_hero_main')
        AND media_type = 'video'
        AND is_active = FALSE
    ),
    hp_urls AS (
      SELECT
        id,
        slot,
        media_type,
        is_active,
        sort_order,
        title,
        base_image_url,
        base_video_url,
        COALESCE(NULLIF(base_video_url, ''), base_image_url) AS any_url
      FROM hp
    )
    SELECT
      id,
      slot,
      media_type,
      is_active,
      sort_order,
      title,
      base_video_url AS url
    FROM hp_urls
    WHERE any_url LIKE '%/hero-studio/%/videos/%'
      AND any_url LIKE '%.mp4%'
    ORDER BY slot, sort_order, id
    """.strip()

    preview = run_sql(m, preview_sql)
    print("=== PREVIEW_HERO_PUB_VIDEOS ===")
    print(json.dumps(preview, ensure_ascii=False, indent=2)[:4000])

    if not preview.get("ok"):
        return 1

    rows = preview.get("rows") or preview.get("data") or []
    if not rows:
        print("No legacy pub.mp4 hero items found for landing_hero_main / student_home_hero_main.")
        return 0

    # 2) Suppression en trois temps (objets Storage, renders, puis lignes hero_playlist)
    delete_storage_sql = """
    DELETE FROM storage.objects o
    WHERE o.bucket_id = 'landing-media'
      AND o.name IN (
        SELECT REGEXP_REPLACE(
                 SPLIT_PART(COALESCE(NULLIF(base_video_url, ''), base_image_url), '/object/public/', 2),
                 '^landing-media/',
                 ''
               ) AS object_name
        FROM app.hero_playlist
        WHERE slot IN ('landing_hero_main', 'student_home_hero_main')
          AND media_type = 'video'
          AND is_active = FALSE
          AND COALESCE(NULLIF(base_video_url, ''), base_image_url) LIKE '%/hero-studio/%/videos/%'
          AND COALESCE(NULLIF(base_video_url, ''), base_image_url) LIKE '%.mp4%'
      )
    """.strip()

    delete_renders_sql = """
    DELETE FROM app.hero_renders
    WHERE playlist_item_id IN (
      SELECT id
      FROM app.hero_playlist
      WHERE slot IN ('landing_hero_main', 'student_home_hero_main')
        AND media_type = 'video'
        AND is_active = FALSE
        AND COALESCE(NULLIF(base_video_url, ''), base_image_url) LIKE '%/hero-studio/%/videos/%'
        AND COALESCE(NULLIF(base_video_url, ''), base_image_url) LIKE '%.mp4%'
    )
    """.strip()

    delete_playlist_sql = """
    DELETE FROM app.hero_playlist
    WHERE slot IN ('landing_hero_main', 'student_home_hero_main')
      AND media_type = 'video'
      AND is_active = FALSE
      AND COALESCE(NULLIF(base_video_url, ''), base_image_url) LIKE '%/hero-studio/%/videos/%'
      AND COALESCE(NULLIF(base_video_url, ''), base_image_url) LIKE '%.mp4%'
    """.strip()

    deleted_storage = run_sql(m, delete_storage_sql)
    deleted_renders = run_sql(m, delete_renders_sql)
    deleted_playlist = run_sql(m, delete_playlist_sql)

    print("=== DELETE_HERO_PUB_VIDEOS_STORAGE ===")
    print(json.dumps(deleted_storage, ensure_ascii=False, indent=2)[:2000])
    print("=== DELETE_HERO_PUB_VIDEOS_RENDERS ===")
    print(json.dumps(deleted_renders, ensure_ascii=False, indent=2)[:2000])
    print("=== DELETE_HERO_PUB_VIDEOS_PLAYLIST ===")
    print(json.dumps(deleted_playlist, ensure_ascii=False, indent=2)[:2000])

    ok = deleted_storage.get("ok") and deleted_renders.get("ok") and deleted_playlist.get("ok")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())

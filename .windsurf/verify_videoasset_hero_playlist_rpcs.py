#!/usr/bin/env python3
from __future__ import annotations

import json
from typing import Any, Dict

import requests

from supabase_auto_manager import SupabaseAutoManager


def run_sql(m: SupabaseAutoManager, sql: str, timeout: int = 60) -> Dict[str, Any]:
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    resp = requests.post(url, headers=m.headers, json={"p_sql": sql}, timeout=timeout)
    try:
        data = resp.json()
    except Exception:
        return {"http": resp.status_code, "ok": False, "raw": (resp.text or '')[:2000]}

    if isinstance(data, dict):
        # admin_execute_sql convention: top-level dict avec ok/error
        return {"http": resp.status_code, **data}

    if isinstance(data, list):
        # Mode SELECT: rows brutes
        return {"http": resp.status_code, "ok": True, "mode": "select", "rows": data}

    return {"http": resp.status_code, "ok": False, "error": "unexpected_json"}


def main() -> int:
    m = SupabaseAutoManager()

    checks: Dict[str, str] = {
        # Existence des RPC Hero playlist VideoAsset-only
        "routines_hero_playlist": """
            SELECT routine_schema, routine_name
            FROM information_schema.routines
            WHERE routine_schema = 'public'
              AND routine_name IN (
                'app_public_hero_playlist',
                'app_admin_get_hero_playlist',
                'app_admin_get_hero_playlist_item_config',
                'app_admin_upsert_hero_playlist_item'
              )
            ORDER BY routine_name
        """.strip(),
        # Colonnes attendues sur app.hero_playlist (video_asset_id présent, colonnes TV présentes)
        "columns_hero_playlist": """
            SELECT table_name, column_name
            FROM information_schema.columns
            WHERE table_schema = 'app'
              AND table_name = 'hero_playlist'
              AND column_name IN (
                'slot', 'media_type', 'base_video_url', 'base_image_url',
                'video_asset_id', 'tv_timeline_duration_seconds', 'tv_timeline_version'
              )
            ORDER BY table_name, column_name
        """.strip(),
        # RPC public pour deux slots clés (même si items = [])
        "rpc_public_hero_playlist_landing": """
            SELECT app_public_hero_playlist('landing_hero_main'::text) AS payload
        """.strip(),
        "rpc_public_hero_playlist_student": """
            SELECT app_public_hero_playlist('student_home_hero_main'::text) AS payload
        """.strip(),
        # RPC admin de lecture: on attend une erreur métier not_authenticated mais aucune erreur SQL
        "rpc_admin_get_hero_playlist_invalid": """
            SELECT app_admin_get_hero_playlist('landing_hero_main'::text) AS payload
        """.strip(),
        # Config item avec un UUID aléatoire: compilation + gestion playlist_item_not_found
        "rpc_admin_get_hero_playlist_item_config_invalid": """
            SELECT app_admin_get_hero_playlist_item_config(gen_random_uuid()) AS payload
        """.strip(),
        # Upsert admin avec media_type='video' et video_asset_id NULL: test de compilation + sécurité
        "rpc_admin_upsert_hero_playlist_item_invalid": """
            SELECT app_admin_upsert_hero_playlist_item(
                NULL::uuid,
                'landing_hero_main'::text,
                'video'::text,
                NULL::uuid,
                '{"best_url": "https://example.com/video.mp4", "poster_url": "https://example.com/poster.jpg"}'::jsonb,
                'Hero test'::text,
                'Subtitle'::text,
                1::integer,
                TRUE::boolean
            ) AS payload
        """.strip(),
        # Feed unifié doit rester fonctionnel
        "feed_unified": """
            SELECT app_student_unified_video_feed(NULL::timestamptz, 5) AS payload
        """.strip(),
    }

    out: Dict[str, Any] = {}
    for label, sql in checks.items():
        out[label] = run_sql(m, sql)

    print(json.dumps(out, ensure_ascii=False, indent=2)[:6000])

    ok = True
    for label in checks.keys():
        if not out.get(label, {}).get("ok"):
            ok = False

    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())

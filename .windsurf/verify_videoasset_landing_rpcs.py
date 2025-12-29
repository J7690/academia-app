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
        # admin_execute_sql convention: top-level dict with ok/error fields
        return {"http": resp.status_code, **data}

    if isinstance(data, list):
        # SELECT mode: raw rows
        return {"http": resp.status_code, "ok": True, "mode": "select", "rows": data}

    return {"http": resp.status_code, "ok": False, "error": "unexpected_json"}


def main() -> int:
    m = SupabaseAutoManager()

    checks = {
        # Existence des RPC Landing VideoAsset-only
        "routines_landing": """
            SELECT routine_schema, routine_name
            FROM information_schema.routines
            WHERE routine_schema = 'public'
              AND routine_name IN (
                'app_admin_upsert_landing_config',
                'app_admin_upsert_landing_video',
                'app_public_landing_content',
                'app_admin_get_landing_content'
              )
            ORDER BY routine_name
        """.strip(),
        # Colonnes attendues sur landing_config / landing_videos
        "columns_landing": """
            SELECT table_name, column_name
            FROM information_schema.columns
            WHERE table_schema = 'app'
              AND table_name IN ('landing_config', 'landing_videos')
              AND column_name IN ('video_asset_id', 'video_url')
            ORDER BY table_name, column_name
        """.strip(),
        # Appels directs des RPC (sans auth, on s'attend à not_authenticated pour les admin)
        "rpc_public_landing_content": """
            SELECT app_public_landing_content() AS payload
        """.strip(),
        "rpc_admin_get_landing_content": """
            SELECT app_admin_get_landing_content() AS payload
        """.strip(),
        "rpc_admin_upsert_landing_config_invalid": """
            SELECT app_admin_upsert_landing_config(
                NULL::uuid,
                'Badge test'::text,
                'Titre test'::text,
                'Sous-titre test'::text,
                NULL::uuid,
                '{"best_url": "https://example.com/video.mp4", "poster_url": "https://example.com/poster.jpg"}'::jsonb,
                '#000000'::text,
                '#ffffff'::text,
                '#ff0000'::text
            ) AS payload
        """.strip(),
        "rpc_admin_upsert_landing_video_invalid": """
            SELECT app_admin_upsert_landing_video(
                NULL::uuid,
                NULL::uuid,
                '{"best_url": "https://example.com/video.mp4", "poster_url": "https://example.com/poster.jpg"}'::jsonb,
                'Video test'::text,
                1::integer,
                TRUE::boolean,
                'video'::text
            ) AS payload
        """.strip(),
        # Feed unifié : doit répondre sans erreur (même si videos = [])
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

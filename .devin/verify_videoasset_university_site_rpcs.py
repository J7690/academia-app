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
        # Existence des RPC mini-site université (VideoAsset-only pour les médias vidéo)
        "routines_university_site": """
            SELECT routine_schema, routine_name
            FROM information_schema.routines
            WHERE routine_schema = 'public'
              AND routine_name IN (
                'app_public_university_site',
                'app_admin_get_university_site',
                'app_list_university_site_for_management',
                'app_upsert_university_media',
                'app_admin_upsert_university_media'
              )
            ORDER BY routine_name
        """.strip(),
        # Colonnes attendues sur app.university_media (video_asset_id présent, thumbnail_url supprimé)
        "columns_university_media": """
            SELECT table_name, column_name
            FROM information_schema.columns
            WHERE table_schema = 'app'
              AND table_name = 'university_media'
              AND column_name IN ('video_asset_id', 'thumbnail_url')
            ORDER BY table_name, column_name
        """.strip(),
        # Appel public du mini-site université (slug de référence, aucun prérequis d'auth)
        "rpc_public_university_site": """
            SELECT app_public_university_site('universite-arbilo'::text) AS payload
        """.strip(),
        # Appel admin de lecture avec p_university_id NULL (on s'attend à une erreur métier, pas à une erreur SQL)
        "rpc_admin_get_university_site_invalid": """
            SELECT app_admin_get_university_site(NULL::uuid) AS payload
        """.strip(),
        # Upsert côté université avec media_type='video' et video_asset_id NULL (on teste la compilation + gestion d'erreur)
        "rpc_university_upsert_media_invalid": """
            SELECT app_upsert_university_media(
                NULL::uuid,
                'video'::text,
                'Video university test'::text,
                'Desc test'::text,
                'https://thevdfcwlcqzdoybfvgs.supabase.co/storage/v1/object/public/university-media/test.mp4'::text,
                'university-media/test.mp4'::text,
                1::integer,
                TRUE::boolean,
                NULL::uuid,
                '{"best_url": "https://example.com/video.mp4", "poster_url": "https://example.com/poster.jpg"}'::jsonb
            ) AS payload
        """.strip(),
        # Upsert côté admin avec media_type='video' et video_asset_id NULL (idem)
        "rpc_admin_upsert_university_media_invalid": """
            SELECT app_admin_upsert_university_media(
                NULL::uuid,
                NULL::uuid,
                'video'::text,
                'Video admin test'::text,
                'Desc admin'::text,
                'https://thevdfcwlcqzdoybfvgs.supabase.co/storage/v1/object/public/university-media/test-admin.mp4'::text,
                'university-media/test-admin.mp4'::text,
                1::integer,
                TRUE::boolean,
                NULL::uuid,
                '{"best_url": "https://example.com/video.mp4", "poster_url": "https://example.com/poster.jpg"}'::jsonb
            ) AS payload
        """.strip(),
        # Feed unifié: doit rester fonctionnel
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

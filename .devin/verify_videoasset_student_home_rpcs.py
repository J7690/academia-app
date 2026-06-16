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

    checks = {
        # Existence des RPC Student Home VideoAsset-only
        "routines_student_home": """
            SELECT routine_schema, routine_name
            FROM information_schema.routines
            WHERE routine_schema = 'public'
              AND routine_name IN (
                'app_public_student_home_content',
                'app_admin_get_student_home_content',
                'app_admin_upsert_student_home_video',
                'app_admin_delete_student_home_video'
              )
            ORDER BY routine_name
        """.strip(),
        # Colonnes attendues sur student_home_videos
        "columns_student_home": """
            SELECT table_name, column_name
            FROM information_schema.columns
            WHERE table_schema = 'app'
              AND table_name = 'student_home_videos'
              AND column_name IN ('video_asset_id')
            ORDER BY table_name, column_name
        """.strip(),
        # Appel public: contenu accueil étudiant
        "rpc_public_student_home_content": """
            SELECT app_public_student_home_content() AS payload
        """.strip(),
        # Appel admin (sans auth effective, attendu: not_authenticated mais pas d'erreur SQL)
        "rpc_admin_get_student_home_content": """
            SELECT app_admin_get_student_home_content() AS payload
        """.strip(),
        # Upsert vidéo avec video_asset_id NULL -> erreur métier mais pas d'erreur SQL
        "rpc_admin_upsert_student_home_video_invalid": """
            SELECT app_admin_upsert_student_home_video(
                NULL::uuid,
                NULL::uuid,
                '{"best_url": "https://example.com/video.mp4", "poster_url": "https://example.com/poster.jpg"}'::jsonb,
                'Video Student Home test'::text,
                1::integer,
                TRUE::boolean,
                'video'::text
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

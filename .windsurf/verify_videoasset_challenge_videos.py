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
        return {"http": resp.status_code, **data}

    if isinstance(data, list):
        return {"http": resp.status_code, "ok": True, "mode": "select", "rows": data}

    return {"http": resp.status_code, "ok": False, "error": "unexpected_json"}


def main() -> int:
    m = SupabaseAutoManager()

    checks = {
        # Existence des RPC challenge en VideoAsset-only
        "rpcs_challenge": """
            SELECT routine_name, data_type
            FROM information_schema.routines
            WHERE routine_schema = 'public'
              AND routine_name IN (
                'app_student_add_challenge_video',
                'app_student_list_my_challenge_videos',
                'app_student_set_challenge_main_video'
              )
            ORDER BY routine_name
        """.strip(),
        # Colonnes video_asset_id sur les tables clés
        "columns_video_asset": """
            SELECT table_name, column_name
            FROM information_schema.columns
            WHERE table_schema = 'app'
              AND table_name IN ('challenge_participations', 'challenge_participation_videos')
              AND column_name = 'video_asset_id'
            ORDER BY table_name
        """.strip(),
        # Appels RPC (sans auth, on s'attend à not_authenticated mais pas à des erreurs SQL)
        "rpc_call_add_challenge_invalid": """
            SELECT app_student_add_challenge_video(
                gen_random_uuid(),
                NULL::uuid,
                '{"best_url": "https://example.com/video.mp4", "poster_url": "https://example.com/poster.jpg"}'::jsonb
            ) AS payload
        """.strip(),
        "rpc_call_list_my_videos": """
            SELECT app_student_list_my_challenge_videos(gen_random_uuid()) AS payload
        """.strip(),
        "rpc_call_set_main_invalid": """
            SELECT app_student_set_challenge_main_video(
                gen_random_uuid(),
                NULL::uuid,
                '{"best_url": "https://example.com/video.mp4", "poster_url": "https://example.com/poster.jpg"}'::jsonb
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

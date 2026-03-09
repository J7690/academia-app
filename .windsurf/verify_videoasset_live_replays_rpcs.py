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
        # Existence des RPC live sessions / replays (VideoAsset-only pour le replay)
        "routines_live_replays": """
            SELECT routine_schema, routine_name
            FROM information_schema.routines
            WHERE routine_schema = 'public'
              AND routine_name IN (
                'app_ci_upsert_online_course_live_session',
                'app_admin_list_online_course_live_sessions',
                'app_student_list_my_online_course_live_sessions',
                'app_ci_list_my_online_course_live_sessions'
              )
            ORDER BY routine_name
        """.strip(),
        # Colonnes attendues sur app.online_course_live_sessions (replay_video_asset_id présent, replay_video_url conservé)
        "columns_online_course_live_sessions": """
            SELECT table_name, column_name
            FROM information_schema.columns
            WHERE table_schema = 'app'
              AND table_name = 'online_course_live_sessions'
              AND column_name IN ('replay_video_url', 'replay_video_asset_id')
            ORDER BY table_name, column_name
        """.strip(),
        # RPC admin de liste: on attend une erreur métier not_authenticated mais aucune erreur SQL
        "rpc_admin_list_live_sessions_invalid": """
            SELECT app_admin_list_online_course_live_sessions(
              NULL::text,
              NULL::uuid,
              NULL::uuid
            ) AS payload
        """.strip(),
        # RPC étudiant: même principe, on teste la compilation et la surface JSON
        "rpc_student_list_live_sessions_invalid": """
            SELECT app_student_list_my_online_course_live_sessions() AS payload
        """.strip(),
        # RPC instructeur: idem
        "rpc_ci_list_live_sessions_invalid": """
            SELECT app_ci_list_my_online_course_live_sessions() AS payload
        """.strip(),
        # RPC CI upsert (VideoAsset-only pour le replay) : test de compilation + sécurisation auth
        "rpc_ci_upsert_live_session_invalid": """
            SELECT app_ci_upsert_online_course_live_session(
                NULL::uuid,
                gen_random_uuid()::uuid,
                NULL::uuid,
                'Test live VideoAsset'::text,
                'Desc test'::text,
                'zoom'::text,
                'https://example.com/meet'::text,
                NOW() + interval '1 day',
                NOW() + interval '1 day' + interval '1 hour',
                NULL::uuid,
                '{"best_url": "https://example.com/replay.m3u8", "poster_url": "https://example.com/replay.jpg"}'::jsonb,
                TRUE::boolean
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

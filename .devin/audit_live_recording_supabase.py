#!/usr/bin/env python3
"""Audit Supabase (L6): colonnes replay + préparation enregistrement (egress_id).

Utilise la RPC public.admin_execute_sql(p_sql) qui renvoie { ok, mode, rows } pour les SELECT.
"""

from __future__ import annotations

import json
from pathlib import Path
import requests

from supabase_auto_manager import SupabaseAutoManager


def run_sql(m: SupabaseAutoManager, sql: str, timeout: int = 60):
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    r = requests.post(url, headers=m.headers, json={"p_sql": sql.strip()}, timeout=timeout)
    try:
        return r.json()
    except Exception:
        return {"ok": False, "error": r.text, "http": r.status_code}


def main() -> int:
    m = SupabaseAutoManager()
    out = {}

    queries = {
        "cols_prep_live_sessions": """
            SELECT column_name, data_type, is_nullable, column_default
            FROM information_schema.columns
            WHERE table_schema='app' AND table_name='prep_live_sessions'
            ORDER BY ordinal_position
        """,
        "cols_online_course_live_sessions": """
            SELECT column_name, data_type, is_nullable, column_default
            FROM information_schema.columns
            WHERE table_schema='app' AND table_name='online_course_live_sessions'
            ORDER BY ordinal_position
        """,
        "rpcs_replay": """
            SELECT routine_name
            FROM information_schema.routines
            WHERE routine_schema='public'
              AND (routine_name ILIKE '%replay%' OR routine_name ILIKE '%live_session%')
            ORDER BY routine_name
        """,
        "sample_online_course_live_sessions": """
            SELECT id, title, status, provider, join_url,
                   replay_video_url,
                   start_at, end_at
            FROM app.online_course_live_sessions
            ORDER BY created_at DESC
            LIMIT 5
        """,
        "sample_prep_live_sessions": """
            SELECT id, title, status, provider, join_url,
                   replay_url,
                   start_at, end_at
            FROM app.prep_live_sessions
            ORDER BY created_at DESC
            LIMIT 5
        """,
    }

    for k, q in queries.items():
        print(f"\n=== {k} ===")
        res = run_sql(m, q)
        print(json.dumps(res, indent=2, ensure_ascii=False, default=str)[:4000])
        out[k] = res

    log_dir = Path(__file__).parent / "logs"
    log_dir.mkdir(parents=True, exist_ok=True)
    out_path = log_dir / "audit_live_recording_supabase.json"
    out_path.write_text(json.dumps(out, indent=2, ensure_ascii=False, default=str), encoding="utf-8")
    print(f"\nSaved: {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

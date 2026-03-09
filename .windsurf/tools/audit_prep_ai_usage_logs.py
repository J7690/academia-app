#!/usr/bin/env python3
"""Audit Phase 7: logs + rate-limit pour l'IA Prépa Concours.

Respecte le cahier des charges .windsurf:
- Lecture via RPC execute_sql.
- Pas de dashboard.

Ce script:
- Affiche les derniers événements de app.prep_ai_usage_logs
- Agrège par status (24h)
- Montre l'état du rate-limit pour un user student actif (simulation auth.uid)
"""

from __future__ import annotations

import sys
from pathlib import Path
import json
import requests

WINDSURF_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(WINDSURF_DIR))

from supabase_auto_manager import SupabaseAutoManager


def call_execute_sql(m: SupabaseAutoManager, sql: str):
    url = f"{m.url}/rest/v1/rpc/execute_sql"
    r = requests.post(url, headers=m.headers, json={"sql_query": sql}, timeout=30)
    try:
        data = r.json()
    except Exception:
        data = r.text
    return r.status_code, data


def sql_set_claims_and_select(user_id: str, select_sql: str) -> str:
    claims = json.dumps({"sub": user_id, "role": "authenticated"})
    escaped = claims.replace("'", "''")
    return (
        "SELECT set_config('request.jwt.claims', '" + escaped + "', true) AS _claims, "
        + "(" + select_sql + ") AS result"
    )


def _normalize_rows(raw: object) -> list:
    if raw is None:
        return []
    if isinstance(raw, list):
        return raw
    return [raw]


def main() -> int:
    m = SupabaseAutoManager()

    # 1) pick an active student
    sql_students = (
        "SELECT id, email, COALESCE(last_sign_in_at, created_at) AS activity_ts "
        "FROM auth.users "
        "WHERE raw_user_meta_data->>'role' = 'student' "
        "ORDER BY COALESCE(last_sign_in_at, created_at) DESC "
        "LIMIT 5"
    )
    st, students = call_execute_sql(m, sql_students)
    print("\n=== active students ===")
    print("HTTP", st)
    print(json.dumps(students, indent=2, ensure_ascii=False)[:4000])

    if not isinstance(students, list) or not students:
        raise SystemExit("No student users found.")

    user_id = str(students[0].get("id") or "").strip()
    email = str(students[0].get("email") or "").strip()

    # 2) last logs
    sql_last = (
        "SELECT id, created_at, user_id, generation_id, subject_id, endpoint, status, duration_ms, input_hash "
        "FROM app.prep_ai_usage_logs "
        "ORDER BY created_at DESC "
        "LIMIT 50"
    )
    st2, logs = call_execute_sql(m, sql_last)
    print("\n=== prep_ai_usage_logs (last 50) ===")
    print("HTTP", st2)
    print(json.dumps(_normalize_rows(logs), indent=2, ensure_ascii=False)[:8000])

    # 3) aggregate 24h
    sql_agg = (
        "SELECT status, COUNT(*)::int AS cnt "
        "FROM app.prep_ai_usage_logs "
        "WHERE created_at > NOW() - interval '24 hours' "
        "GROUP BY status "
        "ORDER BY cnt DESC, status ASC"
    )
    st3, agg = call_execute_sql(m, sql_agg)
    print("\n=== prep_ai_usage_logs (status agg 24h) ===")
    print("HTTP", st3)
    print(json.dumps(_normalize_rows(agg), indent=2, ensure_ascii=False)[:4000])

    # 3b) Insert a test log (so we can validate the pipeline even if no AI call happened yet)
    test_insert = sql_set_claims_and_select(
        user_id,
        "app_prep_ai_log_usage(NULL, NULL, NULL, 'ai/prep/generate', 'test_log', 0, '{\"source\":\"audit_script\"}'::jsonb)",
    )
    st_ins, ins = call_execute_sql(m, test_insert)
    print("\n=== insert test log (simulated user) ===")
    print("HTTP", st_ins)
    print(json.dumps(_normalize_rows(ins), indent=2, ensure_ascii=False)[:2000])

    # 3c) Re-read logs and aggregate after insert
    st2b, logs2 = call_execute_sql(m, sql_last)
    print("\n=== prep_ai_usage_logs (last 50) AFTER test insert ===")
    print("HTTP", st2b)
    print(json.dumps(_normalize_rows(logs2), indent=2, ensure_ascii=False)[:8000])

    st3b, agg2 = call_execute_sql(m, sql_agg)
    print("\n=== prep_ai_usage_logs (status agg 24h) AFTER test insert ===")
    print("HTTP", st3b)
    print(json.dumps(_normalize_rows(agg2), indent=2, ensure_ascii=False)[:4000])

    # 4) rate limit check (simulate uid)
    rl_select = "app_prep_ai_check_rate_limit('ai/prep/generate', 3600, 20)"
    sql_rl = sql_set_claims_and_select(user_id, rl_select)
    st4, rl = call_execute_sql(m, sql_rl)
    print("\n=== rate limit check (simulated) ===")
    print("user", email, user_id)
    print("HTTP", st4)
    print(json.dumps(rl, indent=2, ensure_ascii=False)[:4000])

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

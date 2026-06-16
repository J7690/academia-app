#!/usr/bin/env python3
"""Vérifie le paywall "prep_concours" côté DB.

- Utilise RPC execute_sql (lecture) uniquement.
- Vérifie:
  1) Le user student le plus actif a accès (app_has_feature_access = true).
  2) Un autre student actif (2e) n'a pas accès (app_has_feature_access = false) car entitlement révoqué.
  3) Les policies RLS des tables prep_* ont bien été remplacées.

Notes:
- Pour tester app_has_feature_access() avec un user donné, on simule auth.uid() via:
  set_config('request.jwt.claim.sub', '<uuid>', true)
  dans un CTE.
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


def call_admin_execute_sql(m: SupabaseAutoManager, sql: str):
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    r = requests.post(url, headers=m.headers, json={"p_sql": sql}, timeout=30)
    try:
        data = r.json()
    except Exception:
        data = r.text
    return r.status_code, data


def main() -> int:
    m = SupabaseAutoManager()

    # 1) get active students
    sql_students = (
        "SELECT id, email, COALESCE(last_sign_in_at, created_at) AS activity_ts "
        "FROM auth.users "
        "WHERE raw_user_meta_data->>'role' = 'student' "
        "ORDER BY COALESCE(last_sign_in_at, created_at) DESC "
        "LIMIT 10"
    )
    st, users = call_execute_sql(m, sql_students)
    print("\n=== active students ===")
    print("HTTP", st)
    print(json.dumps(users, indent=2, ensure_ascii=False)[:4000])

    if not isinstance(users, list) or len(users) < 2:
        raise SystemExit("Need at least 2 student users for the check.")

    u1 = users[0]
    u2 = users[1]
    u1_id = str(u1.get("id") or "").strip()
    u2_id = str(u2.get("id") or "").strip()

    # 2) ensure only u1 has active entitlement (revoke others)
    sql_revoke_others = (
        "UPDATE app.user_feature_entitlements "
        "SET is_active = FALSE "
        "WHERE feature_key = 'prep_concours' "
        f"AND user_id <> '{u1_id}'::uuid"
    )
    st2, revoked = call_admin_execute_sql(m, sql_revoke_others)
    print("\n=== revoke others ===")
    print("HTTP", st2)
    print(json.dumps(revoked, indent=2, ensure_ascii=False)[:2000])

    # 3) check access for u1 and u2
    def sql_check_access(user_id: str) -> str:
        # auth.uid() se base sur request.jwt.claims->>'sub'
        # On simule un JWT minimal: {sub: <uuid>, role: authenticated}
        claims = json.dumps({"sub": user_id, "role": "authenticated"})
        return (
            "SELECT set_config('request.jwt.claims', "
            + "'" + claims.replace("'", "''") + "'"
            + ", true) AS _set_claims, "
            + "app_has_feature_access('prep_concours') AS allowed"
        )

    st3, a1 = call_execute_sql(m, sql_check_access(u1_id))
    st4, a2 = call_execute_sql(m, sql_check_access(u2_id))
    print("\n=== access check u1 ===")
    print("u1", u1.get("email"), u1_id)
    print("HTTP", st3)
    print(json.dumps(a1, indent=2, ensure_ascii=False)[:1000])

    print("\n=== access check u2 ===")
    print("u2", u2.get("email"), u2_id)
    print("HTTP", st4)
    print(json.dumps(a2, indent=2, ensure_ascii=False)[:1000])

    # 4) check policies for prep_* tables
    sql_policies = (
        "SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual "
        "FROM pg_policies "
        "WHERE schemaname = 'app' "
        "  AND tablename LIKE 'prep_%' "
        "ORDER BY tablename, policyname"
    )
    st5, pol = call_execute_sql(m, sql_policies)
    print("\n=== pg_policies app.prep_* ===")
    print("HTTP", st5)
    print(json.dumps(pol, indent=2, ensure_ascii=False)[:6000])

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Attribue l'entitlement 'prep_concours' à un user student (MVP paywall).

- Utilise exclusivement la RPC admin_execute_sql (service_role) déjà en place.
- Sélectionne automatiquement le dernier utilisateur avec metadata role='student'.
- Upsert dans app.user_feature_entitlements.
"""

from __future__ import annotations

import sys
from pathlib import Path
import json
import requests

WINDSURF_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(WINDSURF_DIR))

from supabase_auto_manager import SupabaseAutoManager


def admin_execute_sql(m: SupabaseAutoManager, sql: str) -> dict:
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    r = requests.post(url, headers=m.headers, json={"p_sql": sql}, timeout=30)
    try:
        data = r.json()
    except Exception:
        data = {"raw": r.text}
    return {"status": r.status_code, "data": data}


def execute_sql(m: SupabaseAutoManager, sql: str) -> dict:
    url = f"{m.url}/rest/v1/rpc/execute_sql"
    r = requests.post(url, headers=m.headers, json={"sql_query": sql}, timeout=30)
    try:
        data = r.json()
    except Exception:
        data = {"raw": r.text}
    return {"status": r.status_code, "data": data}


def main() -> int:
    m = SupabaseAutoManager()

    sel = (
        "SELECT id, email, raw_user_meta_data->>'role' AS role "
        "FROM auth.users "
        "ORDER BY created_at DESC "
        "LIMIT 25"
    )

    res = execute_sql(m, sel)
    print("\n=== select students ===")
    print("HTTP", res["status"])
    print(json.dumps(res["data"], indent=2, ensure_ascii=False)[:4000])

    rows = res["data"] if isinstance(res["data"], list) else None
    if not isinstance(rows, list) or not rows:
        raise SystemExit("No users returned from execute_sql.")

    user_id = ""
    for row in rows:
        if not isinstance(row, dict):
            continue
        role = str(row.get("role") or "").strip().lower()
        if role == "student":
            user_id = str(row.get("id") or "").strip()
            break

    if not user_id:
        raise SystemExit("No recent user with role=student found in auth.users.")

    upsert = (
        "INSERT INTO app.user_feature_entitlements(user_id, feature_key, granted_by, expires_at, is_active, granted_at) "
        f"VALUES ('{user_id}'::uuid, 'prep_concours', NULL, NULL, TRUE, NOW()) "
        "ON CONFLICT (user_id, feature_key) DO UPDATE "
        "SET is_active = TRUE, expires_at = NULL, granted_at = NOW()"
    )
    res2 = admin_execute_sql(m, upsert)
    print("\n=== upsert entitlement ===")
    print("chosen_user_id", user_id)
    print("HTTP", res2["status"])
    print(json.dumps(res2["data"], indent=2, ensure_ascii=False)[:2000])

    verify = (
        "SELECT user_id, feature_key, is_active, expires_at, granted_at "
        "FROM app.user_feature_entitlements "
        f"WHERE user_id = '{user_id}'::uuid AND feature_key = 'prep_concours'"
    )
    res3 = execute_sql(m, verify)
    print("\n=== verify entitlement ===")
    print("HTTP", res3["status"])
    print(json.dumps(res3["data"], indent=2, ensure_ascii=False)[:4000])

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

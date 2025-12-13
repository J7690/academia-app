#!/usr/bin/env python3
"""Audit auth.users et attribue l'entitlement prep_concours à un compte student réellement actif.

But:
- Éviter de choisir un compte "fantôme" jamais utilisé.
- Utiliser uniquement les RPC .windsurf:
  - execute_sql (pour lire des rows)
  - admin_execute_sql (pour écrire/mettre à jour)

Stratégie de sélection:
1) Récupère les 50 derniers users role=student avec email + confirmed_at + last_sign_in_at.
2) Choisit en priorité un user avec last_sign_in_at non null (le plus récent).
3) Sinon, choisit un user avec confirmed_at non null (le plus récent).
4) Sinon, prend le plus récent.

Ensuite:
- Révoque (is_active=false) tous les entitlements prep_concours existants.
- Upsert l'entitlement prep_concours sur le user choisi.
- Vérifie la ligne.

Note: admin_execute_sql ne renvoie pas les rows, donc les SELECT passent par execute_sql.
"""

from __future__ import annotations

import sys
from pathlib import Path
import json
import requests

WINDSURF_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(WINDSURF_DIR))

from supabase_auto_manager import SupabaseAutoManager


def call_rpc(m: SupabaseAutoManager, rpc: str, payload: dict) -> tuple[int, object]:
    url = f"{m.url}/rest/v1/rpc/{rpc}"
    r = requests.post(url, headers=m.headers, json=payload, timeout=30)
    try:
        data = r.json()
    except Exception:
        data = r.text
    return r.status_code, data


def main() -> int:
    m = SupabaseAutoManager()

    sql_students = (
        "SELECT id, email, created_at, confirmed_at, last_sign_in_at, raw_user_meta_data->>'role' AS role "
        "FROM auth.users "
        "WHERE raw_user_meta_data->>'role' = 'student' "
        "ORDER BY COALESCE(last_sign_in_at, created_at) DESC "
        "LIMIT 50"
    )

    st, data = call_rpc(m, "execute_sql", {"sql_query": sql_students})
    print("\n=== students (top 50) ===")
    print("HTTP", st)
    print(json.dumps(data, indent=2, ensure_ascii=False)[:6000])

    if not isinstance(data, list) or not data:
        raise SystemExit("No student users returned from execute_sql.")

    def is_nonempty(v: object) -> bool:
        return v is not None and str(v).strip() != "" and str(v).strip().lower() != "null"

    chosen = None
    for row in data:
        if not isinstance(row, dict):
            continue
        if is_nonempty(row.get("last_sign_in_at")):
            chosen = row
            break

    if chosen is None:
        for row in data:
            if not isinstance(row, dict):
                continue
            if is_nonempty(row.get("confirmed_at")):
                chosen = row
                break

    if chosen is None:
        chosen = data[0] if isinstance(data[0], dict) else None

    if not isinstance(chosen, dict):
        raise SystemExit("Could not select a student row.")

    user_id = str(chosen.get("id") or "").strip()
    email = str(chosen.get("email") or "").strip()

    if not user_id:
        raise SystemExit("Selected row has no id.")

    print("\n=== chosen student ===")
    print(json.dumps(chosen, indent=2, ensure_ascii=False))

    # 1) Revoke all existing entitlements for prep_concours
    revoke_sql = (
        "UPDATE app.user_feature_entitlements "
        "SET is_active = FALSE "
        "WHERE feature_key = 'prep_concours'"
    )
    st2, data2 = call_rpc(m, "admin_execute_sql", {"p_sql": revoke_sql})
    print("\n=== revoke existing entitlements ===")
    print("HTTP", st2)
    print(json.dumps(data2, indent=2, ensure_ascii=False)[:2000])

    # 2) Upsert entitlement for chosen user
    upsert_sql = (
        "INSERT INTO app.user_feature_entitlements(user_id, feature_key, granted_by, expires_at, is_active, granted_at) "
        f"VALUES ('{user_id}'::uuid, 'prep_concours', NULL, NULL, TRUE, NOW()) "
        "ON CONFLICT (user_id, feature_key) DO UPDATE "
        "SET is_active = TRUE, expires_at = NULL, granted_at = NOW()"
    )
    st3, data3 = call_rpc(m, "admin_execute_sql", {"p_sql": upsert_sql})
    print("\n=== grant entitlement ===")
    print("target_user_id", user_id)
    print("target_email", email)
    print("HTTP", st3)
    print(json.dumps(data3, indent=2, ensure_ascii=False)[:2000])

    # 3) Verify
    verify_sql = (
        "SELECT user_id, feature_key, is_active, expires_at, granted_at "
        "FROM app.user_feature_entitlements "
        f"WHERE user_id = '{user_id}'::uuid AND feature_key = 'prep_concours'"
    )
    st4, data4 = call_rpc(m, "execute_sql", {"sql_query": verify_sql})
    print("\n=== verify entitlement ===")
    print("HTTP", st4)
    print(json.dumps(data4, indent=2, ensure_ascii=False)[:4000])

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

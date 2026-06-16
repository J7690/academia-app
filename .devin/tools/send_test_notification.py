#!/usr/bin/env python3
"""Envoie un événement de notification de test pour un étudiant actif.

Étapes:
- Sélectionne un student récent dans auth.users (via execute_sql).
- Affiche ses éventuels tokens dans app.user_device_tokens.
- Insère un event dans app.notification_events pour ce user via admin_execute_sql.
- Relit les derniers events pour ce user.

Objectif: valider de bout en bout la chaîne notifications -> edge function FCM.
"""

from __future__ import annotations

import json
from pathlib import Path
import sys

import requests

WINDSURF_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(WINDSURF_DIR))

from supabase_auto_manager import SupabaseAutoManager


def call_execute_sql(m: SupabaseAutoManager, sql: str) -> tuple[int, object]:
    url = f"{m.url}/rest/v1/rpc/execute_sql"
    r = requests.post(url, headers=m.headers, json={"sql_query": sql}, timeout=30)
    try:
        data = r.json()
    except Exception:
        data = r.text
    return r.status_code, data


def call_admin_execute_sql(m: SupabaseAutoManager, sql: str) -> tuple[int, object]:
    sql_clean = (sql or "").strip()
    if sql_clean.endswith(";"):
        sql_clean = sql_clean[:-1].rstrip()
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    r = requests.post(url, headers=m.headers, json={"p_sql": sql_clean}, timeout=60)
    try:
        data = r.json()
    except Exception:
        data = r.text
    return r.status_code, data


def _normalize_rows(raw: object) -> list:
    if raw is None:
        return []
    if isinstance(raw, list):
        return raw
    return [raw]


def main() -> int:
    m = SupabaseAutoManager()
    print("Supabase URL:", m.url)

    # 1) Choisir un étudiant actif
    sql_students = (
        "SELECT id, email, COALESCE(last_sign_in_at, created_at) AS activity_ts "
        "FROM auth.users "
        "WHERE raw_user_meta_data->>'role' = 'student' "
        "ORDER BY COALESCE(last_sign_in_at, created_at) DESC "
        "LIMIT 5"
    )
    st1, students = call_execute_sql(m, sql_students)
    print("\n=== active students (top 5) ===")
    print("HTTP", st1)
    print(json.dumps(_normalize_rows(students), indent=2, ensure_ascii=False)[:4000])

    if not isinstance(students, list) or not students:
        raise SystemExit("No student users found.")

    chosen = None
    for row in students:
        if isinstance(row, dict):
            chosen = row
            break

    if not isinstance(chosen, dict):
        raise SystemExit("Could not pick a student row.")

    user_id = str(chosen.get("id") or "").strip()
    email = str(chosen.get("email") or "").strip()
    print("\n=== chosen student ===")
    print(json.dumps(chosen, indent=2, ensure_ascii=False))

    if not user_id:
        raise SystemExit("Chosen student has no id.")

    # 2) Afficher ses tokens device (si la table existe et contient des lignes)
    sql_tokens = (
        "SELECT platform, fcm_token, is_active, last_seen_at, updated_at "
        "FROM app.user_device_tokens "
        f"WHERE user_id = '{user_id}'::uuid "
        "ORDER BY last_seen_at DESC "
        "LIMIT 20"
    )
    st2, tokens = call_execute_sql(m, sql_tokens)
    print("\n=== user_device_tokens for chosen student ===")
    print("HTTP", st2)
    print(json.dumps(_normalize_rows(tokens), indent=2, ensure_ascii=False)[:4000])

    # 3) Insérer un event dans app.notification_events pour ce user
    sql_insert = (
        "INSERT INTO app.notification_events (user_id, domain, event_type, payload) "
        "VALUES ("
        f"'{user_id}'::uuid, "
        "'student_bobodo', "
        "'message', "
        "jsonb_build_object('source', 'send_test_notification', 'note', 'test FCM pipeline', 'inserted_at', NOW())"
        ")"
    )
    st3, data3 = call_admin_execute_sql(m, sql_insert)
    print("\n=== insert notification_events row ===")
    print("HTTP", st3)
    print(json.dumps(data3, indent=2, ensure_ascii=False)[:2000])

    if st3 != 200:
        raise SystemExit("admin_execute_sql INSERT failed.")

    # 4) Relire les derniers events pour ce user
    sql_events = (
        "SELECT id, user_id, domain, event_type, created_at, processed_at, attempt_count, "
        "LEFT(last_error, 200) AS last_error "
        "FROM app.notification_events "
        f"WHERE user_id = '{user_id}'::uuid "
        "ORDER BY created_at DESC "
        "LIMIT 20"
    )
    st4, events = call_execute_sql(m, sql_events)
    print("\n=== notification_events for chosen student (last 20) ===")
    print("HTTP", st4)
    print(json.dumps(_normalize_rows(events), indent=2, ensure_ascii=False)[:8000])

    print("\n[OK] Test notification event inserted for:")
    print("user_id", user_id)
    print("email", email)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

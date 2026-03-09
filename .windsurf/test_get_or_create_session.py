#!/usr/bin/env python3
"""Tester la nouvelle RPC app_get_or_create_bobodo_session pour vérifier qu'elle réutilise bien une session existante."""

import json
import requests
from auto_supabase_import import SUPABASE_URL, SUPABASE_SERVICE_KEY

HEADERS = {
    "apikey": SUPABASE_SERVICE_KEY,
    "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
    "Content-Type": "application/json",
}

def run_sql(label: str, sql: str) -> None:
    url = f"{SUPABASE_URL}/rest/v1/rpc/admin_execute_sql"
    print(f"\n=== {label} ===")
    print(sql)
    try:
        resp = requests.post(url, headers=HEADERS, json={"p_sql": sql}, timeout=30)
    except Exception as exc:
        print("[ERROR] Exception réseau:", exc)
        return

    print("STATUS", resp.status_code)
    try:
        body = resp.json()
        print("BODY", json.dumps(body, ensure_ascii=False, indent=2)[:4000])
    except Exception:
        print("BODY_RAW", resp.text[:4000])

def main() -> int:
    # 1) Compter les sessions avant test
    run_sql(
        "Sessions avant test",
        """
SELECT COUNT(DISTINCT s.id) AS sessions_count
FROM app.bobodo_sessions s
WHERE s.student_id = '6745c7ad-732b-47d0-b5b8-06d6dcf286ff'
  AND s.created_at >= NOW() - INTERVAL '7 days'
        """.strip(),
    )

    # 2) Simuler un appel à app_get_or_create_bobodo_session en se faisant passer pour l'étudiant
    # (en vrai, il faudrait le JWT de l'étudiant, mais ici on vérifie juste que la RPC est fonctionnelle)
    run_sql(
        "Test RPC get_or_create (via admin)",
        """
SELECT app.app_get_or_create_bobodo_session('Test session RPC') AS session_id
        """.strip(),
    )

    # 3) Compter les sessions après test (ne devrait pas avoir augmenté si une session < 7j existait)
    run_sql(
        "Sessions après test",
        """
SELECT COUNT(DISTINCT s.id) AS sessions_count
FROM app.bobodo_sessions s
WHERE s.student_id = '6745c7ad-732b-47d0-b5b8-06d6dcf286ff'
  AND s.created_at >= NOW() - INTERVAL '7 days'
        """.strip(),
    )

    return 0

if __name__ == "__main__":
    raise SystemExit(main())

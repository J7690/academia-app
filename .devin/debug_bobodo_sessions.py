#!/usr/bin/env python3
"""Debug des sessions Bobodo : voir les sessions récentes et les messages pour comprendre pourquoi Bobodo se présente plusieurs fois."""

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
    # 1) Sessions Bobodo récentes avec nombre de messages et dates
    run_sql(
        "Sessions Bobodo récentes",
        """
SELECT
  s.id AS session_id,
  s.student_id,
  st.full_name,
  COUNT(m.id) AS messages_count,
  COUNT(m.id) FILTER (WHERE m.sender = 'assistant') AS assistant_messages,
  MIN(m.created_at) AS first_message_at,
  MAX(m.created_at) AS last_message_at,
  s.created_at AS session_created_at
FROM app.bobodo_sessions s
LEFT JOIN app.bobodo_messages m ON m.session_id = s.id
LEFT JOIN app.students st ON st.id = s.student_id
WHERE s.created_at >= NOW() - INTERVAL '2 days'
GROUP BY s.id, s.student_id, st.full_name
ORDER BY s.created_at DESC
LIMIT 10
        """.strip(),
    )

    # 2) Derniers messages de la session la plus récente
    run_sql(
        "Derniers messages de la session la plus récente",
        """
SELECT
  m.id,
  m.sender,
  LEFT(m.content, 120) AS content_preview,
  m.created_at
FROM app.bobodo_messages m
WHERE m.session_id = (
  SELECT s.id
  FROM app.bobodo_sessions s
  WHERE s.created_at >= NOW() - INTERVAL '2 days'
  ORDER BY s.created_at DESC
  LIMIT 1
)
ORDER BY m.created_at ASC
LIMIT 20
        """.strip(),
    )

    # 3) Vérifier si plusieurs sessions existent pour le même étudiant
    run_sql(
        "Sessions par étudiant (2 derniers jours)",
        """
SELECT
  s.student_id,
  st.full_name,
  COUNT(DISTINCT s.id) AS sessions_count,
  COUNT(m.id) AS total_messages,
  MAX(s.created_at) AS latest_session_at
FROM app.bobodo_sessions s
LEFT JOIN app.bobodo_messages m ON m.session_id = s.id
LEFT JOIN app.students st ON st.id = s.student_id
WHERE s.created_at >= NOW() - INTERVAL '2 days'
GROUP BY s.student_id, st.full_name
HAVING COUNT(DISTINCT s.id) > 1
ORDER BY sessions_count DESC, latest_session_at DESC
LIMIT 10
        """.strip(),
    )

    return 0

if __name__ == "__main__":
    raise SystemExit(main())

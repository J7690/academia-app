#!/usr/bin/env python3
"""Déployer manuellement l'Edge Function bobodo-chat via les RPC admin Supabase."""

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
    # Lire le code de l'Edge Function
    edge_function_path = "../supabase/functions/bobodo-chat/index.ts"
    try:
        with open(edge_function_path, "r", encoding="utf-8") as f:
            edge_function_code = f.read()
    except Exception as exc:
        print(f"[ERROR] Impossible de lire le fichier Edge Function: {exc}")
        return 1

    # Échapper le code pour SQL
    escaped_code = edge_function_code.replace("'", "''")

    # 1) Créer ou mettre à jour l'Edge Function dans la table functions
    create_function_sql = f"""
INSERT INTO supabase_functions.functions (name, body, verify_jwt, import_map)
VALUES (
  'bobodo-chat',
  '{escaped_code}',
  true,
  '{{}}'
)
ON CONFLICT (name) DO UPDATE SET
  body = EXCLUDED.body,
  verify_jwt = EXCLUDED.verify_jwt,
  import_map = EXCLUDED.import_map,
  updated_at = NOW();
    """.strip()

    run_sql("Créer/Mettre à jour l'Edge Function bobodo-chat", create_function_sql)

    # 2) Vérifier que la fonction est bien enregistrée
    verify_sql = """
SELECT name, created_at, updated_at
FROM supabase_functions.functions
WHERE name = 'bobodo-chat'
    """.strip()

    run_sql("Vérifier l'Edge Function", verify_sql)

    # 3) Activer la fonction (si nécessaire)
    activate_sql = """
UPDATE supabase_functions.functions
SET status = 'ACTIVE'
WHERE name = 'bobodo-chat'
    """.strip()

    run_sql("Activer l'Edge Function", activate_sql)

    return 0

if __name__ == "__main__":
    raise SystemExit(main())

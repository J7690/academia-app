#!/usr/bin/env python3
"""Déployer l'Edge Function admin-create-merchant-account via les RPC admin Supabase.

Cette approche suit le même modèle que deploy_bobodo_chat_edge_function.py :
- Lire le code TypeScript de la function dans supabase/functions/...
- L'enregistrer dans la table supabase_functions.functions via admin_execute_sql
- Forcer le status à ACTIVE

Pré-requis:
- auto_supabase_import.py doit fournir SUPABASE_URL et SUPABASE_SERVICE_KEY
- Le RPC admin_execute_sql doit être disponible
"""

import json
import sys

import requests

from auto_supabase_import import SUPABASE_URL, SUPABASE_SERVICE_KEY


HEADERS = {
    "apikey": SUPABASE_SERVICE_KEY,
    "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
    "Content-Type": "application/json",
}


def run_sql(label: str, sql: str) -> bool:
    url = f"{SUPABASE_URL}/rest/v1/rpc/admin_execute_sql"
    print(f"\n=== {label} ===")
    print(f"SQL (début): {sql[:200]}...")

    try:
        resp = requests.post(url, headers=HEADERS, json={"p_sql": sql}, timeout=60)
    except Exception as exc:
        print("[ERROR] Exception réseau:", exc)
        return False

    print("STATUS", resp.status_code)
    try:
        body = resp.json()
        print("BODY", json.dumps(body, ensure_ascii=False, indent=2)[:2000])
    except Exception:
        print("BODY_RAW", resp.text[:2000])

    return resp.status_code == 200


def deploy_edge_function(name: str, ts_path: str, verify_jwt: bool = True) -> bool:
    try:
        with open(ts_path, "r", encoding="utf-8") as f:
            code = f.read()
    except Exception as exc:
        print(f"[ERROR] Impossible de lire {ts_path}: {exc}")
        return False

    escaped_code = code.replace("'", "''")
    verify_jwt_sql = "true" if verify_jwt else "false"

    upsert_sql = f"""
INSERT INTO supabase_functions.functions (name, body, verify_jwt, import_map)
VALUES (
  '{name}',
  '{escaped_code}',
  {verify_jwt_sql},
  '{{}}'
)
ON CONFLICT (name) DO UPDATE SET
  body = EXCLUDED.body,
  verify_jwt = EXCLUDED.verify_jwt,
  import_map = EXCLUDED.import_map,
  updated_at = NOW();
    """.strip()

    if not run_sql(f"Créer/Mettre à jour l'Edge Function {name}", upsert_sql):
        return False

    verify_sql = f"""
SELECT name, status, created_at, updated_at
FROM supabase_functions.functions
WHERE name = '{name}';
    """.strip()

    run_sql(f"Vérifier l'Edge Function {name}", verify_sql)

    activate_sql = f"""
UPDATE supabase_functions.functions
SET status = 'ACTIVE'
WHERE name = '{name}';
    """.strip()

    if not run_sql(f"Activer l'Edge Function {name}", activate_sql):
        return False

    return True


def main() -> int:
    print("Déploiement via admin_execute_sql : admin-create-merchant-account")
    print("=" * 80)

    ok = deploy_edge_function(
        name="admin-create-merchant-account",
        ts_path="supabase/functions/admin-create-merchant-account/index.ts",
        verify_jwt=True,
    )

    if not ok:
        print("\n❌ Déploiement échoué.")
        return 1

    print("\n✅ Déploiement terminé. admin-create-merchant-account est enregistrée et ACTIVE.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

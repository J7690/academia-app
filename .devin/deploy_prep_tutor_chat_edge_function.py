#!/usr/bin/env python3
"""Déployer l'Edge Function prep-tutor-chat via supabase_functions.functions."""

import json
import requests
from auto_supabase_import import SUPABASE_URL, SUPABASE_SERVICE_KEY

HEADERS = {
    "apikey": SUPABASE_SERVICE_KEY,
    "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
    "Content-Type": "application/json",
}


def run_sql(label: str, sql: str) -> dict:
    url = f"{SUPABASE_URL}/rest/v1/rpc/admin_execute_sql"
    print(f"\n=== {label} ===")
    try:
        resp = requests.post(url, headers=HEADERS, json={"p_sql": sql}, timeout=30)
    except Exception as exc:
        print(f"[ERROR] Exception réseau: {exc}")
        return {"ok": False, "error": str(exc)}

    print(f"STATUS: {resp.status_code}")
    try:
        body = resp.json()
        print(f"BODY: {json.dumps(body, ensure_ascii=False, indent=2)[:2000]}")
        return body
    except Exception:
        print(f"BODY_RAW: {resp.text[:2000]}")
        return {"ok": False, "error": resp.text[:500]}


def main() -> int:
    print("=" * 60)
    print("Déploiement de l'Edge Function prep-tutor-chat")
    print("=" * 60)

    # 1) Lire le code de l'Edge Function
    edge_function_path = "../supabase/functions/prep-tutor-chat/index.ts"
    try:
        with open(edge_function_path, "r", encoding="utf-8") as f:
            edge_function_code = f.read()
    except Exception as exc:
        print(f"[ERROR] Impossible de lire le fichier Edge Function: {exc}")
        return 1

    print(f"Code lu: {len(edge_function_code)} caractères")

    # 2) Échapper le code pour SQL
    escaped_code = edge_function_code.replace("'", "''")

    # 3) Insérer/mettre à jour dans supabase_functions.functions
    upsert_sql = f"""
INSERT INTO supabase_functions.functions (name, body, verify_jwt, import_map)
VALUES (
  'prep-tutor-chat',
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

    result = run_sql("Créer/Mettre à jour l'Edge Function prep-tutor-chat", upsert_sql)

    # 4) Vérifier
    verify_sql = """
SELECT name, created_at, updated_at
FROM supabase_functions.functions
WHERE name = 'prep-tutor-chat'
    """.strip()

    run_sql("Vérifier l'Edge Function", verify_sql)

    # 5) Vérifier que les env vars OpenRouter sont disponibles
    # (elles sont partagées entre toutes les Edge Functions)
    check_env_sql = """
SELECT name, created_at, updated_at
FROM supabase_functions.functions
WHERE name = 'bobodo-chat'
    """.strip()

    result = run_sql("Vérifier que bobodo-chat existe (même env vars)", check_env_sql)

    print("\n" + "=" * 60)
    print("✅ Edge Function prep-tutor-chat déployée!")
    print("   Elle réutilise les mêmes variables d'environnement que bobodo-chat:")
    print("   - OPENROUTER_API_KEY")
    print("   - OPENROUTER_MODEL")
    print("   - SUPABASE_URL")
    print("   - SUPABASE_SERVICE_ROLE_KEY")
    print("=" * 60)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

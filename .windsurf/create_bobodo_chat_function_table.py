#!/usr/bin/env python3
"""Créer la table functions pour Edge Functions et déployer bobodo-chat."""

import json
import requests
from auto_supabase_import import SUPABASE_URL, SUPABASE_SERVICE_KEY

def run_sql(label: str, sql: str) -> dict:
    """Exécuter une commande SQL via admin_execute_sql."""
    url = f"{SUPABASE_URL}/rest/v1/rpc/admin_execute_sql"
    headers = {
        "apikey": SUPABASE_SERVICE_KEY,
        "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
        "Content-Type": "application/json"
    }
    
    print(f"\n=== {label} ===")
    print(f"SQL: {sql[:200]}...")
    
    try:
        resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
        print(f"STATUS: {resp.status_code}")
        
        if resp.status_code == 200:
            body = resp.json()
            print(f"RESULT: {json.dumps(body, ensure_ascii=False, indent=2)[:500]}")
            return body
        else:
            print(f"ERROR: {resp.text}")
            return {"ok": False, "error": resp.text}
    except Exception as exc:
        print(f"[ERROR] Exception: {exc}")
        return {"ok": False, "error": str(exc)}

def main() -> int:
    print("Création de la table supabase_functions.functions pour Edge Functions")
    print("=" * 70)
    
    # 1) Créer le schéma supabase_functions s'il n'existe pas
    create_schema_sql = """
    CREATE SCHEMA IF NOT EXISTS supabase_functions;
    """.strip()
    
    result = run_sql("Créer schéma supabase_functions", create_schema_sql)
    if not result.get("ok"):
        return 1
    
    # 2) Créer la table functions
    create_table_sql = """
    CREATE TABLE IF NOT EXISTS supabase_functions.functions (
        name TEXT PRIMARY KEY,
        body TEXT NOT NULL,
        verify_jwt BOOLEAN DEFAULT true,
        import_map JSONB DEFAULT '{}',
        status TEXT DEFAULT 'ACTIVE',
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
    );
    """.strip()
    
    result = run_sql("Créer table functions", create_table_sql)
    if not result.get("ok"):
        return 1
    
    # 3) Créer un trigger pour updated_at
    create_trigger_sql = """
    CREATE OR REPLACE FUNCTION supabase_functions.update_updated_at_column()
    RETURNS TRIGGER AS $$
    BEGIN
        NEW.updated_at = NOW();
        RETURN NEW;
    END;
    $$ language plpgsql;
    
    CREATE TRIGGER update_functions_updated_at
        BEFORE UPDATE ON supabase_functions.functions
        FOR EACH ROW
        EXECUTE FUNCTION supabase_functions.update_updated_at_column();
    """.strip()
    
    result = run_sql("Créer trigger updated_at", create_trigger_sql)
    if not result.get("ok"):
        return 1
    
    # 4) Donner les droits
    grant_sql = """
    GRANT ALL ON SCHEMA supabase_functions TO postgres;
    GRANT ALL ON SCHEMA supabase_functions TO service_role;
    GRANT USAGE ON SCHEMA supabase_functions TO authenticated, anon;
    GRANT ALL ON ALL TABLES IN SCHEMA supabase_functions TO postgres, service_role;
    GRANT SELECT ON ALL TABLES IN SCHEMA supabase_functions TO authenticated, anon;
    """.strip()
    
    result = run_sql("Donner les droits", grant_sql)
    if not result.get("ok"):
        return 1
    
    # 5) Vérifier que la table existe
    verify_sql = """
    SELECT table_name 
    FROM information_schema.tables 
    WHERE table_schema = 'supabase_functions' 
      AND table_name = 'functions';
    """.strip()
    
    result = run_sql("Vérifier la table", verify_sql)
    if not result.get("ok"):
        return 1
    
    print("\n✅ Table supabase_functions.functions créée avec succès!")
    print("Vous pouvez maintenant déployer l'Edge Function bobodo-chat.")
    
    return 0

if __name__ == "__main__":
    raise SystemExit(main())

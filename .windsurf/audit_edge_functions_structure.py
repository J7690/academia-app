#!/usr/bin/env python3
"""Auditer la structure des Edge Functions Supabase existantes."""

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
            print(f"RESULT: {json.dumps(body, ensure_ascii=False, indent=2)[:800]}")
            return body
        else:
            print(f"ERROR: {resp.text}")
            return {"ok": False, "error": resp.text}
    except Exception as exc:
        print(f"[ERROR] Exception: {exc}")
        return {"ok": False, "error": str(exc)}

def main() -> int:
    print("Audit de la structure des Edge Functions Supabase")
    print("=" * 50)
    
    # 1) Lister tous les schémas
    list_schemas_sql = """
    SELECT schema_name 
    FROM information_schema.schemata 
    WHERE schema_name NOT IN ('information_schema', 'pg_catalog', 'pg_toast')
    ORDER BY schema_name
    """.strip()
    
    result = run_sql("Lister les schémas", list_schemas_sql)
    
    # 2) Chercher spécifiquement les schémas liés aux Edge Functions
    edge_function_schemas = [
        'supabase_functions',
        'supabase_edge_functions',
        'edge_functions',
        'functions',
        'extensions'
    ]
    
    for schema in edge_function_schemas:
        check_schema_sql = f"""
        SELECT schema_name 
        FROM information_schema.schemata 
        WHERE schema_name = '{schema}'
        """.strip()
        
        result = run_sql(f"Vérifier le schéma {schema}", check_schema_sql)
    
    # 3) Lister toutes les tables dans tous les schémas (sauf ceux système)
    list_all_tables_sql = """
    SELECT table_schema, table_name, table_type
    FROM information_schema.tables 
    WHERE table_schema NOT IN ('information_schema', 'pg_catalog', 'pg_toast')
      AND (table_name LIKE '%function%' OR table_name LIKE '%edge%' OR table_name LIKE '%trigger%')
    ORDER BY table_schema, table_name
    """.strip()
    
    result = run_sql("Chercher les tables liées aux functions", list_all_tables_sql)
    
    # 4) Vérifier s'il existe des vues ou fonctions liées aux Edge Functions
    list_views_sql = """
    SELECT table_schema, table_name
    FROM information_schema.views 
    WHERE table_schema NOT IN ('information_schema', 'pg_catalog', 'pg_toast')
      AND (table_name LIKE '%function%' OR table_name LIKE '%edge%')
    ORDER BY table_schema, table_name
    """.strip()
    
    result = run_sql("Chercher les vues liées aux functions", list_views_sql)
    
    # 5) Vérifier les extensions PostgreSQL qui pourraient être liées
    list_extensions_sql = """
    SELECT extname, extversion, extnamespace::regnamespace as schema
    FROM pg_extension 
    WHERE extname IN ('pg_cron', 'pg_net', 'pg_graphql', 'plv8', 'plv8js')
    ORDER BY extname
    """.strip()
    
    result = run_sql("Vérifier les extensions pertinentes", list_extensions_sql)
    
    # 6) Vérifier s'il existe des tables dans le schéma public qui pourraient stocker les Edge Functions
    public_functions_sql = """
    SELECT table_name, column_name, data_type
    FROM information_schema.columns 
    WHERE table_schema = 'public'
      AND table_name LIKE '%function%'
    ORDER BY table_name, ordinal_position
    """.strip()
    
    result = run_sql("Chercher les tables functions dans public", public_functions_sql)
    
    # 7) Tester si l'Edge Function bobodo-chat est déjà accessible
    print("\n=== Test d'accès à l'Edge Function bobodo-chat ===")
    
    headers = {
        "apikey": SUPABASE_SERVICE_KEY,
        "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
        "Content-Type": "application/json"
    }
    
    function_url = f"{SUPABASE_URL}/functions/v1/bobodo-chat"
    test_payload = {
        "session_id": "00000000-0000-0000-0000-000000000000",
        "message": "test"
    }
    
    try:
        response = requests.post(function_url, headers=headers, json=test_payload, timeout=10)
        print(f"STATUS: {response.status_code}")
        print(f"RESPONSE: {response.text[:300]}")
    except Exception as exc:
        print(f"[ERROR] Exception: {exc}")
    
    # 8) Vérifier les autres Edge Functions qui pourraient exister
    print("\n=== Test d'autres Edge Functions possibles ===")
    
    possible_functions = ['hello-world', 'test', 'api', 'webhook']
    
    for func_name in possible_functions:
        try:
            url = f"{SUPABASE_URL}/functions/v1/{func_name}"
            response = requests.get(url, headers=headers, timeout=5)
            print(f"{func_name}: {response.status_code}")
        except:
            print(f"{func_name}: ERROR")
    
    return 0

if __name__ == "__main__":
    raise SystemExit(main())

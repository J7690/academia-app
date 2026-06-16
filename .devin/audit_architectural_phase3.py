#!/usr/bin/env python3
"""PHASE 3 - Recherche de proxys (proxy/wrapper/passerelle)"""
from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()
    
    print("\n" + "="*60)
    print("  PHASE 3 — RECHERCHE DE PROXYS")
    print("="*60 + "\n")
    
    # Rechercher les fonctions qui contiennent "proxy", "wrapper", "passerelle" dans leur nom
    sql_keywords = """
    SELECT
        n.nspname AS schema,
        p.proname AS name,
        pg_get_function_arguments(p.oid) AS args,
        pg_get_functiondef(p.oid) AS function_def
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname IN ('public', 'app')
    AND (
        p.proname LIKE '%proxy%'
        OR p.proname LIKE '%wrapper%'
        OR p.proname LIKE '%passerelle%'
        OR p.proname LIKE '%gateway%'
    )
    ORDER BY n.nspname, p.proname
    """
    
    result = m.execute_sql_auto(sql_keywords)
    
    print("Recherche par mots-clés (proxy/wrapper/passerelle/gateway):\n")
    
    if result.get('success') and result.get('data'):
        keyword_rpcs = result['data']
        print(f"RPCs trouvées par mots-clés: {len(keyword_rpcs)}\n")
        
        for rpc in keyword_rpcs:
            schema = rpc.get('schema', '?')
            name = rpc.get('name', '?')
            function_def = rpc.get('function_def', '')[:200]
            print(f"  [{schema}] {name}")
            print(f"    Définition: {function_def}...")
    else:
        print("  Aucune RPC trouvée par mots-clés.\n")
    
    print("\n" + "="*60)
    print("  RECHERCHE DE FONCTIONS QUI APPELLENT app.*")
    print("="*60 + "\n")
    
    # Rechercher les fonctions dans public qui appellent des fonctions dans app
    sql_calls_app = """
    SELECT
        n.nspname AS schema,
        p.proname AS name,
        pg_get_functiondef(p.oid) AS function_def
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
    AND pg_get_functiondef(p.oid) LIKE '%app.%'
    ORDER BY p.proname
    """
    
    result_calls = m.execute_sql_auto(sql_calls_app)
    
    print("Fonctions dans public qui appellent app.*:\n")
    
    if result_calls.get('success') and result_calls.get('data'):
        calling_rpcs = result_calls['data']
        print(f"RPCs trouvées: {len(calling_rpcs)}\n")
        
        for rpc in calling_rpcs:
            schema = rpc.get('schema', '?')
            name = rpc.get('name', '?')
            function_def = rpc.get('function_def', '')
            
            # Extraire les appels à app.*
            import re
            app_calls = re.findall(r'app\.\w+', function_def)
            
            if app_calls:
                print(f"  [{schema}] {name}")
                print(f"    Appelle: {', '.join(set(app_calls))}")
    else:
        print("  Aucune RPC trouvée qui appelle app.*\n")
    
    print("\n" + "="*60)
    print("  RECHERCHE DE FONCTIONS QUI APPELLENT public.*")
    print("="*60 + "\n")
    
    # Rechercher les fonctions dans app qui appellent des fonctions dans public
    sql_calls_public = """
    SELECT
        n.nspname AS schema,
        p.proname AS name,
        pg_get_functiondef(p.oid) AS function_def
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'app'
    AND pg_get_functiondef(p.oid) LIKE '%public.%'
    ORDER BY p.proname
    """
    
    result_calls_pub = m.execute_sql_auto(sql_calls_public)
    
    print("Fonctions dans app qui appellent public.*:\n")
    
    if result_calls_pub.get('success') and result_calls_pub.get('data'):
        calling_rpcs = result_calls_pub['data']
        print(f"RPCs trouvées: {len(calling_rpcs)}\n")
        
        for rpc in calling_rpcs:
            schema = rpc.get('schema', '?')
            name = rpc.get('name', '?')
            function_def = rpc.get('function_def', '')
            
            # Extraire les appels à public.*
            import re
            public_calls = re.findall(r'public\.\w+', function_def)
            
            if public_calls:
                print(f"  [{schema}] {name}")
                print(f"    Appelle: {', '.join(set(public_calls))}")
    else:
        print("  Aucune RPC trouvée qui appelle public.*\n")
    
    print("\n✅ PHASE 3 terminée.\n")

if __name__ == "__main__":
    main()

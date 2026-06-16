#!/usr/bin/env python3
"""Inventaire spécifique des RPCs teacher/instructor"""
import requests
import json
from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()
    
    print("\n" + "="*60)
    print("  PHASE 3 — RPC TEACHER/INSTRUCTOR SPÉCIFIQUES")
    print("="*60 + "\n")
    
    # Récupérer toutes les fonctions des schémas public et app
    sql = """
    SELECT n.nspname AS schema, p.proname AS name,
           pg_get_function_arguments(p.oid) AS args,
           pg_get_function_result(p.oid) AS returns
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname IN ('public', 'app')
    AND (p.proname LIKE '%teacher%' OR p.proname LIKE '%instructor%' OR p.proname LIKE '%mentor%' OR p.proname LIKE '%coach%' OR p.proname LIKE '%tutor%')
    ORDER BY n.nspname, p.proname
    """
    
    result = m.execute_sql_auto(sql)
    
    if result.get('success'):
        matching_rpcs = result.get('data', [])
        print(f"RPCs teacher/instructor trouvées: {len(matching_rpcs)}\n")
        
        for rpc in matching_rpcs:
            schema = rpc.get('schema', '?')
            name = rpc.get('name', '?')
            args = rpc.get('args', '')[:100]
            returns = rpc.get('returns', '')[:60]
            
            print(f"[{schema}] {name}")
            print(f"  Args: {args}")
            print(f"  Returns: {returns}\n")
    else:
        print(f"Erreur: {result.get('error')}")
    
    print("✅ Inventaire terminé.\n")

if __name__ == "__main__":
    main()

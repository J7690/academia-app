#!/usr/bin/env python3
"""Inventaire des RPC par mots-clés (teacher/instructor/td/prep/assignment/live/session/course/orientation)"""
import requests
import json
from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()
    
    print("\n" + "="*60)
    print("  PHASE 3 — INVENTAIRE COMPLET DES RPC")
    print("="*60 + "\n")
    
    keywords = [
        'teacher', 'instructor', 'mentor', 'coach', 'tutor',
        'td', 'prep', 'concours',
        'assignment', 'exercise', 'submission',
        'live', 'session',
        'course', 'orientation'
    ]
    
    # Récupérer toutes les fonctions des schémas public et app
    sql = """
    SELECT n.nspname AS schema, p.proname AS name,
           pg_get_function_arguments(p.oid) AS args,
           pg_get_function_result(p.oid) AS returns
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname IN ('public', 'app')
    ORDER BY n.nspname, p.proname
    """
    
    result = m.execute_sql_auto(sql)
    
    if result.get('success'):
        all_rpcs = result.get('data', [])
        print(f"Total RPCs dans public + app: {len(all_rpcs)}\n")
        
        # Filtrer par mots-clés
        for keyword in keywords:
            matching_rpcs = [r for r in all_rpcs if keyword.lower() in r.get('name', '').lower()]
            
            if matching_rpcs:
                print(f"\n{'='*60}")
                print(f"  MOT-CLÉ: {keyword}")
                print(f"{'='*60}")
                print(f"  RPCs trouvées: {len(matching_rpcs)}")
                
                for rpc in matching_rpcs:
                    schema = rpc.get('schema', '?')
                    name = rpc.get('name', '?')
                    args = rpc.get('args', '')[:80]
                    returns = rpc.get('returns', '')[:50]
                    
                    print(f"  - [{schema}] {name}")
                    print(f"    Args: {args}")
                    print(f"    Returns: {returns}")
    else:
        print(f"Erreur: {result.get('error')}")
    
    print("\n✅ Inventaire des RPC terminé.\n")

if __name__ == "__main__":
    main()

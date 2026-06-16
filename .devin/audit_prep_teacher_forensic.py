#!/usr/bin/env python3
"""Audit forensique RPC prep_teacher - Inventaire exhaustif"""
from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()
    
    print("\n" + "="*60)
    print("  PHASE 1 — INVENTAIRE EXHAUSTIF RPC")
    print("="*60 + "\n")
    
    keywords = [
        'prep_teacher',
        'teacher_prep',
        'assignment',
        'submission',
        'live_session',
        'live',
        'session'
    ]
    
    # Récupérer TOUTES les fonctions des schémas public et app
    sql = """
    SELECT
        n.nspname AS schema,
        p.proname AS name,
        pg_get_function_arguments(p.oid) AS args,
        pg_get_function_result(p.oid) AS returns,
        pg_get_userbyid(p.proowner) AS owner,
        p.proacl AS permissions
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
                    args = rpc.get('args', '')[:100]
                    returns = rpc.get('returns', '')[:60]
                    owner = rpc.get('owner', '?')
                    permissions = rpc.get('permissions', [])[:100] if rpc.get('permissions') else []
                    
                    print(f"\n  [{schema}] {name}")
                    print(f"    Args: {args}")
                    print(f"    Returns: {returns}")
                    print(f"    Owner: {owner}")
                    print(f"    Permissions: {permissions}")
    else:
        print(f"Erreur: {result.get('error')}")
    
    print("\n✅ Inventaire exhaustif terminé.\n")

if __name__ == "__main__":
    main()

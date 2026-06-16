#!/usr/bin/env python3
"""PHASE 1 - Interroger PostgreSQL pour récupérer les signatures exactes"""
from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()
    
    print("\n" + "="*60)
    print("  PHASE 1 — SIGNATURES EXACTES POSTGRESQL")
    print("="*60 + "\n")
    
    target_rpcs = [
        'app_prep_teacher_list_assignments',
        'app_prep_teacher_upsert_assignment',
        'app_prep_teacher_list_submissions',
        'app_prep_teacher_grade_submission',
        'app_prep_teacher_list_live_sessions',
        'app_prep_teacher_upsert_live_session',
        'app_prep_teacher_start_live_session',
        'app_prep_teacher_end_live_session',
    ]
    
    exact_signatures = []
    
    for rpc_name in target_rpcs:
        print(f"\n{rpc_name}:")
        
        # Récupérer la signature exacte depuis pg_proc
        sql = f"""
        SELECT
            n.nspname AS schema,
            p.proname AS name,
            pg_get_function_arguments(p.oid) AS args,
            pg_get_function_identity_arguments(p.oid) AS identity_args
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'app' AND p.proname = '{rpc_name}'
        """
        
        result = m.execute_sql_auto(sql)
        
        if result.get('success') and result.get('data'):
            row = result['data'][0]
            schema = row.get('schema', '')
            name = row.get('name', '')
            args = row.get('args', '')
            identity_args = row.get('identity_args', '')
            
            print(f"  Schéma: {schema}")
            print(f"  Nom: {name}")
            print(f"  Arguments complets: {args}")
            print(f"  Identité (types uniquement): {identity_args}")
            
            exact_signatures.append({
                'name': rpc_name,
                'schema': schema,
                'args': args,
                'identity_args': identity_args
            })
        else:
            print(f"  ✗ Erreur: {result.get('error')}")
    
    # Sauvegarder les résultats
    import json
    with open('C:\\Users\\fasop\\AndroidStudioProjects\\academia\\.windsurf\\logs\\exact_signatures.json', 'w', encoding='utf-8') as f:
        json.dump(exact_signatures, f, indent=2, ensure_ascii=False)
    
    print("\n✅ PHASE 1 terminée.\n")

if __name__ == "__main__":
    main()

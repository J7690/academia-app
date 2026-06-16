#!/usr/bin/env python3
"""PHASE 2 - Preuve d'existence des 7 RPCs app_prep_teacher_*"""
from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()
    
    print("\n" + "="*60)
    print("  PHASE 2 — PREUVE D'EXISTENCE")
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
    
    for rpc_name in target_rpcs:
        print(f"\n{'='*60}")
        print(f"  RPC: {rpc_name}")
        print(f"{'='*60}")
        
        # Vérifier l'existence dans pg_proc
        sql = f"""
        SELECT
            n.nspname AS schema,
            p.proname AS name,
            pg_get_function_arguments(p.oid) AS args,
            pg_get_function_result(p.oid) AS returns,
            pg_get_userbyid(p.proowner) AS owner,
            p.proacl AS permissions,
            p.oid AS function_oid
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname IN ('public', 'app')
        AND p.proname = '{rpc_name}'
        """
        
        result = m.execute_sql_auto(sql)
        
        if result.get('success'):
            data = result.get('data', [])
            if data:
                rpc = data[0]
                schema = rpc.get('schema', '?')
                name = rpc.get('name', '?')
                args = rpc.get('args', '')
                returns = rpc.get('returns', '')
                owner = rpc.get('owner', '?')
                permissions = rpc.get('permissions', [])
                oid = rpc.get('function_oid', '?')
                
                print(f"  EXISTE: OUI")
                print(f"  Schéma exact: {schema}")
                print(f"  Nom complet: {name}")
                print(f"  Signature: {args}")
                print(f"  Type de retour: {returns}")
                print(f"  Propriétaire: {owner}")
                print(f"  Permissions: {permissions}")
                print(f"  OID: {oid}")
                
                # Preuve supplémentaire: récupérer le corps de la fonction
                sql_body = f"""
                SELECT pg_get_functiondef(p.oid) AS function_def
                FROM pg_proc p
                JOIN pg_namespace n ON n.oid = p.pronamespace
                WHERE n.nspname = '{schema}'
                AND p.proname = '{name}'
                """
                
                result_body = m.execute_sql_auto(sql_body)
                if result_body.get('success') and result_body.get('data'):
                    function_def = result_body['data'][0].get('function_def', '')
                    print(f"  Définition (premières 200 chars): {function_def[:200]}...")
            else:
                print(f"  EXISTE: NON")
                print(f"  Aucune entrée trouvée dans pg_proc")
        else:
            print(f"  ERREUR: {result.get('error')}")
    
    print("\n✅ PHASE 2 terminée.\n")

if __name__ == "__main__":
    main()

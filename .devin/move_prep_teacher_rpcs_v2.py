#!/usr/bin/env python3
"""PHASE 2 - Déplacement des 8 RPCs de app vers public (avec signatures complètes)"""
from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()
    
    print("\n" + "="*60)
    print("  PHASE 2 — DÉPLACEMENT DES 8 RPCs (AVEC SIGNATURES COMPLÈTES)")
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
        print(f"Déplacement de {rpc_name}...")
        
        # Récupérer la signature complète
        sql = f"""
        SELECT
            p.proname AS name,
            pg_get_function_arguments(p.oid) AS args
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'app' AND p.proname = '{rpc_name}'
        """
        
        result = m.execute_sql_auto(sql)
        
        if result.get('success') and result.get('data'):
            args = result['data'][0].get('args', '')
            
            # ALTER FUNCTION avec signature complète
            if args:
                sql_alter = f"ALTER FUNCTION app.{rpc_name}({args}) SET SCHEMA public"
            else:
                sql_alter = f"ALTER FUNCTION app.{rpc_name}() SET SCHEMA public"
            
            result_alter = m.execute_sql_auto(sql_alter)
            
            if result_alter.get('success'):
                print(f"  ✓ Déplacé vers public")
            else:
                print(f"  ✗ Erreur: {result_alter.get('error')}")
        else:
            print(f"  ✗ Erreur récupération signature: {result.get('error')}")
    
    print("\n✅ PHASE 2 terminée.\n")

if __name__ == "__main__":
    main()

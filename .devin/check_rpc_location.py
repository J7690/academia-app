#!/usr/bin/env python3
"""Vérification détaillée de l'emplacement des RPCs"""
from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()
    
    print("\n" + "="*60)
    print("  VÉRIFICATION DÉTAILLÉE DE L'EMPLACEMENT")
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
        print(f"\n{rpc_name}:")
        
        # Chercher dans public
        sql_public = f"""
        SELECT n.nspname AS schema, p.proname AS name
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public' AND p.proname = '{rpc_name}'
        """
        
        result_public = m.execute_sql_auto(sql_public)
        
        if result_public.get('success') and result_public.get('data'):
            print(f"  ✓ Trouvée dans public")
        else:
            print(f"  ✗ Non trouvée dans public")
        
        # Chercher dans app
        sql_app = f"""
        SELECT n.nspname AS schema, p.proname AS name
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'app' AND p.proname = '{rpc_name}'
        """
        
        result_app = m.execute_sql_auto(sql_app)
        
        if result_app.get('success') and result_app.get('data'):
            print(f"  ✗ Encore dans app")
        else:
            print(f"  ✓ Plus dans app")
    
    print("\n✅ Vérification terminée.\n")

if __name__ == "__main__":
    main()

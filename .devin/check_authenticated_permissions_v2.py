#!/usr/bin/env python3
"""PHASE 3 - Contrôle authenticated EXECUTE permissions (v2)"""
from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()
    
    print("\n" + "="*60)
    print("  PHASE 3 — CONTRÔLE AUTHENTICATED EXECUTE PERMISSIONS")
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
    
    permission_results = []
    
    for rpc_name in target_rpcs:
        print(f"{rpc_name}:")
        
        # Vérifier les permissions EXECUTE pour authenticated via information_schema
        sql = f"""
        SELECT
            grantee,
            privilege_type
        FROM information_schema.role_routine_grants
        WHERE routine_schema = 'public'
        AND routine_name = '{rpc_name}'
        AND grantee = 'authenticated'
        AND privilege_type = 'EXECUTE'
        """
        
        result = m.execute_sql_auto(sql)
        
        if result.get('success') and result.get('data'):
            if len(result['data']) > 0:
                print(f"  authenticated EXECUTE: OUI")
                permission_results.append({'name': rpc_name, 'authenticated': True})
            else:
                print(f"  authenticated EXECUTE: NON")
                permission_results.append({'name': rpc_name, 'authenticated': False})
        else:
            print(f"  ✗ Erreur: {result.get('error')}")
            permission_results.append({'name': rpc_name, 'authenticated': 'ERROR'})
    
    # Sauvegarder les résultats
    import json
    with open('C:\\Users\\fasop\\AndroidStudioProjects\\academia\\.windsurf\\logs\\post_migration_permissions.json', 'w', encoding='utf-8') as f:
        json.dump(permission_results, f, indent=2, ensure_ascii=False)
    
    print("\n✅ PHASE 3 terminée.\n")

if __name__ == "__main__":
    main()

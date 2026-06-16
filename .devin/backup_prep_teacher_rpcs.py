#!/usr/bin/env python3
"""PHASE 1 - Sauvegarde SQL des 8 RPCs app_prep_teacher_*"""
from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()
    
    print("\n" + "="*60)
    print("  PHASE 1 — SAUVEGARDE SQL DES 8 RPCs")
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
    
    backup_file = "C:\\Users\\fasop\\AndroidStudioProjects\\academia\\.windsurf\\logs\\backup_prep_teacher_rpcs_20260606.sql"
    
    with open(backup_file, 'w', encoding='utf-8') as f:
        f.write("-- SAUVEGARDE DES RPCs app_prep_teacher_*\n")
        f.write(f"-- Date: 2026-06-06\n")
        f.write(f"-- Projet: academia_app\n\n")
        
        for rpc_name in target_rpcs:
            print(f"Sauvegarde de {rpc_name}...")
            
            sql = f"""
            SELECT pg_get_functiondef(p.oid) AS function_def
            FROM pg_proc p
            JOIN pg_namespace n ON n.oid = p.pronamespace
            WHERE n.nspname = 'app' AND p.proname = '{rpc_name}'
            """
            
            result = m.execute_sql_auto(sql)
            
            if result.get('success') and result.get('data'):
                function_def = result['data'][0].get('function_def', '')
                f.write(f"-- {rpc_name}\n")
                f.write(function_def)
                f.write("\n\n")
                print(f"  ✓ Sauvegardé")
            else:
                print(f"  ✗ Erreur: {result.get('error')}")
                f.write(f"-- ERREUR: {rpc_name} - {result.get('error')}\n\n")
    
    print(f"\nSauvegarde terminée: {backup_file}")
    print("✅ PHASE 1 terminée.\n")

if __name__ == "__main__":
    main()

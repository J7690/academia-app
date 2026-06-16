#!/usr/bin/env python3
"""PHASE 1 - Vérification du schéma des 8 RPCs"""
from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()
    
    print("\n" + "="*60)
    print("  PHASE 1 — VÉRIFICATION DU SCHÉMA")
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
    
    schema_results = []
    
    for rpc_name in target_rpcs:
        print(f"{rpc_name}:")
        
        # Vérifier le schéma actuel
        sql = f"""
        SELECT
            n.nspname AS schema,
            p.proname AS name
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE p.proname = '{rpc_name}'
        """
        
        result = m.execute_sql_auto(sql)
        
        if result.get('success') and result.get('data'):
            row = result['data'][0]
            schema = row.get('schema', '?')
            name = row.get('name', '?')
            print(f"  Schéma: {schema}")
            print(f"  Nom: {name}")
            schema_results.append({'name': rpc_name, 'schema': schema})
        else:
            print(f"  ✗ Erreur: {result.get('error')}")
            schema_results.append({'name': rpc_name, 'schema': 'ERROR'})
    
    # Sauvegarder les résultats
    import json
    with open('C:\\Users\\fasop\\AndroidStudioProjects\\academia\\.windsurf\\logs\\post_migration_schema.json', 'w', encoding='utf-8') as f:
        json.dump(schema_results, f, indent=2, ensure_ascii=False)
    
    print("\n✅ PHASE 1 terminée.\n")

if __name__ == "__main__":
    main()

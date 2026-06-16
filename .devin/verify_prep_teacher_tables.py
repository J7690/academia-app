#!/usr/bin/env python3
"""PHASE 2 - Vérifier l'existence des tables référencées"""
from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()
    
    print("\n" + "="*60)
    print("  PHASE 2 — VÉRIFICATION DES TABLES RÉFÉRENCÉES")
    print("="*60 + "\n")
    
    # Tables identifiées manuellement à partir des définitions SQL
    table_dependencies = {
        'app_prep_teacher_list_assignments': ['prep_assignments', 'prep_assignment_submissions'],
        'app_prep_teacher_upsert_assignment': ['prep_assignments'],
        'app_prep_teacher_list_submissions': ['prep_assignments', 'prep_assignment_submissions', 'students'],
        'app_prep_teacher_grade_submission': ['prep_assignment_submissions'],
        'app_prep_teacher_list_live_sessions': ['prep_live_sessions', 'prep_live_participants'],
        'app_prep_teacher_upsert_live_session': ['prep_live_sessions'],
        'app_prep_teacher_start_live_session': ['prep_live_sessions'],
        'app_prep_teacher_end_live_session': ['prep_live_sessions'],
    }
    
    all_tables = set()
    for tables in table_dependencies.values():
        all_tables.update(tables)
    
    print(f"Tables uniques à vérifier: {len(all_tables)}\n")
    
    table_status = {}
    
    for table in sorted(all_tables):
        print(f"Table: {table}")
        
        # Vérifier l'existence
        sql = f"""
        SELECT
            table_schema,
            table_name
        FROM information_schema.tables
        WHERE table_name = '{table}'
        """
        
        result = m.execute_sql_auto(sql)
        
        if result.get('success') and result.get('data'):
            table_info = result['data'][0]
            schema = table_info.get('table_schema', '?')
            print(f"  ✓ Existe dans schéma: {schema}")
            
            # Nombre d'enregistrements
            sql_count = f"""
            SELECT reltuples::bigint as estimate
            FROM pg_class c
            JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE n.nspname = '{schema}' AND c.relname = '{table}'
            """
            
            result_count = m.execute_sql_auto(sql_count)
            
            if result_count.get('success') and result_count.get('data'):
                count = result_count['data'][0].get('estimate', 0)
                print(f"  Enregistrements (est.): {count}")
            
            table_status[table] = {
                'exists': True,
                'schema': schema,
                'count': count
            }
        else:
            print(f"  ✗ N'existe pas")
            table_status[table] = {
                'exists': False,
                'schema': None,
                'count': 0
            }
        
        print()
    
    # Sauvegarder les résultats
    import json
    with open('C:\\Users\\fasop\\AndroidStudioProjects\\academia\\.windsurf\\logs\\prep_teacher_table_status.json', 'w', encoding='utf-8') as f:
        json.dump(table_status, f, indent=2, ensure_ascii=False)
    
    print("✅ PHASE 2 terminée. Résultats sauvegardés.\n")

if __name__ == "__main__":
    main()

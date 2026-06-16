#!/usr/bin/env python3
"""Vérification spécifique des RPCs app_prep_teacher_* manquantes"""
import requests
import json

def main():
    from supabase_auto_manager import SupabaseAutoManager
    m = SupabaseAutoManager()
    
    print("\n" + "="*60)
    print("  VÉRIFICATION RPCs app_prep_teacher_*")
    print("="*60 + "\n")
    
    # RPCs appelées par Flutter
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
    
    # Vérifier dans tous les schemas
    sql = """
    SELECT n.nspname AS schema, p.proname AS name, 
           pg_get_function_arguments(p.oid) AS args
    FROM pg_proc p 
    JOIN pg_namespace n ON n.oid = p.pronamespace 
    WHERE p.proname = ANY(%s)
    AND n.nspname NOT IN ('pg_catalog', 'information_schema')
    ORDER BY n.nspname, p.proname
    """
    
    result = requests.post(
        f"{m.url}/rest/v1/rpc/execute_sql",
        headers=m.headers,
        json={"sql_query": sql, "params": [target_rpcs]},
        timeout=30
    )
    
    if result.status_code == 200:
        data = result.json()
        if isinstance(data, list):
            found_rpcs = {r['name']: r for r in data}
            
            for rpc in target_rpcs:
                if rpc in found_rpcs:
                    r = found_rpcs[rpc]
                    print(f"✅ {rpc}")
                    print(f"   Schema: {r['schema']}")
                    print(f"   Args: {r['args'][:100]}")
                else:
                    print(f"❌ {rpc} — NON TROUVÉE")
        else:
            print(f"Erreur format réponse: {data}")
    else:
        print(f"Erreur HTTP: {result.status_code} - {result.text[:200]}")
    
    print("\n" + "="*60)
    print("  VÉRIFICATION RPCs app_prep_student_* correspondantes")
    print("="*60 + "\n")
    
    # Vérifier les RPCs student correspondantes
    student_rpcs = [
        'app_prep_student_list_assignments',
        'app_prep_student_list_live_sessions',
        'app_prep_student_join_live_session',
        'app_prep_student_submit_assignment',
        'app_prep_student_get_submission',
    ]
    
    sql2 = """
    SELECT n.nspname AS schema, p.proname AS name
    FROM pg_proc p 
    JOIN pg_namespace n ON n.oid = p.pronamespace 
    WHERE p.proname = ANY(%s)
    AND n.nspname NOT IN ('pg_catalog', 'information_schema')
    ORDER BY n.nspname, p.proname
    """
    
    result2 = requests.post(
        f"{m.url}/rest/v1/rpc/execute_sql",
        headers=m.headers,
        json={"sql_query": sql2, "params": [student_rpcs]},
        timeout=30
    )
    
    if result2.status_code == 200:
        data2 = result2.json()
        if isinstance(data2, list):
            for r in data2:
                print(f"✅ {r['name']} (schema: {r['schema']})")
            
            found_student = {r['name'] for r in data2}
            for rpc in student_rpcs:
                if rpc not in found_student:
                    print(f"❌ {rpc} — NON TROUVÉE")
    
    print("\n✅ Vérification terminée.\n")

if __name__ == "__main__":
    main()

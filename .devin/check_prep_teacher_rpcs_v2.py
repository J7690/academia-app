#!/usr/bin/env python3
"""Vérification spécifique des RPCs app_prep_teacher_* manquantes via pg_proc direct"""
import requests
import json

def main():
    # Configuration directe
    m_url = 'https://thevdfcwlcqzdoybfvgs.supabase.co'
    m_key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM'
    
    headers = {
        'apikey': m_key,
        'Authorization': f'Bearer {m_key}',
        'Content-Type': 'application/json'
    }
    
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
    
    # Requête SQL pour chercher les RPCs dans pg_proc
    sql = """
    SELECT n.nspname AS schema, p.proname AS name, 
           pg_get_function_arguments(p.oid) AS args,
           pg_get_function_result(p.oid) AS returns
    FROM pg_proc p 
    JOIN pg_namespace n ON n.oid = p.pronamespace 
    WHERE p.proname = ANY(%s)
    AND n.nspname NOT IN ('pg_catalog', 'information_schema')
    ORDER BY n.nspname, p.proname
    """
    
    # Utiliser l'API REST directe avec pg_stat_statements ou autre méthode
    # Alternative: tester chaque RPC via un appel REST
    
    print("Test via appels REST directs:\n")
    
    for rpc in target_rpcs:
        try:
            resp = requests.post(
                f"{m_url}/rest/v1/rpc/{rpc}",
                headers=headers,
                json={},
                timeout=10
            )
            
            if resp.status_code == 200:
                print(f"✅ {rpc} → 200 OK (EXISTS)")
            elif resp.status_code == 404:
                print(f"❌ {rpc} → 404 NOT FOUND (N'EXISTE PAS)")
            elif resp.status_code == 401:
                print(f"✅ {rpc} → 401 UNAUTHORIZED (EXISTS mais besoin auth)")
            else:
                body = resp.text[:100]
                print(f"⚠️  {rpc} → {resp.status_code} ({body})")
        except Exception as e:
            print(f"❌ {rpc} → Exception: {str(e)[:50]}")
    
    print("\n" + "="*60)
    print("  VÉRIFICATION RPCs app_prep_student_* correspondantes")
    print("="*60 + "\n")
    
    student_rpcs = [
        'app_prep_student_list_assignments',
        'app_prep_student_list_live_sessions',
        'app_prep_student_join_live_session',
        'app_prep_student_submit_assignment',
        'app_prep_student_get_submission',
    ]
    
    for rpc in student_rpcs:
        try:
            resp = requests.post(
                f"{m_url}/rest/v1/rpc/{rpc}",
                headers=headers,
                json={},
                timeout=10
            )
            
            if resp.status_code == 200:
                print(f"✅ {rpc} → 200 OK (EXISTS)")
            elif resp.status_code == 404:
                print(f"❌ {rpc} → 404 NOT FOUND (N'EXISTE PAS)")
            elif resp.status_code == 401:
                print(f"✅ {rpc} → 401 UNAUTHORIZED (EXISTS mais besoin auth)")
            else:
                body = resp.text[:100]
                print(f"⚠️  {rpc} → {resp.status_code} ({body})")
        except Exception as e:
            print(f"❌ {rpc} → Exception: {str(e)[:50]}")
    
    print("\n✅ Vérification terminée.\n")

if __name__ == "__main__":
    main()

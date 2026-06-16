#!/usr/bin/env python3
"""PHASE 3 - Contrôle (schéma, PostgREST, REST, service_role, authenticated)"""
from supabase_auto_manager import SupabaseAutoManager
import requests

def main():
    m = SupabaseAutoManager()
    
    print("\n" + "="*60)
    print("  PHASE 3 — CONTRÔLE")
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
    
    print(f"{'RPC':<50} {'Schéma':<10} {'PostgREST':<15} {'Permissions':<30}")
    print("-" * 105)
    
    for rpc_name in target_rpcs:
        # Vérifier le schéma
        sql = f"""
        SELECT
            n.nspname AS schema,
            p.proname AS name,
            p.proacl AS permissions
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname IN ('public', 'app')
        AND p.proname = '{rpc_name}'
        """
        
        result = m.execute_sql_auto(sql)
        
        if result.get('success') and result.get('data'):
            rpc = result['data'][0]
            schema = rpc.get('schema', '?')
            permissions = str(rpc.get('permissions', []))[:30]
            
            # Test PostgREST
            try:
                r = requests.post(
                    f"{m.url}/rest/v1/rpc/{rpc_name}",
                    headers=m.headers,
                    json={},
                    timeout=10
                )
                if r.status_code == 200:
                    postgrest = "OUI (200)"
                elif r.status_code == 404:
                    postgrest = "NON (404)"
                elif r.status_code == 401:
                    postgrest = "AUTH (401)"
                else:
                    postgrest = f"ERR ({r.status_code})"
            except Exception as e:
                postgrest = f"EXC ({str(e)[:5]})"
            
            print(f"{rpc_name:<50} {schema:<10} {postgrest:<15} {permissions:<30}")
        else:
            print(f"{rpc_name:<50} {'NON TROUVÉ':<10} {'-':<15} {'-':<30}")
    
    print("\n✅ PHASE 3 terminée.\n")

if __name__ == "__main__":
    main()

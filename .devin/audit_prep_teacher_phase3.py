#!/usr/bin/env python3
"""PHASE 3 - Test de visibilité (public/app/PostgREST/service_role/authenticated)"""
import requests
import json
from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()
    
    print("\n" + "="*60)
    print("  PHASE 3 — TEST DE VISIBILITÉ")
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
    
    print("TABLEAU DE VISIBILITÉ:\n")
    print(f"{'RPC':<40} {'Public':<10} {'App':<10} {'PostgREST':<15} {'Service_Role':<15} {'Authenticated':<15}")
    print("-" * 105)
    
    for rpc_name in target_rpcs:
        # 1. Visible dans public ?
        sql_public = f"""
        SELECT COUNT(*) as count
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public' AND p.proname = '{rpc_name}'
        """
        result_public = m.execute_sql_auto(sql_public)
        visible_public = "OUI" if result_public.get('success') and result_public.get('data', [{}])[0].get('count', 0) > 0 else "NON"
        
        # 2. Visible dans app ?
        sql_app = f"""
        SELECT COUNT(*) as count
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'app' AND p.proname = '{rpc_name}'
        """
        result_app = m.execute_sql_auto(sql_app)
        visible_app = "OUI" if result_app.get('success') and result_app.get('data', [{}])[0].get('count', 0) > 0 else "NON"
        
        # 3. Accessible via PostgREST (test REST direct)
        try:
            r = requests.post(
                f"{m.url}/rest/v1/rpc/{rpc_name}",
                headers=m.headers,
                json={},
                timeout=10
            )
            if r.status_code == 200:
                postgrest_accessible = "OUI (200)"
            elif r.status_code == 404:
                postgrest_accessible = "NON (404)"
            elif r.status_code == 401:
                postgrest_accessible = "AUTH (401)"
            else:
                postgrest_accessible = f"ERR ({r.status_code})"
        except Exception as e:
            postgrest_accessible = f"EXC ({str(e)[:5]})"
        
        # 4. Permissions EXECUTE pour service_role
        sql_perms = f"""
        SELECT
            n.nspname AS schema,
            p.proname AS name,
            p.proacl AS permissions
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname IN ('public', 'app')
        AND p.proname = '{rpc_name}'
        """
        result_perms = m.execute_sql_auto(sql_perms)
        
        service_role_perm = "NON"
        authenticated_perm = "NON"
        
        if result_perms.get('success') and result_perms.get('data'):
            permissions = result_perms['data'][0].get('permissions', [])
            if permissions:
                perm_str = str(permissions)
                service_role_perm = "OUI" if "service_role" in perm_str else "NON"
                authenticated_perm = "OUI" if "authenticated" in perm_str else "NON"
        
        print(f"{rpc_name:<40} {visible_public:<10} {visible_app:<10} {postgrest_accessible:<15} {service_role_perm:<15} {authenticated_perm:<15}")
    
    print("\n" + "="*60)
    print("  ANALYSE DES PERMISSIONS DÉTAILLÉES")
    print("="*60 + "\n")
    
    # Comparaison avec app_td_teacher_*
    td_rpcs = [
        'app_td_teacher_get_dashboard',
        'app_td_teacher_list_assignments',
    ]
    
    print("COMPARAISON AVEC TD:\n")
    print(f"{'RPC':<40} {'Schéma':<10} {'Permissions':<30}")
    print("-" * 80)
    
    for rpc_name in td_rpcs:
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
            print(f"{rpc_name:<40} {schema:<10} {permissions:<30}")
    
    print("\n✅ PHASE 3 terminée.\n")

if __name__ == "__main__":
    main()

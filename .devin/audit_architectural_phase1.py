#!/usr/bin/env python3
"""PHASE 1 - Inventaire des RPC TD fonctionnelles"""
from supabase_auto_manager import SupabaseAutoManager
import requests

def main():
    m = SupabaseAutoManager()
    
    print("\n" + "="*60)
    print("  PHASE 1 — INVENTAIRE DES RPC TD FONCTIONNELLES")
    print("="*60 + "\n")
    
    target_rpcs = [
        'app_td_teacher_list_assignments',
        'app_td_teacher_get_dashboard',
        'app_td_teacher_list_students',
        'app_td_teacher_add_resource',
        'app_td_teacher_list_resources',
        'app_td_teacher_list_upcoming_sessions',
    ]
    
    print(f"{'RPC':<45} {'Schéma':<10} {'Signature':<30} {'Propriétaire':<15} {'EXECUTE':<10} {'PostgREST':<15}")
    print("-" * 125)
    
    for rpc_name in target_rpcs:
        # Récupérer les détails de la RPC
        sql = f"""
        SELECT
            n.nspname AS schema,
            p.proname AS name,
            pg_get_function_arguments(p.oid) AS args,
            pg_get_userbyid(p.proowner) AS owner,
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
            args = rpc.get('args', '')[:30]
            owner = rpc.get('owner', '?')
            permissions = rpc.get('permissions', [])
            
            # Vérifier les droits EXECUTE
            has_execute = "OUI" if permissions and any('EXECUTE' in str(p) for p in permissions) else "NON"
            
            # Test PostgREST
            try:
                r = requests.post(
                    f"{m.url}/rest/v1/rpc/{rpc_name}",
                    headers=m.headers,
                    json={},
                    timeout=10
                )
                postgrest = "OUI" if r.status_code == 200 else f"NON ({r.status_code})"
            except Exception as e:
                postgrest = f"ERR ({str(e)[:5]})"
            
            print(f"{rpc_name:<45} {schema:<10} {args:<30} {owner:<15} {has_execute:<10} {postgrest:<15}")
        else:
            print(f"{rpc_name:<45} {'NON TROUVÉ':<10} {'-':<30} {'-':<15} {'-':<10} {'-':<15}")
    
    print("\n✅ PHASE 1 terminée.\n")

if __name__ == "__main__":
    main()

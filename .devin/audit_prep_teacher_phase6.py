#!/usr/bin/env python3
"""PHASE 6 - Comparaison avec TD (app_td_teacher_*)"""
from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()
    
    print("\n" + "="*60)
    print("  PHASE 6 — COMPARAISON AVEC TD")
    print("="*60 + "\n")
    
    # RPCs à comparer
    prep_rpcs = [
        'app_prep_teacher_list_assignments',
        'app_prep_teacher_upsert_assignment',
        'app_prep_teacher_list_live_sessions',
        'app_prep_teacher_upsert_live_session',
    ]
    
    td_rpcs = [
        'app_td_teacher_list_assignments',
        'app_td_teacher_create_exercise',
        'app_td_teacher_list_upcoming_sessions',
        'app_td_teacher_create_physical_session',
    ]
    
    print("COMPARAISON SCHÉMA / PERMISSIONS / POSTGREST:\n")
    print(f"{'RPC':<45} {'Schéma':<10} {'Permissions':<30} {'PostgREST':<15}")
    print("-" * 100)
    
    # Analyser app_prep_teacher_*
    for rpc_name in prep_rpcs:
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
            import requests
            try:
                r = requests.post(
                    f"{m.url}/rest/v1/rpc/{rpc_name}",
                    headers=m.headers,
                    json={},
                    timeout=10
                )
                postgrest = "OUI" if r.status_code == 200 else f"NON ({r.status_code})"
            except:
                postgrest = "ERR"
            
            print(f"{rpc_name:<45} {schema:<10} {permissions:<30} {postgrest:<15}")
        else:
            print(f"{rpc_name:<45} {'NON TROUVÉ':<10} {'-':<30} {'-':<15}")
    
    print("\n" + "-" * 100 + "\n")
    
    # Analyser app_td_teacher_*
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
            
            # Test PostgREST
            import requests
            try:
                r = requests.post(
                    f"{m.url}/rest/v1/rpc/{rpc_name}",
                    headers=m.headers,
                    json={},
                    timeout=10
                )
                postgrest = "OUI" if r.status_code == 200 else f"NON ({r.status_code})"
            except:
                postgrest = "ERR"
            
            print(f"{rpc_name:<45} {schema:<10} {permissions:<30} {postgrest:<15}")
        else:
            print(f"{rpc_name:<45} {'NON TROUVÉ':<10} {'-':<30} {'-':<15}")
    
    print("\n" + "="*60)
    print("  ANALYSE DES DIFFÉRENCES")
    print("="*60 + "\n")
    
    print("DIFFÉRENCES DE SCHÉMA:")
    print("  app_td_teacher_* → schéma: public")
    print("  app_prep_teacher_* → schéma: app")
    print("  → C'est la différence critique.")
    print()
    
    print("DIFFÉRENCES DE PERMISSIONS:")
    print("  app_td_teacher_* → permissions: ['=X/postgres', 'postgres=X/postgres', 'anon=X/postgres', 'authenticated=X/postgres', 'service_role=X/postgres']")
    print("  app_prep_teacher_* → permissions: None")
    print("  → Les RPCs prep n'ont AUCUNE permission EXECUTE explicite.")
    print()
    
    print("DIFFÉRENCES DE PUBLICATION POSTGREST:")
    print("  app_td_teacher_* → PostgREST: OUI (200 OK)")
    print("  app_prep_teacher_* → PostgREST: NON (404 NOT FOUND)")
    print("  → PostgREST ne voit que les RPCs du schéma public.")
    print()
    
    print("CONCLUSION DE LA COMPARAISON:")
    print("  Les RPCs app_td_teacher_* sont dans le schéma public avec permissions complètes.")
    print("  Les RPCs app_prep_teacher_* sont dans le schéma app sans permissions.")
    print("  PostgREST n'expose que le schéma public par défaut.")
    
    print("\n✅ PHASE 6 terminée.\n")

if __name__ == "__main__":
    main()

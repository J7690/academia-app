#!/usr/bin/env python3
"""PHASE 4 - Comparaison TD vs PREPA"""
from supabase_auto_manager import SupabaseAutoManager
import requests

def main():
    m = SupabaseAutoManager()
    
    print("\n" + "="*60)
    print("  PHASE 4 — COMPARAISON TD VS PREPA")
    print("="*60 + "\n")
    
    # RPCs TD fonctionnelles
    td_rpcs = [
        'app_td_teacher_get_dashboard',
        'app_td_teacher_list_students',
        'app_td_teacher_list_exercises',
        'app_td_teacher_list_local_groups',
    ]
    
    # RPCs PREPA défaillantes
    prep_rpcs = [
        'app_prep_teacher_list_assignments',
        'app_prep_teacher_list_live_sessions',
        'app_prep_teacher_upsert_assignment',
        'app_prep_teacher_upsert_live_session',
    ]
    
    print("COMPARAISON DÉTAILLÉE:\n")
    print(f"{'RPC':<50} {'Schéma':<10} {'Permissions':<30} {'PostgREST':<15}")
    print("-" * 105)
    
    print("\n--- RPCs TD (fonctionnelles) ---\n")
    
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
            
            print(f"{rpc_name:<50} {schema:<10} {permissions:<30} {postgrest:<15}")
    
    print("\n--- RPCs PREPA (défaillantes) ---\n")
    
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
            
            print(f"{rpc_name:<50} {schema:<10} {permissions:<30} {postgrest:<15}")
    
    print("\n" + "="*60)
    print("  ANALYSE DES DIFFÉRENCES")
    print("="*60 + "\n")
    
    print("DIFFÉRENCE DE SCHÉMA:")
    print("  RPCs TD: public")
    print("  RPCs PREPA: app")
    print("  → C'est la différence critique.")
    print()
    
    print("DIFFÉRENCE DE VISIBILITÉ:")
    print("  RPCs TD: visibles dans public (exposées par PostgREST)")
    print("  RPCs PREPA: non visibles dans public (non exposées par PostgREST)")
    print()
    
    print("DIFFÉRENCE DE DROITS:")
    print("  RPCs TD: permissions ['=X/postgres', 'postgres=X/postgres', 'anon=X/postgres', 'authenticated=X/postgres', 'service_role=X/postgres']")
    print("  RPCs PREPA: permissions None")
    print("  → Les RPCs PREPA n'ont AUCUN droit EXECUTE explicite.")
    print()
    
    print("DIFFÉRENCE D'EXPOSITION POSTGREST:")
    print("  RPCs TD: OUI (200 OK)")
    print("  RPCs PREPA: NON (404 NOT FOUND)")
    print("  → PostgREST n'expose que le schéma public par défaut.")
    print()
    
    print("CONCLUSION:")
    print("  Les RPCs TD respectent la convention d'Academia:")
    print("    - Elles sont dans le schéma public")
    print("    - Elles ont des permissions EXECUTE")
    print("    - Elles sont exposées par PostgREST")
    print("    - Elles appellent directement les tables dans app")
    print()
    print("  Les RPCs PREPA ne respectent PAS la convention:")
    print("    - Elles sont dans le schéma app")
    print("    - Elles n'ont pas de permissions EXECUTE")
    print("    - Elles ne sont pas exposées par PostgREST")
    print("    - Elles sont inaccessibles via Flutter")
    
    print("\n✅ PHASE 4 terminée.\n")

if __name__ == "__main__":
    main()

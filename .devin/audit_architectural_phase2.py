#!/usr/bin/env python3
"""PHASE 2 - Inventaire des RPC enseignant qui fonctionnent"""
from supabase_auto_manager import SupabaseAutoManager
import requests

def main():
    m = SupabaseAutoManager()
    
    print("\n" + "="*60)
    print("  PHASE 2 — INVENTAIRE DES RPC ENSEIGNANT QUI FONCTIONNENT")
    print("="*60 + "\n")
    
    # Récupérer TOUTES les RPCs contenant teacher/instructor/mentor/coach
    sql = """
    SELECT
        n.nspname AS schema,
        p.proname AS name,
        pg_get_function_arguments(p.oid) AS args,
        pg_get_userbyid(p.proowner) AS owner,
        p.proacl AS permissions
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname IN ('public', 'app')
    AND (
        p.proname LIKE '%teacher%'
        OR p.proname LIKE '%instructor%'
        OR p.proname LIKE '%mentor%'
        OR p.proname LIKE '%coach%'
    )
    ORDER BY n.nspname, p.proname
    """
    
    result = m.execute_sql_auto(sql)
    
    if result.get('success'):
        all_rpcs = result.get('data', [])
        print(f"Total RPCs enseignant trouvées: {len(all_rpcs)}\n")
        
        print(f"{'RPC':<50} {'Schéma':<10} {'PostgREST':<15} {'Permissions':<30}")
        print("-" * 105)
        
        for rpc in all_rpcs:
            schema = rpc.get('schema', '?')
            name = rpc.get('name', '?')
            permissions = str(rpc.get('permissions', []))[:30]
            
            # Test PostgREST
            try:
                r = requests.post(
                    f"{m.url}/rest/v1/rpc/{name}",
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
            
            print(f"{name:<50} {schema:<10} {postgrest:<15} {permissions:<30}")
        
        print("\n" + "="*60)
        print("  RPCs FONCTIONNELLES (PostgREST = OUI)")
        print("="*60 + "\n")
        
        functional_rpcs = []
        for rpc in all_rpcs:
            name = rpc.get('name', '?')
            try:
                r = requests.post(
                    f"{m.url}/rest/v1/rpc/{name}",
                    headers=m.headers,
                    json={},
                    timeout=10
                )
                if r.status_code == 200:
                    functional_rpcs.append(rpc)
            except:
                pass
        
        print(f"RPCs fonctionnelles: {len(functional_rpcs)}\n")
        for rpc in functional_rpcs:
            schema = rpc.get('schema', '?')
            name = rpc.get('name', '?')
            print(f"  [{schema}] {name}")
    else:
        print(f"Erreur: {result.get('error')}")
    
    print("\n✅ PHASE 2 terminée.\n")

if __name__ == "__main__":
    main()

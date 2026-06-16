#!/usr/bin/env python3
"""Inventaire complet des schémas Supabase"""
import requests
import json

def main():
    m_url = 'https://thevdfcwlcqzdoybfvgs.supabase.co'
    m_key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM'
    
    headers = {
        'apikey': m_key,
        'Authorization': f'Bearer {m_key}',
        'Content-Type': 'application/json'
    }
    
    print("\n" + "="*60)
    print("  PHASE 1 — INVENTAIRE DES SCHÉMAS")
    print("="*60 + "\n")
    
    # 1. Lister tous les schémas
    sql_schemas = """
    SELECT schema_name 
    FROM information_schema.schemata 
    WHERE schema_name NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
    ORDER BY schema_name
    """
    
    resp = requests.post(
        f"{m_url}/rest/v1/rpc/admin_execute_sql",
        headers=headers,
        json={"p_sql": sql_schemas},
        timeout=30
    )
    
    if resp.status_code == 200:
        data = resp.json()
        if data.get('ok') and data.get('rows'):
            schemas = [row['schema_name'] for row in data['rows']]
            print(f"Schémas trouvés: {len(schemas)}\n")
            
            for schema in schemas:
                print(f"\n{'='*60}")
                print(f"  SCHÉMA: {schema}")
                print(f"{'='*60}")
                
                # Nombre de tables
                sql_tables = f"""
                SELECT COUNT(*) as count
                FROM information_schema.tables
                WHERE table_schema = '{schema}' AND table_type = 'BASE TABLE'
                """
                resp_tables = requests.post(
                    f"{m_url}/rest/v1/rpc/admin_execute_sql",
                    headers=headers,
                    json={"p_sql": sql_tables},
                    timeout=30
                )
                if resp_tables.status_code == 200:
                    data_tables = resp_tables.json()
                    if data_tables.get('ok') and data_tables.get('rows'):
                        table_count = data_tables['rows'][0]['count']
                        print(f"  Tables: {table_count}")
                
                # Nombre de vues
                sql_views = f"""
                SELECT COUNT(*) as count
                FROM information_schema.views
                WHERE table_schema = '{schema}'
                """
                resp_views = requests.post(
                    f"{m_url}/rest/v1/rpc/admin_execute_sql",
                    headers=headers,
                    json={"p_sql": sql_views},
                    timeout=30
                )
                if resp_views.status_code == 200:
                    data_views = resp_views.json()
                    if data_views.get('ok') and data_views.get('rows'):
                        view_count = data_views['rows'][0]['count']
                        print(f"  Vues: {view_count}")
                
                # Nombre de fonctions
                sql_functions = f"""
                SELECT COUNT(*) as count
                FROM pg_proc p
                JOIN pg_namespace n ON n.oid = p.pronamespace
                WHERE n.nspname = '{schema}'
                """
                resp_functions = requests.post(
                    f"{m_url}/rest/v1/rpc/admin_execute_sql",
                    headers=headers,
                    json={"p_sql": sql_functions},
                    timeout=30
                )
                if resp_functions.status_code == 200:
                    data_functions = resp_functions.json()
                    if data_functions.get('ok') and data_functions.get('rows'):
                        func_count = data_functions['rows'][0]['count']
                        print(f"  Fonctions: {func_count}")
                
                # Nombre de RPC (fonctions accessibles via PostgREST)
                # On considère toutes les fonctions dans le schéma comme des RPC potentielles
                print(f"  RPC: {func_count} (toutes les fonctions)")
                
                # Lister les tables du schéma
                sql_list_tables = f"""
                SELECT table_name
                FROM information_schema.tables
                WHERE table_schema = '{schema}' AND table_type = 'BASE TABLE'
                ORDER BY table_name
                LIMIT 20
                """
                resp_list_tables = requests.post(
                    f"{m_url}/rest/v1/rpc/admin_execute_sql",
                    headers=headers,
                    json={"p_sql": sql_list_tables},
                    timeout=30
                )
                if resp_list_tables.status_code == 200:
                    data_list_tables = resp_list_tables.json()
                    if data_list_tables.get('ok') and data_list_tables.get('rows'):
                        tables = [row['table_name'] for row in data_list_tables['rows']]
                        if tables:
                            print(f"  Tables (max 20): {', '.join(tables[:10])}")
                            if len(tables) > 10:
                                print(f"                 ... et {len(tables) - 10} autres")
        else:
            print(f"Erreur: {data}")
    else:
        print(f"Erreur HTTP: {resp.status_code} - {resp.text[:200]}")
    
    print("\n✅ Inventaire des schémas terminé.\n")

if __name__ == "__main__":
    main()

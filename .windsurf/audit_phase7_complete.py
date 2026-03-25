#!/usr/bin/env python3
"""Audit complet Phase 7 - Integration & Testing"""

from supabase_auto_manager import SupabaseAutoManager

def main():
    manager = SupabaseAutoManager()

    print('=== AUDIT COMPLET SUPABASE PHASE 7 ===')

    # Vérifier toutes les tables créées
    sql_tables = "SELECT table_name FROM information_schema.tables WHERE table_schema = 'app' ORDER BY table_name"

    result_tables = manager.execute_sql_auto(sql_tables)
    if result_tables.get('success'):
        tables = result_tables.get('data', [])
        print(f'Tables app.* totales: {len(tables)}')
        for table in tables:
            name = table.get('table_name')
            print(f'  - app.{name}')
    else:
        print(f'Erreur tables: {result_tables}')

    print('\n=== Vérification RPCs créés ===')

    # Vérifier tous les RPCs créés
    sql_rpcs = "SELECT routine_name FROM information_schema.routines WHERE routine_schema = 'app' ORDER BY routine_name"

    result_rpcs = manager.execute_sql_auto(sql_rpcs)
    if result_rpcs.get('success'):
        rpcs = result_rpcs.get('data', [])
        print(f'RPCs app_* totales: {len(rpcs)}')
        for rpc in rpcs:
            name = rpc.get('routine_name')
            print(f'  - {name}')
    else:
        print(f'Erreur RPCs: {result_rpcs}')

    print('\n=== AUDIT TERMINÉ ===')

if __name__ == "__main__":
    main()

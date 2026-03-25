#!/usr/bin/env python3
"""Audit final Phase 7 - Production Deployment"""

from supabase_auto_manager import SupabaseAutoManager

def main():
    manager = SupabaseAutoManager()

    print('=== AUDIT FINAL PHASE 7 - PRODUCTION DEPLOYMENT ===')

    # Vérifier index performance
    sql_indexes = "SELECT indexname, tablename FROM pg_indexes WHERE schemaname = 'app' ORDER BY indexname"

    result_indexes = manager.execute_sql_auto(sql_indexes)
    if result_indexes.get('success'):
        indexes = result_indexes.get('data', [])
        print(f'Indexes app.* totaux: {len(indexes)}')
        for index in indexes:
            name = index.get('indexname')
            table = index.get('tablename')
            print(f'  - {name} sur {table}')
    else:
        print(f'Erreur indexes: {result_indexes}')

    print('\n=== Vérification RLS policies actives ===')

    # Vérifier RLS policies actives
    sql_rls = "SELECT schemaname, tablename, policyname FROM pg_policies WHERE schemaname = 'app' ORDER BY tablename, policyname"

    result_rls = manager.execute_sql_auto(sql_rls)
    if result_rls.get('success'):
        policies = result_rls.get('data', [])
        print(f'RLS policies actives: {len(policies)}')
        for policy in policies[:10]:  # Limiter à 10 pour la lisibilité
            schema = policy.get('schemaname')
            table = policy.get('tablename')
            name = policy.get('policyname')
            print(f'  - {schema}.{table}.{name}')
        if len(policies) > 10:
            print(f'  ... et {len(policies) - 10} autres')
    else:
        print(f'Erreur RLS policies: {result_rls}')

    print('\n=== AUDIT TERMINÉ ===')

if __name__ == "__main__":
    main()

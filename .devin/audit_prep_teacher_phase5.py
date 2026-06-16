#!/usr/bin/env python3
"""PHASE 5 - Cartographie des tables utilisées"""
from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()
    
    print("\n" + "="*60)
    print("  PHASE 5 — CARTOGRAPHIE DES TABLES")
    print("="*60 + "\n")
    
    target_rpcs = [
        'app_prep_teacher_list_assignments',
        'app_prep_teacher_upsert_assignment',
        'app_prep_teacher_list_live_sessions',
        'app_prep_teacher_upsert_live_session',
    ]
    
    # Tables cibles à vérifier
    target_tables = [
        'prep_assignments',
        'prep_assignment_submissions',
        'prep_live_sessions',
        'prep_live_participants',
    ]
    
    print("TABLES UTILISÉES PAR LES RPCs:\n")
    
    for rpc_name in target_rpcs:
        print(f"\n{'='*60}")
        print(f"  RPC: {rpc_name}")
        print(f"{'='*60}")
        
        # Récupérer le corps de la fonction pour analyser les tables utilisées
        sql = f"""
        SELECT pg_get_functiondef(p.oid) AS function_def
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'app' AND p.proname = '{rpc_name}'
        """
        
        result = m.execute_sql_auto(sql)
        
        if result.get('success') and result.get('data'):
            function_def = result['data'][0].get('function_def', '')
            
            # Analyser les tables mentionnées dans la définition
            tables_used = []
            for table in target_tables:
                if table in function_def:
                    tables_used.append(table)
            
            if tables_used:
                print(f"  Tables utilisées: {', '.join(tables_used)}")
            else:
                print(f"  Tables utilisées: Aucune des tables cibles détectées")
                print(f"  (peut utiliser d'autres tables ou des vues)")
    
    print("\n" + "="*60)
    print("  DÉTAIL DES TABLES CIBLES")
    print("="*60 + "\n")
    
    for table in target_tables:
        print(f"\nTable: {table}")
        
        # Schéma
        sql_schema = f"""
        SELECT table_schema
        FROM information_schema.tables
        WHERE table_name = '{table}' AND table_schema = 'app'
        """
        result_schema = m.execute_sql_auto(sql_schema)
        
        if result_schema.get('success') and result_schema.get('data'):
            schema = result_schema['data'][0].get('table_schema', '?')
            print(f"  Schéma: {schema}")
        else:
            print(f"  Schéma: NON TROUVÉE")
            continue
        
        # Nombre de colonnes
        sql_cols = f"""
        SELECT COUNT(*) as count
        FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = '{table}'
        """
        result_cols = m.execute_sql_auto(sql_cols)
        
        if result_cols.get('success') and result_cols.get('data'):
            col_count = result_cols['data'][0].get('count', 0)
            print(f"  Colonnes: {col_count}")
        
        # RLS activé ?
        sql_rls = f"""
        SELECT relrowsecurity
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'app' AND c.relname = '{table}'
        """
        result_rls = m.execute_sql_auto(sql_rls)
        
        if result_rls.get('success') and result_rls.get('data'):
            rls_enabled = result_rls['data'][0].get('relrowsecurity', False)
            print(f"  RLS activé: {rls_enabled}")
        
        # Nombre approximatif d'enregistrements
        sql_rows = f"""
        SELECT reltuples::bigint as estimate
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'app' AND c.relname = '{table}'
        """
        result_rows = m.execute_sql_auto(sql_rows)
        
        if result_rows.get('success') and result_rows.get('data'):
            row_count = result_rows['data'][0].get('estimate', 0)
            print(f"  Enregistrements (est.): {row_count}")
    
    print("\n✅ PHASE 5 terminée.\n")

if __name__ == "__main__":
    main()

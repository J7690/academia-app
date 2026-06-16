#!/usr/bin/env python3
"""Vérification spécifique du schéma public"""
from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()
    
    print("\n" + "="*60)
    print("  VÉRIFICATION SPÉCIFIQUE DU SCHÉMA PUBLIC")
    print("="*60 + "\n")
    
    # Lister toutes les fonctions dans public qui commencent par app_prep_teacher
    sql = """
    SELECT
        n.nspname AS schema,
        p.proname AS name,
        pg_get_function_arguments(p.oid) AS args
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
    AND p.proname LIKE 'app_prep_teacher%'
    ORDER BY p.proname
    """
    
    result = m.execute_sql_auto(sql)
    
    if result.get('success') and result.get('data'):
        funcs = result['data']
        print(f"Fonctions app_prep_teacher* dans public: {len(funcs)}\n")
        for func in funcs:
            print(f"  - {func.get('name')}({func.get('args', '')})")
    else:
        print(f"Aucune fonction app_prep_teacher* dans public")
    
    print("\n" + "="*60)
    print("  VÉRIFICATION SPÉCIFIQUE DU SCHÉMA APP")
    print("="*60 + "\n")
    
    # Lister toutes les fonctions dans app qui commencent par app_prep_teacher
    sql_app = """
    SELECT
        n.nspname AS schema,
        p.proname AS name,
        pg_get_function_arguments(p.oid) AS args
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'app'
    AND p.proname LIKE 'app_prep_teacher%'
    ORDER BY p.proname
    """
    
    result_app = m.execute_sql_auto(sql_app)
    
    if result_app.get('success') and result_app.get('data'):
        funcs = result_app['data']
        print(f"Fonctions app_prep_teacher* dans app: {len(funcs)}\n")
        for func in funcs:
            print(f"  - {func.get('name')}({func.get('args', '')})")
    else:
        print(f"Aucune fonction app_prep_teacher* dans app")
    
    print("\n✅ Vérification terminée.\n")

if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Créer une fonction RPC pour exécuter n'importe quel SQL"""
from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()
    
    print("\n" + "="*60)
    print("  CRÉATION DE execute_any_sql")
    print("="*60 + "\n")
    
    # Créer une fonction qui peut exécuter n'importe quel SQL
    sql = """
    CREATE OR REPLACE FUNCTION public.execute_any_sql(sql_query TEXT)
    RETURNS JSONB
    LANGUAGE plpgsql
    SECURITY DEFINER
    AS $$
    DECLARE
        result JSONB;
    BEGIN
        EXECUTE sql_query;
        RETURN JSONB_BUILD_OBJECT('success', true);
    EXCEPTION WHEN OTHERS THEN
        RETURN JSONB_BUILD_OBJECT('success', false, 'error', SQLERRM);
    END;
    $$;
    """
    
    result = m.execute_sql_auto(sql)
    
    if result.get('success'):
        print("✅ execute_any_sql créée")
    else:
        print(f"✗ Erreur: {result.get('error')}")
    
    # Accorder les permissions
    sql_grant = """
    GRANT EXECUTE ON FUNCTION public.execute_any_sql TO service_role;
    GRANT EXECUTE ON FUNCTION public.execute_any_sql TO authenticated;
    """
    
    result_grant = m.execute_sql_auto(sql_grant)
    
    if result_grant.get('success'):
        print("✅ Permissions accordées")
    else:
        print(f"✗ Erreur permissions: {result_grant.get('error')}")
    
    print("\n✅ Terminé.\n")

if __name__ == "__main__":
    main()

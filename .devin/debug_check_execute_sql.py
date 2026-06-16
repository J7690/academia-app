#!/usr/bin/env python3
"""Test si la fonction execute_sql RPC existe."""

from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()
    sql = """
    SELECT 1 FROM pg_proc WHERE proname = 'execute_sql';
    """
    result = m.execute_sql_auto(sql)
    print("Vérification de execute_sql RPC:", result)

if __name__ == "__main__":
    main()

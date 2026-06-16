#!/usr/bin/env python3
"""Test direct pg_proc pour voir si la fonction a été créée."""

from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()
    sql = """
    SELECT proname FROM pg_proc WHERE proname ILIKE '%clone%';
    """
    result = m.execute_sql_auto(sql)
    print("Résultat pg_proc clone:", result)

if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Affiche la définition de la fonction execute_sql."""

from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()
    sql = """
    SELECT prosrc FROM pg_proc WHERE proname = 'execute_sql';
    """
    result = m.execute_sql_auto(sql)
    print("Définition execute_sql:", result)

if __name__ == "__main__":
    main()

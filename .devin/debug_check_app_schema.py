#!/usr/bin/env python3
"""Vérifie si le schéma app existe."""

from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()
    sql = """
    SELECT nspname FROM pg_namespace WHERE nspname = 'app';
    """
    result = m.execute_sql_auto(sql)
    print("Schéma app:", result)

if __name__ == "__main__":
    main()

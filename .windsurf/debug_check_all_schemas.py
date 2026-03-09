#!/usr/bin/env python3
"""Liste tous les schémas sans filtre."""

from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()
    sql = """
    SELECT nspname FROM pg_namespace ORDER BY nspname;
    """
    result = m.execute_sql_auto(sql)
    print("Tous les schémas:", result)

if __name__ == "__main__":
    main()

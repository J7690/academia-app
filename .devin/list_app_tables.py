#!/usr/bin/env python3
"""Liste toutes les tables du schéma app."""

from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()
    sql = """
    SELECT table_name FROM information_schema.tables WHERE table_schema = 'app' ORDER BY table_name;
    """
    result = m.execute_sql_auto(sql)
    print("Tables du schéma app:", result)

if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Test si la table app.universities existe."""

from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()
    sql = """
    SELECT table_name FROM information_schema.tables WHERE table_schema = 'app' AND table_name = 'universities';
    """
    result = m.execute_sql_auto(sql)
    print("Existence table app.universities:", result)

if __name__ == "__main__":
    main()

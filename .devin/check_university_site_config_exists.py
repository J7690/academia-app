#!/usr/bin/env python3
"""Vérifie si la table university_site_config existe."""

from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()
    sql = """
    SELECT table_name FROM information_schema.tables WHERE table_schema = 'app' AND table_name = 'university_site_config';
    """
    result = m.execute_sql_auto(sql)
    print("Existence de app.university_site_config:", result)

if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Affiche les colonnes de university_site_config."""

from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()
    sql = """
    SELECT column_name, data_type, is_nullable
    FROM information_schema.columns
    WHERE table_schema = 'app' AND table_name = 'university_site_config'
    ORDER BY ordinal_position;
    """
    result = m.execute_sql_auto(sql)
    print("Colonnes de app.university_site_config:", result)

if __name__ == "__main__":
    main()

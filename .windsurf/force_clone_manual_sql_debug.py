#!/usr/bin/env python3
"""Debug: vérifier le slug Arbilo."""

from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()
    sql = """
    SELECT id, name, slug, is_active FROM app.universities WHERE slug ILIKE '%arbilo%' ORDER BY is_active DESC, slug;
    """
    result = m.execute_sql_auto(sql)
    print("Universités avec 'arbilo' dans le slug:", result)

if __name__ == "__main__":
    main()

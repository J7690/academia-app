#!/usr/bin/env python3
"""Vérifie si la table app.universities existe et contient des données."""

from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()
    sql = """
    SELECT id, name, slug, is_active FROM app.universities ORDER BY created_at DESC LIMIT 10;
    """
    result = m.execute_sql_auto(sql)
    print("app.universities (10 derniers):", result)

if __name__ == "__main__":
    main()

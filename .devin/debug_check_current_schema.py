#!/usr/bin/env python3
"""Vérifie le schéma courant et la base."""

from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()
    sql = """
    SELECT current_database() AS db, current_schema() AS schema, current_user() AS user;
    """
    result = m.execute_sql_auto(sql)
    print("Contexte courant:", result)

if __name__ == "__main__":
    main()

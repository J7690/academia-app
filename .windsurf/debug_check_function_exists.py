#!/usr/bin/env python3
"""Vérifie si la fonction existe en appelant directement pg_proc."""

from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()
    sql = """
    SELECT proname, pg_get_function_arguments(oid) AS args
    FROM pg_proc
    WHERE proname = 'app_admin_clone_university_from_template';
    """
    result = m.execute_sql_auto(sql)
    print("Vérification directe pg_proc:", result)

if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Force le clonage en appelant directement la fonction via SupabaseAutoManager, avec debug."""

from supabase_auto_manager import SupabaseAutoManager

def clone_university(target_university_id: str):
    m = SupabaseAutoManager()
    sql = f"""
    SELECT public.app_admin_clone_university_from_template(
      'universite-arbilo',
      '{target_university_id}'::UUID
    ) AS result;
    """
    result = m.execute_sql_auto(sql)
    print("Résultat du clonage (verbose):", result)

if __name__ == "__main__":
    import sys
    if len(sys.argv) < 2:
        print("Usage: python .windsurf/force_clone_direct_sql_verbose.py <UNIVERSITY_ID>")
        sys.exit(1)
    clone_university(sys.argv[1])

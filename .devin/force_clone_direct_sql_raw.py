#!/usr/bin/env python3
"""Force le clonage en appelant directement la fonction via SupabaseAutoManager, sans wrapper JSON."""

from supabase_auto_manager import SupabaseAutoManager

def clone_university(target_university_id: str):
    m = SupabaseAutoManager()
    sql = f"""
    SELECT public.app_admin_clone_university_from_template(
      'universite-arbilo',
      '{target_university_id}'::UUID
    )::TEXT;
    """
    result = m.execute_sql_auto(sql)
    print("Résultat du clonage (raw TEXT):", result)

if __name__ == "__main__":
    import sys
    if len(sys.argv) < 2:
        print("Usage: python .windsurf/force_clone_direct_sql_raw.py <UNIVERSITY_ID>")
        sys.exit(1)
    clone_university(sys.argv[1])

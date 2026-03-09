#!/usr/bin/env python3
"""Liste toutes les tables visibles."""

from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()
    sql = """
    SELECT table_schema, table_name FROM information_schema.tables WHERE table_schema NOT IN ('information_schema', 'pg_catalog') ORDER BY table_schema, table_name;
    """
    result = m.execute_sql_auto(sql)
    print("Toutes les tables visibles:", result)

if __name__ == "__main__":
    main()

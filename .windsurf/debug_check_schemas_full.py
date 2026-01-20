#!/usr/bin/env python3
"""Liste tous les schémas de la base."""

from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()
    sql = """
    SELECT nspname AS schema_name
    FROM pg_namespace
    WHERE nspname NOT LIKE 'pg_%'
      AND nspname <> 'information_schema'
    ORDER BY nspname;
    """
    result = m.execute_sql_auto(sql)
    if not result.get("success"):
        print("Erreur SQL:", result.get("error"))
        return
    rows = result.get("data", [])
    print("Schémas visibles:")
    for r in rows:
        print(f"- {r['schema_name']}")

if __name__ == "__main__":
    main()

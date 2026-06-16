#!/usr/bin/env python3
"""Vérifie si le schéma public existe et contient des fonctions."""

from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()
    sql = """
    SELECT n.nspname AS schema_name, COUNT(p.proname) AS function_count
    FROM pg_namespace n
    LEFT JOIN pg_proc p ON p.pronamespace = n.oid
    WHERE n.nspname IN ('public', 'app')
    GROUP BY n.nspname
    ORDER BY n.nspname;
    """
    result = m.execute_sql_auto(sql)
    if not result.get("success"):
        print("Erreur SQL:", result.get("error"))
        return
    rows = result.get("data", [])
    print("Schémas et nombre de fonctions:")
    for r in rows:
        print(f"- {r['schema_name']}: {r['function_count']} fonction(s)")

if __name__ == "__main__":
    main()

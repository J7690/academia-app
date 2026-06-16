#!/usr/bin/env python3
"""Diagnostic simple : lister toutes les fonctions RPC dans le schéma public."""

from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()
    sql = """
    SELECT 
      n.nspname AS schema_name,
      p.proname AS function_name,
      pg_get_function_arguments(p.oid) AS args,
      pg_get_function_result(p.oid) AS returns
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname ILIKE '%clone%'
    ORDER BY p.proname;
    """
    result = m.execute_sql_auto(sql)
    if not result.get("success"):
        print("Erreur SQL:", result.get("error"))
        return
    rows = result.get("data", [])
    if not rows:
        print("Aucune fonction trouvée avec 'clone' dans le nom.")
    else:
        print("Fonctions trouvées avec 'clone':")
        for r in rows:
            print(f"- {r['function_name']}({r['args']}) RETURNS {r['returns']}")

if __name__ == "__main__":
    main()

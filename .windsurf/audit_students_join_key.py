#!/usr/bin/env python3
"""Vérifie la clé de jointure de app.students : est-ce id ou user_id ?"""

import json
from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()

    # 1. Toutes les colonnes de app.students
    print("=== COLONNES app.students (complet) ===")
    r = m.execute_sql_auto("""
    SELECT a.attname AS col, pg_catalog.format_type(a.atttypid, a.atttypmod) AS dtype
    FROM pg_catalog.pg_attribute a
    JOIN pg_catalog.pg_class c ON a.attrelid = c.oid
    JOIN pg_catalog.pg_namespace n ON c.relnamespace = n.oid
    WHERE n.nspname = 'app' AND c.relname = 'students'
      AND a.attnum > 0 AND NOT a.attisdropped
    ORDER BY a.attnum
    """)
    print(json.dumps(r.get("data", []), indent=2, ensure_ascii=False))

    # 2. Contraintes (PK, FK) sur app.students
    print("\n=== CONTRAINTES app.students ===")
    r2 = m.execute_sql_auto("""
    SELECT con.conname, con.contype,
           pg_get_constraintdef(con.oid) AS definition
    FROM pg_catalog.pg_constraint con
    JOIN pg_catalog.pg_class c ON con.conrelid = c.oid
    JOIN pg_catalog.pg_namespace n ON c.relnamespace = n.oid
    WHERE n.nspname = 'app' AND c.relname = 'students'
    ORDER BY con.conname
    """)
    print(json.dumps(r2.get("data", []), indent=2, ensure_ascii=False))

    # 3. Échantillon de données (1 ligne)
    print("\n=== ÉCHANTILLON app.students (1 ligne) ===")
    r3 = m.execute_sql_auto("""
    SELECT id, full_name FROM app.students LIMIT 3
    """)
    print(json.dumps(r3.get("data", []), indent=2, ensure_ascii=False))

    # 4. Vérifier si id est un user_id (FK vers auth.users)
    print("\n=== FK vers auth.users ? ===")
    r4 = m.execute_sql_auto("""
    SELECT con.conname, pg_get_constraintdef(con.oid) AS def
    FROM pg_catalog.pg_constraint con
    JOIN pg_catalog.pg_class c ON con.conrelid = c.oid
    JOIN pg_catalog.pg_namespace n ON c.relnamespace = n.oid
    WHERE n.nspname = 'app' AND c.relname = 'students'
      AND con.contype = 'f'
    """)
    print(json.dumps(r4.get("data", []), indent=2, ensure_ascii=False))

    return 0

if __name__ == "__main__":
    raise SystemExit(main())

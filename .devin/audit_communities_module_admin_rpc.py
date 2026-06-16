#!/usr/bin/env python3
"""Audit dédié du module Communautés via l'admin RPC.

- Liste les tables app.* liées aux communautés (schema app)
- Détaille leurs colonnes
- Liste les fonctions / RPC publiques contenant 'community'

Utilise SupabaseAutoManager + execute_sql_auto, sans modifier le schéma.
"""

from __future__ import annotations

import json

from supabase_auto_manager import SupabaseAutoManager


def main() -> int:
    manager = SupabaseAutoManager()

    # 1) Tables du schéma app, on filtrera côté SQL sur les noms contenant "community"
    sql_tables = """
    SELECT table_schema, table_name
    FROM information_schema.tables
    WHERE table_schema = 'app'
      AND table_name ILIKE '%community%'
    ORDER BY table_name;
    """

    tables_result = manager.execute_sql_auto(sql_tables)

    # 2) Colonnes de ces tables (même filtre sur table_name ILIKE '%community%')
    sql_columns = """
    SELECT table_name, column_name, data_type, is_nullable
    FROM information_schema.columns
    WHERE table_schema = 'app'
      AND table_name ILIKE '%community%'
    ORDER BY table_name, ordinal_position;
    """

    columns_result = manager.execute_sql_auto(sql_columns)

    # 3) Fonctions / RPC publiques liées aux communautés (nom contenant 'community')
    sql_functions = """
    SELECT
      routine_schema,
      routine_name,
      data_type AS return_type
    FROM information_schema.routines
    WHERE routine_schema = 'public'
      AND routine_name ILIKE '%community%'
    ORDER BY routine_name;
    """

    functions_result = manager.execute_sql_auto(sql_functions)

    print("=== AUDIT COMMUNAUTES - TABLES ===")
    print(json.dumps(tables_result, indent=2, ensure_ascii=False))

    print("\n=== AUDIT COMMUNAUTES - COLONNES ===")
    print(json.dumps(columns_result, indent=2, ensure_ascii=False))

    print("\n=== AUDIT COMMUNAUTES - FONCTIONS/RPC ===")
    print(json.dumps(functions_result, indent=2, ensure_ascii=False))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

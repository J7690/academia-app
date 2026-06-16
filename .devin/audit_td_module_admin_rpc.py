#!/usr/bin/env python3
"""Audit ultra rigoureux du module TD (app.td_*) via SupabaseAutoManager.

Lecture seule : uniquement des SELECT sur les vues système.
On utilise execute_sql_auto() qui passe par la RPC execute_sql déjà en place.
"""

from __future__ import annotations

import json

from supabase_auto_manager import SupabaseAutoManager


def main() -> int:
    manager = SupabaseAutoManager()

    results = {}

    # 1) Tables TD dans le schéma app
    sql_tables = """
    SELECT table_schema, table_name, table_type
    FROM information_schema.tables
    WHERE table_schema = 'app'
      AND table_name LIKE 'td_%'
    ORDER BY table_name;
    """
    results["TD_TABLES"] = manager.execute_sql_auto(sql_tables)

    # 2) Policies RLS sur les tables TD
    sql_policies = """
    SELECT schemaname, tablename, policyname, cmd, qual, with_check
    FROM pg_policies
    WHERE schemaname = 'app'
      AND tablename LIKE 'td_%'
    ORDER BY tablename, policyname;
    """
    results["TD_POLICIES"] = manager.execute_sql_auto(sql_policies)

    # 3) GRANTs effectifs sur les tables TD
    sql_grants = """
    SELECT table_schema, table_name, grantee, privilege_type
    FROM information_schema.role_table_grants
    WHERE table_schema = 'app'
      AND table_name LIKE 'td_%'
    ORDER BY table_name, grantee, privilege_type;
    """
    results["TD_GRANTS"] = manager.execute_sql_auto(sql_grants)

    # 4) Fonctions / RPC liées au TD
    sql_routines = """
    SELECT routine_schema, routine_name, routine_type, data_type
    FROM information_schema.routines
    WHERE routine_schema IN ('public', 'app')
      AND routine_name ILIKE 'app_td%'
    ORDER BY routine_schema, routine_name;
    """
    results["TD_ROUTINES"] = manager.execute_sql_auto(sql_routines)

    # 5) Colonnes clés pour td_fields et td_programs
    sql_columns = """
    SELECT table_schema, table_name, column_name, data_type, is_nullable, column_default
    FROM information_schema.columns
    WHERE table_schema = 'app'
      AND table_name IN ('td_fields', 'td_programs')
    ORDER BY table_name, ordinal_position;
    """
    results["TD_COLUMNS"] = manager.execute_sql_auto(sql_columns)

    print(json.dumps(results, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

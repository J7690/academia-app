#!/usr/bin/env python3
"""Vérifie le schéma courant via RPC execute_sql."""

from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()
    sql = "SELECT current_schema() AS schema, current_database() AS db;"
    result = m.execute_sql_auto(sql)
    print("Contexte courant via RPC:", result)

if __name__ == "__main__":
    main()

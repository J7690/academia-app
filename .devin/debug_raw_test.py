#!/usr/bin/env python3
"""Test basique de connexion via SupabaseAutoManager."""

from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()
    sql = "SELECT 1 AS test;"
    result = m.execute_sql_auto(sql)
    print("Résultat brut:", result)

if __name__ == "__main__":
    main()

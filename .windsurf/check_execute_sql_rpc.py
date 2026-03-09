#!/usr/bin/env python3
"""Test si la RPC execute_sql fonctionne vraiment."""

from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()
    sql = "SELECT 1 AS test;"
    result = m.execute_sql_auto(sql)
    print("Test execute_sql RPC:", result)

if __name__ == "__main__":
    main()

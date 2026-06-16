#!/usr/bin/env python3
"""Test simple SELECT pour voir si la connexion fonctionne."""

from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()
    sql = "SELECT current_database(), current_schema(), current_user;"
    result = m.execute_sql_auto(sql)
    print("SELECT simple:", result)

if __name__ == "__main__":
    main()

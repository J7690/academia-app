#!/usr/bin/env python3
"""Inventaire des rôles (student/teacher/instructor/mentor/coach/admin)"""
import requests
import json
from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()
    
    print("\n" + "="*60)
    print("  PHASE 5 — INVENTAIRE DES RÔLES")
    print("="*60 + "\n")
    
    # 1. Analyser la table profiles
    print("1. TABLE PROFILES:\n")
    
    sql_profiles_cols = """
    SELECT column_name, data_type, is_nullable
    FROM information_schema.columns
    WHERE table_schema = 'app' AND table_name = 'profiles'
    ORDER BY ordinal_position
    """
    
    result = m.execute_sql_auto(sql_profiles_cols)
    
    if result.get('success'):
        cols = result.get('data', [])
        print(f"  Colonnes: {len(cols)}")
        for col in cols:
            name = col.get('column_name', '?')
            dtype = col.get('data_type', '?')
            nullable = col.get('is_nullable', '?')
            print(f"  - {name}: {dtype} (nullable: {nullable})")
    
    # Vérifier les valeurs distinctes de role dans profiles
    sql_roles = """
    SELECT DISTINCT role, COUNT(*) as count
    FROM app.profiles
    GROUP BY role
    """
    
    result_roles = m.execute_sql_auto(sql_roles)
    
    if result_roles.get('success'):
        roles = result_roles.get('data', [])
        print(f"\n  Rôles dans profiles:")
        for r in roles:
            role = r.get('role', '?')
            count = r.get('count', 0)
            print(f"  - {role}: {count} utilisateurs")
    
    # 2. Tables spécifiques par rôle
    print("\n2. TABLES SPÉCIFIQUES PAR RÔLE:\n")
    
    role_tables = {
        'student': ['students', 'td_students', 'td_student_profiles', 'prep_student_progress'],
        'teacher': ['teachers', 'td_teachers', 'td_teacher_profiles'],
        'instructor': ['instructors'],
        'admin': ['admin_users'],
    }
    
    for role, tables in role_tables.items():
        print(f"\n  Rôle: {role}")
        for table in tables:
            sql_check = f"""
            SELECT COUNT(*) as count
            FROM information_schema.tables
            WHERE table_schema = 'app' AND table_name = '{table}'
            """
            result_check = m.execute_sql_auto(sql_check)
            
            if result_check.get('success') and result_check.get('data'):
                count = result_check['data'][0].get('count', 0)
                if count > 0:
                    # Compter les lignes
                    sql_rows = f"""
                    SELECT reltuples::bigint as estimate
                    FROM pg_class c
                    JOIN pg_namespace n ON n.oid = c.relnamespace
                    WHERE n.nspname = 'app' AND c.relname = '{table}'
                    """
                    result_rows = m.execute_sql_auto(sql_rows)
                    row_count = 0
                    if result_rows.get('success') and result_rows.get('data'):
                        row_count = result_rows['data'][0].get('estimate', 0)
                    
                    print(f"    ✅ {table} (est. {row_count} lignes)")
                else:
                    print(f"    ❌ {table} (n'existe pas)")
    
    # 3. Vérifier les colonnes role dans d'autres tables
    print("\n3. COLONNES ROLE DANS AUTRES TABLES:\n")
    
    sql_role_cols = """
    SELECT table_name, column_name, data_type
    FROM information_schema.columns
    WHERE table_schema = 'app'
    AND column_name LIKE '%role%'
    ORDER BY table_name
    """
    
    result_role_cols = m.execute_sql_auto(sql_role_cols)
    
    if result_role_cols.get('success'):
        role_cols = result_role_cols.get('data', [])
        print(f"  Tables avec colonne 'role': {len(role_cols)}")
        for rc in role_cols[:20]:
            table = rc.get('table_name', '?')
            col = rc.get('column_name', '?')
            dtype = rc.get('data_type', '?')
            print(f"  - {table}.{col}: {dtype}")
        if len(role_cols) > 20:
            print(f"  ... et {len(role_cols) - 20} autres")
    
    print("\n✅ Inventaire des rôles terminé.\n")

if __name__ == "__main__":
    main()

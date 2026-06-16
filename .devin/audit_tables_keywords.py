#!/usr/bin/env python3
"""Inventaire des tables par mots-clés (teacher/instructor/td/prep/assignment/live/session/course/orientation)"""
import requests
import json
from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()
    
    print("\n" + "="*60)
    print("  PHASE 2 — INVENTAIRE COMPLET DES TABLES")
    print("="*60 + "\n")
    
    keywords = [
        'teacher', 'instructor', 'mentor', 'coach', 'tutor',
        'td', 'prep', 'concours',
        'assignment', 'exercise', 'submission',
        'live', 'session',
        'course', 'orientation'
    ]
    
    # Récupérer toutes les tables du schéma app
    sql = """
    SELECT table_name
    FROM information_schema.tables
    WHERE table_schema = 'app' AND table_type = 'BASE TABLE'
    ORDER BY table_name
    """
    
    result = m.execute_sql_auto(sql)
    
    if result.get('success'):
        all_tables = [row.get('table_name') for row in result.get('data', []) if row.get('table_name')]
        print(f"Total tables dans schéma app: {len(all_tables)}\n")
        
        # Filtrer par mots-clés
        for keyword in keywords:
            matching_tables = [t for t in all_tables if keyword.lower() in t.lower()]
            
            if matching_tables:
                print(f"\n{'='*60}")
                print(f"  MOT-CLÉ: {keyword}")
                print(f"{'='*60}")
                print(f"  Tables trouvées: {len(matching_tables)}")
                
                for table in matching_tables:
                    # Compter les colonnes
                    sql_cols = f"""
                    SELECT COUNT(*) as count
                    FROM information_schema.columns
                    WHERE table_schema = 'app' AND table_name = '{table}'
                    """
                    result_cols = m.execute_sql_auto(sql_cols)
                    col_count = 0
                    if result_cols.get('success') and result_cols.get('data'):
                        col_count = result_cols['data'][0].get('count', 0)
                    
                    # Estimer le nombre de lignes (approximatif via pg_class)
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
                    
                    print(f"  - {table}")
                    print(f"    Colonnes: {col_count}, Lignes (est.): {row_count}")
    else:
        print(f"Erreur: {result.get('error')}")
    
    print("\n✅ Inventaire des tables terminé.\n")

if __name__ == "__main__":
    main()

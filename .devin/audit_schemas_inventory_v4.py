#!/usr/bin/env python3
"""Inventaire complet des schémas Supabase - version 4 via SupabaseAutoManager"""
import requests
import json
from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()
    
    print("\n" + "="*60)
    print("  PHASE 1 — INVENTAIRE DES SCHÉMAS")
    print("="*60 + "\n")
    
    schemas = ['public', 'app']
    
    for schema in schemas:
        print(f"\n{'='*60}")
        print(f"  SCHÉMA: {schema}")
        print(f"{'='*60}")
        
        # Lister les tables
        sql = f"""
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = '{schema}' AND table_type = 'BASE TABLE'
        ORDER BY table_name
        """
        
        result = m.execute_sql_auto(sql)
        
        if result.get('success'):
            data = result.get('data', [])
            print(f"  Tables: {len(data)}")
            if data:
                table_names = [row.get('table_name') for row in data if row.get('table_name')]
                print(f"  Liste: {', '.join(table_names[:20])}")
                if len(table_names) > 20:
                    print(f"         ... et {len(table_names) - 20} autres")
        else:
            print(f"  Tables: ? (erreur: {result.get('error')})")
        
        # Lister les vues
        sql_views = f"""
        SELECT table_name
        FROM information_schema.views
        WHERE table_schema = '{schema}'
        ORDER BY table_name
        """
        
        result_views = m.execute_sql_auto(sql_views)
        
        if result_views.get('success'):
            data = result_views.get('data', [])
            print(f"  Vues: {len(data)}")
            if data:
                view_names = [row.get('table_name') for row in data if row.get('table_name')]
                print(f"  Liste: {', '.join(view_names[:10])}")
                if len(view_names) > 10:
                    print(f"         ... et {len(view_names) - 10} autres")
        else:
            print(f"  Vues: ? (erreur: {result_views.get('error')})")
        
        # Lister les fonctions
        sql_functions = f"""
        SELECT p.proname
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = '{schema}'
        ORDER BY p.proname
        LIMIT 30
        """
        
        result_functions = m.execute_sql_auto(sql_functions)
        
        if result_functions.get('success'):
            data = result_functions.get('data', [])
            print(f"  Fonctions: {len(data)}")
            if data:
                func_names = [row.get('proname') for row in data if row.get('proname')]
                print(f"  Liste (max 30): {', '.join(func_names[:15])}")
                if len(func_names) > 15:
                    print(f"                 ... et {len(func_names) - 15} autres")
        else:
            print(f"  Fonctions: ? (erreur: {result_functions.get('error')})")
    
    print("\n✅ Inventaire des schémas terminé.\n")

if __name__ == "__main__":
    main()

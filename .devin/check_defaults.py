#!/usr/bin/env python3
"""Vérification valeurs par défaut"""

from supabase_auto_manager import SupabaseAutoManager

manager = SupabaseAutoManager()

print("=" * 80)
print("VALEURS PAR DÉFAUT DES COLONNES")
print("=" * 80)

# Vérifier les valeurs par défaut
result = manager.execute_sql_auto("""
    SELECT column_name, column_default
    FROM information_schema.columns
    WHERE table_schema = 'app' 
    AND table_name = 'bobodo_knowledge'
    AND column_default IS NOT NULL
    ORDER BY ordinal_position
""")

if result and 'data' in result and len(result['data']) > 0:
    print(f"\n{len(result['data'])} colonne(s) avec valeur par défaut:\n")
    for col in result['data']:
        print(f"  - {col['column_name']}: {col['column_default']}")
else:
    print("\n❌ Aucune colonne avec valeur par défaut")

print("\n" + "=" * 80)

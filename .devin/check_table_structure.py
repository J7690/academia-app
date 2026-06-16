#!/usr/bin/env python3
"""Vérification structure table bobodo_knowledge"""

from supabase_auto_manager import SupabaseAutoManager

manager = SupabaseAutoManager()

print("=" * 80)
print("STRUCTURE TABLE app.bobodo_knowledge")
print("=" * 80)

# Vérifier les colonnes
result = manager.execute_sql_auto("""
    SELECT column_name, data_type, is_nullable
    FROM information_schema.columns
    WHERE table_schema = 'app' 
    AND table_name = 'bobodo_knowledge'
    ORDER BY ordinal_position
""")

if result and 'data' in result and len(result['data']) > 0:
    print("\nColonnes:\n")
    for col in result['data']:
        nullable = "NULL" if col['is_nullable'] == 'YES' else "NOT NULL"
        print(f"  - {col['column_name']}: {col['data_type']} {nullable}")
else:
    print("❌ Erreur lors de la récupération des colonnes")

# Vérifier les contraintes
print("\n" + "=" * 80)
print("CONTRAINTES")
print("=" * 80)

result = manager.execute_sql_auto("""
    SELECT conname, contype
    FROM pg_constraint
    WHERE conrelid = 'app.bobodo_knowledge'::regclass
""")

if result and 'data' in result and len(result['data']) > 0:
    print(f"\n{len(result['data'])} contrainte(s):\n")
    for con in result['data']:
        print(f"  - {con['conname']}: {con['contype']}")
else:
    print("\n✅ Aucune contrainte")

print("=" * 80)

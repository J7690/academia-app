#!/usr/bin/env python3
"""Vérification de la structure de la table app.bobodo_knowledge."""

from supabase_auto_manager import SupabaseAutoManager

manager = SupabaseAutoManager()

print("=" * 80)
print("STRUCTURE TABLE app.bobodo_knowledge")
print("=" * 80)

# Vérifier les colonnes et contraintes
result = manager.execute_sql_auto("""
    SELECT 
        column_name,
        data_type,
        is_nullable,
        column_default
    FROM information_schema.columns
    WHERE table_schema = 'app' 
    AND table_name = 'bobodo_knowledge'
    ORDER BY ordinal_position
""")

if result and len(result) > 0:
    print("\n📋 Colonnes:\n")
    for row in result:
        print(f"  - {row}")
else:
    print("❌ Erreur lors de la récupération des colonnes")

# Vérifier les contraintes uniques
result = manager.execute_sql_auto("""
    SELECT 
        tc.constraint_name,
        tc.constraint_type,
        kcu.column_name
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu 
        ON tc.constraint_name = kcu.constraint_name
    WHERE tc.table_schema = 'app' 
    AND tc.table_name = 'bobodo_knowledge'
    AND tc.constraint_type = 'UNIQUE'
""")

if result and len(result) > 0:
    print(f"\n🔑 Contraintes uniques:\n")
    for row in result:
        print(f"  - {row['constraint_name']}: {row['column_name']}")
else:
    print("\n⚠️  Aucune contrainte unique trouvée")

print("\n" + "=" * 80)

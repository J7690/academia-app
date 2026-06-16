#!/usr/bin/env python3
"""Vérification simple des fiches de connaissances Academia."""

from supabase_auto_manager import SupabaseAutoManager

manager = SupabaseAutoManager()

print("=" * 80)
print("VÉRIFICATION FICHES DE CONNAISSANCES ACADEMIA")
print("=" * 80)

# Compter le total
result = manager.execute_sql_auto("""
    SELECT COUNT(*) as total
    FROM app.bobodo_knowledge
    WHERE category IN ('NEXIOM_ACADEMIA_INTERNE', 'ORIENTATION_ETUDES_EMPLOI')
""")

print(f"\n📊 Résultat COUNT: {result}")

# Lister les fiches
result = manager.execute_sql_auto("""
    SELECT title, category
    FROM app.bobodo_knowledge
    WHERE category IN ('NEXIOM_ACADEMIA_INTERNE', 'ORIENTATION_ETUDES_EMPLOI')
    ORDER BY title
""")

print(f"\n📊 Résultat SELECT: {len(result)} fiches")
for row in result:
    print(f"  - {row}")

print("\n" + "=" * 80)

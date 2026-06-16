#!/usr/bin/env python3
"""Vérification finale des fiches de connaissances Academia insérées."""

from supabase_auto_manager import SupabaseAutoManager

manager = SupabaseAutoManager()

print("=" * 80)
print("VÉRIFICATION FINALE FICHES DE CONNAISSANCES ACADEMIA")
print("=" * 80)

# Compter le total
result = manager.execute_sql_auto("""
    SELECT COUNT(*) as total
    FROM app.bobodo_knowledge
    WHERE category IN ('NEXIOM_ACADEMIA_INTERNE', 'ORIENTATION_ETUDES_EMPLOI')
""")

if result and len(result) > 0:
    print(f"\n✅ Total fiches Academia: {result[0]['total']}")
else:
    print("❌ Erreur lors de la vérification")

# Lister les fiches
result = manager.execute_sql_auto("""
    SELECT title, category
    FROM app.bobodo_knowledge
    WHERE category IN ('NEXIOM_ACADEMIA_INTERNE', 'ORIENTATION_ETUDES_EMPLOI')
    ORDER BY title
""")

if result and len(result) > 0:
    print(f"\n📝 Fiches trouvées ({len(result)}):\n")
    for row in result:
        print(f"  - [{row['category']}] {row['title']}")
else:
    print("❌ Aucune fiche trouvée")

print("\n" + "=" * 80)

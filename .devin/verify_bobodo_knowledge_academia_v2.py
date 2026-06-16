#!/usr/bin/env python3
"""Vérification des fiches de connaissances Academia insérées via RPC."""

from supabase_auto_manager import SupabaseAutoManager

manager = SupabaseAutoManager()

print("=" * 80)
print("VÉRIFICATION FICHES DE CONNAISSANCES ACADEMIA")
print("=" * 80)

# Vérifier les fiches insérées via RPC
result = manager.execute_sql_auto("""
    SELECT COUNT(*) as total
    FROM app.bobodo_knowledge
    WHERE category IN ('NEXIOM_ACADEMIA_INTERNE', 'ORIENTATION_ETUDES_EMPLOI')
""")

if result and len(result) > 0:
    print(f"\n✅ Total fiches: {result[0]['total']}")
else:
    print("❌ Erreur lors de la vérification")

# Lister les titres
result = manager.execute_sql_auto("""
    SELECT title, category
    FROM app.bobodo_knowledge
    WHERE category IN ('NEXIOM_ACADEMIA_INTERNE', 'ORIENTATION_ETUDES_EMPLOI')
    ORDER BY title
""")

if result and len(result) > 0:
    print(f"\n📝 Fiches trouvées:\n")
    for row in result:
        print(f"  - [{row['category']}] {row['title']}")
else:
    print("❌ Aucune fiche trouvée")

print("\n" + "=" * 80)

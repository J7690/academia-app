#!/usr/bin/env python3
"""Vérification des fiches de connaissances Academia insérées."""

from supabase_auto_manager import SupabaseAutoManager

manager = SupabaseAutoManager()

print("=" * 80)
print("VÉRIFICATION FICHES DE CONNAISSANCES ACADEMIA")
print("=" * 80)

# Vérifier les fiches insérées
result = manager.execute_sql_auto("""
    SELECT id, title, category, tags
    FROM app.bobodo_knowledge
    WHERE category IN ('NEXIOM_ACADEMIA_INTERNE', 'ORIENTATION_ETUDES_EMPLOI')
    ORDER BY title
""")

if result and len(result) > 0:
    print(f"\n✅ {len(result)} fiche(s) trouvée(s) dans la base:\n")
    for row in result:
        print(f"  - {row}")
        print()
else:
    print("❌ Aucune fiche trouvée")

print("=" * 80)

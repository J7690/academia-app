#!/usr/bin/env python3
"""Vérification exacte du titre avec caractères"""

from supabase_auto_manager import SupabaseAutoManager

manager = SupabaseAutoManager()

print("=" * 80)
print("VÉRIFICATION EXACTE DU TITRE")
print("=" * 80)

# Vérifier le titre exact
result = manager.execute_sql_auto("""
    SELECT id, title, created_at
    FROM app.bobodo_knowledge
    WHERE title = 'Critères d''admission des universités partenaires'
""")

if result and 'data' in result and len(result['data']) > 0:
    print(f"\n✅ Fiche trouvée avec titre exact:\n")
    for fiche in result['data']:
        print(f"ID: {fiche['id']}")
        print(f"Titre: '{fiche['title']}'")
        print(f"Créée: {fiche['created_at']}")
        print(f"Longueur titre: {len(fiche['title'])}")
else:
    print("❌ Fiche non trouvée avec titre exact")

# Vérifier avec ILIKE
result = manager.execute_sql_auto("""
    SELECT id, title, created_at
    FROM app.bobodo_knowledge
    WHERE title ILIKE '%critères%'
""")

if result and 'data' in result and len(result['data']) > 0:
    print(f"\n✅ Fiches trouvées avec ILIKE:\n")
    for fiche in result['data']:
        print(f"ID: {fiche['id']}")
        print(f"Titre: '{fiche['title']}'")
        print(f"Créée: {fiche['created_at']}")
        print(f"Longueur titre: {len(fiche['title'])}")
        print()
else:
    print("❌ Aucune fiche trouvée")

print("=" * 80)

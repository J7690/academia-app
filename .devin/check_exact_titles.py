#!/usr/bin/env python3
"""Vérification exacte des titres LOT A"""

from supabase_auto_manager import SupabaseAutoManager

manager = SupabaseAutoManager()

print("=" * 80)
print("VÉRIFICATION EXACTE DES TITRES LOT A")
print("=" * 80)

# Vérifier les fiches créées aujourd'hui avec "critères" dans le titre
result = manager.execute_sql_auto("""
    SELECT id, title, created_at
    FROM app.bobodo_knowledge
    WHERE created_at >= CURRENT_DATE
    AND title ILIKE '%crit%'
    ORDER BY created_at DESC
""")

if result and 'data' in result and len(result['data']) > 0:
    print(f"\n{len(result['data'])} fiches avec 'crit' trouvées aujourd'hui:\n")
    for fiche in result['data']:
        print(f"ID: {fiche['id']}")
        print(f"Titre: {fiche['title']}")
        print(f"Créée: {fiche['created_at']}")
        print()
else:
    print("❌ Aucune fiche trouvée")

# Vérifier tous les titres créés aujourd'hui
print("=" * 80)
print("TOUS LES TITRES CRÉÉS AUJOURD'HUI")
print("=" * 80)

result = manager.execute_sql_auto("""
    SELECT id, title, created_at
    FROM app.bobodo_knowledge
    WHERE created_at >= CURRENT_DATE
    ORDER BY created_at DESC
""")

if result and 'data' in result and len(result['data']) > 0:
    print(f"\n{len(result['data'])} fiches créées aujourd'hui:\n")
    for i, fiche in enumerate(result['data'], 1):
        print(f"{i}. {fiche['title']}")
        print(f"   ID: {fiche['id']}")
        print(f"   Créée: {fiche['created_at']}")
        print()
else:
    print("❌ Aucune fiche trouvée")

print("=" * 80)

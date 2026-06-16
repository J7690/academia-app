#!/usr/bin/env python3
"""Vérification des inserts d'aujourd'hui"""

from supabase_auto_manager import SupabaseAutoManager

manager = SupabaseAutoManager()

print("=" * 80)
print("VÉRIFICATION INSERTS D'AUJOURD'HUI")
print("=" * 80)

# Vérifier les fiches créées aujourd'hui avec SET search_path
result = manager.execute_sql_auto("""
    SET search_path TO app, public;
    SELECT id, title, created_at
    FROM app.bobodo_knowledge
    WHERE created_at >= CURRENT_DATE
    ORDER BY created_at DESC
""")

if result and 'data' in result and len(result['data']) > 0:
    print(f"\n✅ Fiches créées aujourd'hui : {len(result['data'])}\n")
    for fiche in result['data']:
        print(f"ID: {fiche['id']}")
        print(f"Titre: {fiche['title']}")
        print(f"Créée: {fiche['created_at']}")
        print()
else:
    print("❌ Aucune fiche créée aujourd'hui")

# Vérifier avec un SELECT direct sans SET search_path
print("=" * 80)
print("VÉRIFICATION SANS SET search_path")
print("=" * 80)

result = manager.execute_sql_auto("""
    SELECT id, title, created_at
    FROM app.bobodo_knowledge
    WHERE title ILIKE '%candidature%' OR title ILIKE '%paiement%' OR title ILIKE '%crédits%'
    ORDER BY created_at DESC
""")

if result and 'data' in result and len(result['data']) > 0:
    print(f"\n✅ Fiches trouvées : {len(result['data'])}\n")
    for fiche in result['data']:
        print(f"ID: {fiche['id']}")
        print(f"Titre: {fiche['title']}")
        print(f"Créée: {fiche['created_at']}")
        print()
else:
    print("❌ Aucune fiche trouvée")

print("=" * 80)

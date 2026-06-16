#!/usr/bin/env python3
"""Vérification des inserts récents"""

from supabase_auto_manager import SupabaseAutoManager

manager = SupabaseAutoManager()

print("=" * 80)
print("VÉRIFICATION DES 7 DERNIERS INSERES")
print("=" * 80)

# Vérifier les 7 dernières fiches par ID
result = manager.execute_sql_auto("""
    SELECT id, title, created_at
    FROM app.bobodo_knowledge
    ORDER BY id DESC
    LIMIT 10
""")

if result and 'data' in result and len(result['data']) > 0:
    print(f"\n{len(result['data'])} dernières fiches par ID:\n")
    for fiche in result['data']:
        print(f"ID: {fiche['id']}")
        print(f"Titre: {fiche['title']}")
        print(f"Créée: {fiche['created_at']}")
        print()
else:
    print("❌ Erreur")

# Vérifier si les titres contiennent "candidature" ou "paiement"
print("=" * 80)
print("RECHERCHE PAR MOTS-CLÉS")
print("=" * 80)

result = manager.execute_sql_auto("""
    SELECT id, title, created_at
    FROM app.bobodo_knowledge
    WHERE title ILIKE '%candidature%' 
       OR title ILIKE '%paiement%'
       OR title ILIKE '%crédits%'
    ORDER BY created_at DESC
""")

if result and 'data' in result and len(result['data']) > 0:
    print(f"\n{len(result['data'])} fiches trouvées:\n")
    for fiche in result['data']:
        print(f"ID: {fiche['id']}")
        print(f"Titre: {fiche['title']}")
        print(f"Créée: {fiche['created_at']}")
        print()
else:
    print("❌ Aucune fiche trouvée avec ces mots-clés")

print("=" * 80)

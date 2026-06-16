#!/usr/bin/env python3
"""Vérification simple des fiches LOT B Phase 1"""

from supabase_auto_manager import SupabaseAutoManager

manager = SupabaseAutoManager()

print("=" * 80)
print("VÉRIFICATION SIMPLE FICHES LOT B PHASE 1")
print("=" * 80)

# Lister toutes les fiches récentes
print("\n--- Fiches récentes ---")
result = manager.execute_sql_auto("""
    SELECT id, title, category, created_at
    FROM app.bobodo_knowledge
    ORDER BY created_at DESC
    LIMIT 10;
""")

if result and 'data' in result and len(result['data']) > 0:
    print(f"Nombre de fiches récentes : {len(result['data'])}")
    for i, fiche in enumerate(result['data'], 1):
        print(f"\n{i}. {fiche['title']}")
        print(f"   ID : {fiche['id']}")
        print(f"   Catégorie : {fiche['category']}")
        print(f"   Créé le : {fiche['created_at']}")
else:
    print("❌ Erreur lors de la récupération des fiches")

# Chercher spécifiquement les 5 fiches LOT B Phase 1
print("\n--- Recherche des 5 fiches LOT B Phase 1 ---")
new_fiches = [
    "Comment créer un compte sur Academia ?",
    "Comment modifier mon profil ?",
    "Mon paiement est en attente",
    "Ma candidature est bloquée",
    "Comment accéder aux cours d''appui ?"
]

for fiche_title in new_fiches:
    result = manager.execute_sql_auto(f"""
        SELECT id, title, category, is_active
        FROM app.bobodo_knowledge
        WHERE title ILIKE '%{fiche_title.replace("'", "''").replace("?", "")}%'
        LIMIT 5;
    """)
    
    if result and 'data' in result and len(result['data']) > 0:
        print(f"✅ Trouvé : {fiche_title}")
        for fiche in result['data']:
            print(f"   - {fiche['title']} (ID: {fiche['id']})")
    else:
        print(f"❌ Non trouvé : {fiche_title}")

print("\n" + "=" * 80)
print("VÉRIFICATION TERMINÉE")
print("=" * 80)

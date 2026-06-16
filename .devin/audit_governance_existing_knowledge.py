#!/usr/bin/env python3
"""Audit de gouvernance - Analyse des 13 fiches existantes dans app.bobodo_knowledge."""

from supabase_auto_manager import SupabaseAutoManager

manager = SupabaseAutoManager()

print("=" * 80)
print("AUDIT GOUVERNANCE – ANALYSE FICHES EXISTANTES")
print("=" * 80)

# Récupérer toutes les fiches
result = manager.execute_sql_auto("""
    SELECT id, title, content, category, tags, created_at, updated_at
    FROM app.bobodo_knowledge
    ORDER BY title
""")

if result and 'data' in result and len(result['data']) > 0:
    fiches = result['data']
    print(f"\n✅ {len(fiches)} fiche(s) trouvée(s) dans app.bobodo_knowledge\n")
    
    for fiche in fiches:
        print(f"{'=' * 80}")
        print(f"ID: {fiche['id']}")
        print(f"Titre: {fiche['title']}")
        print(f"Catégorie: {fiche['category']}")
        print(f"Tags: {fiche['tags']}")
        print(f"Créée le: {fiche['created_at']}")
        print(f"Modifiée le: {fiche['updated_at']}")
        print(f"\nContenu:\n{fiche['content']}")
        print(f"{'=' * 80}\n")
else:
    print("❌ Aucune fiche trouvée")

print("=" * 80)

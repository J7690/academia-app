#!/usr/bin/env python3
"""Audit de gouvernance - Récupération complète de toutes les fiches."""

from supabase_auto_manager import SupabaseAutoManager
import json

manager = SupabaseAutoManager()

print("=" * 80)
print("AUDIT GOUVERNANCE – RÉCUPÉRATION COMPLÈTE FICHES")
print("=" * 80)

# Récupérer toutes les fiches
result = manager.execute_sql_auto("""
    SELECT id, title, content, category, tags, created_at, updated_at
    FROM app.bobodo_knowledge
    ORDER BY created_at
""")

if result and 'data' in result and len(result['data']) > 0:
    fiches = result['data']
    print(f"\n✅ {len(fiches)} fiche(s) trouvée(s) au total\n")
    
    # Sauvegarder en JSON pour analyse
    with open('all_bobodo_knowledge.json', 'w', encoding='utf-8') as f:
        json.dump(fiches, f, ensure_ascii=False, indent=2)
    
    print("Fiches sauvegardées dans all_bobodo_knowledge.json\n")
    
    # Afficher un résumé
    for i, fiche in enumerate(fiches, 1):
        print(f"{i}. [{fiche['category']}] {fiche['title']}")
        print(f"   Tags: {fiche['tags']}")
        print(f"   Créée: {fiche['created_at'][:10]}")
        print()
else:
    print("❌ Aucune fiche trouvée")

print("=" * 80)

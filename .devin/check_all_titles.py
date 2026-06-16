#!/usr/bin/env python3
"""Vérification complète de tous les titres"""

from supabase_auto_manager import SupabaseAutoManager

manager = SupabaseAutoManager()

print("=" * 80)
print("LISTE COMPLÈTE DES TITRES")
print("=" * 80)

result = manager.execute_sql_auto("""
    SELECT id, title, created_at
    FROM app.bobodo_knowledge
    ORDER BY created_at DESC
""")

if result and 'data' in result and len(result['data']) > 0:
    print(f"\n{len(result['data'])} fiches au total:\n")
    for i, fiche in enumerate(result['data'], 1):
        created = fiche['created_at'][:19] if fiche['created_at'] else 'N/A'
        print(f"{i}. {fiche['title']}")
        print(f"   ID: {fiche['id']}")
        print(f"   Créée: {created}")
        print()
else:
    print("❌ Erreur")

print("=" * 80)

#!/usr/bin/env python3
"""Debug insertion LOT A"""

from supabase_auto_manager import SupabaseAutoManager

manager = SupabaseAutoManager()

print("=" * 80)
print("DEBUG – VÉRIFICATION DERNIÈRES FICHES AJOUTÉES")
print("=" * 80)

# Vérifier les fiches créées aujourd'hui
result = manager.execute_sql_auto("""
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

# Vérifier s'il y a des doublons de titres
print("=" * 80)
print("VÉRIFICATION DOUBLONS DE TITRES")
print("=" * 80)

result = manager.execute_sql_auto("""
    SELECT title, COUNT(*) as count
    FROM app.bobodo_knowledge
    GROUP BY title
    HAVING COUNT(*) > 1
""")

if result and 'data' in result and len(result['data']) > 0:
    print(f"\n⚠️  Doublons détectés : {len(result['data'])}\n")
    for dup in result['data']:
        print(f"Titre: {dup['title']} (x{dup['count']})")
else:
    print("\n✅ Aucun doublon détecté")

print("=" * 80)

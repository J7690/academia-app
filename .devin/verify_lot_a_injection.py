#!/usr/bin/env python3
"""Vérifications post-injection LOT A"""

from supabase_auto_manager import SupabaseAutoManager

manager = SupabaseAutoManager()

print("=" * 80)
print("VÉRIFICATION 1 – NOMBRE TOTAL FICHES + LISTE TITRES")
print("=" * 80)

# Compter le nombre total de fiches
result = manager.execute_sql_auto("""
    SELECT COUNT(*) as total
    FROM app.bobodo_knowledge
""")

if result and 'data' in result and len(result['data']) > 0:
    total = result['data'][0]['total']
    print(f"\n✅ Nombre total de fiches dans app.bobodo_knowledge : {total}")
else:
    print("❌ Erreur lors du comptage")

# Lister tous les titres
result = manager.execute_sql_auto("""
    SELECT title, created_at
    FROM app.bobodo_knowledge
    ORDER BY created_at DESC
""")

if result and 'data' in result and len(result['data']) > 0:
    print(f"\n✅ Liste des titres ({len(result['data'])} fiches) :\n")
    for i, fiche in enumerate(result['data'], 1):
        created = fiche['created_at'][:10] if fiche['created_at'] else 'N/A'
        print(f"{i}. {fiche['title']} (créée le {created})")
else:
    print("❌ Erreur lors de la récupération des titres")

# Vérifier la présence des 7 nouvelles fiches du LOT A
print("\n" + "=" * 80)
print("VÉRIFICATION PRÉSENCE FICHES LOT A")
print("=" * 80)

lot_a_titles = [
    'Comment déposer une candidature sur Academia',
    'Documents nécessaires pour une candidature',
    "Critères d'admission des universités partenaires",
    'Comprendre les statuts de candidature',
    'Effectuer un paiement sur Academia',
    'Guide complet des crédits IA',
    'Comment suivre sa candidature'
]

# Vérifier chaque titre individuellement
found = []
for title in lot_a_titles:
    result = manager.execute_sql_auto(f"""
        SELECT title
        FROM app.bobodo_knowledge
        WHERE title = '{title.replace("'", "''")}'
    """)
    if result and 'data' in result and len(result['data']) > 0:
        found.append(title)

print(f"\n✅ Fiches LOT A présentes : {len(found)}/7")
for title in lot_a_titles:
    status = "✅" if title in found else "❌"
    print(f"{status} {title}")

print("\n" + "=" * 80)
print("VÉRIFICATION 2 – EMBEDDINGS GÉNÉRÉS")
print("=" * 80)

# Compter les fiches avec embeddings
result = manager.execute_sql_auto("""
    SELECT 
        COUNT(*) as total,
        COUNT(embedding) as with_embeddings
    FROM app.bobodo_knowledge
""")

if result and 'data' in result and len(result['data']) > 0:
    total = result['data'][0]['total']
    with_embeddings = result['data'][0]['with_embeddings']
    rate = (with_embeddings / total * 100) if total > 0 else 0
    print(f"\n✅ Nombre total de fiches : {total}")
    print(f"✅ Nombre de fiches avec embeddings : {with_embeddings}")
    print(f"✅ Taux de vectorisation : {rate:.1f}%")
else:
    print("❌ Erreur lors de la vérification des embeddings")

print("\n" + "=" * 80)

#!/usr/bin/env python3
"""Vérification embeddings LOT A"""

from supabase_auto_manager import SupabaseAutoManager

manager = SupabaseAutoManager()

print("=" * 80)
print("VÉRIFICATION EMBEDDINGS LOT A")
print("=" * 80)

# Vérifier les embeddings des fiches LOT A
lot_a_titles = [
    'Comment déposer une candidature sur Academia',
    'Documents nécessaires pour une candidature',
    "Critères d'admission des universités partenaires",
    'Comprendre les statuts de candidature',
    'Effectuer un paiement sur Academia',
    'Guide complet des crédits IA',
    'Comment suivre sa candidature'
]

with_embeddings = []
without_embeddings = []

for title in lot_a_titles:
    result = manager.execute_sql_auto(f"""
        SELECT title, embedding IS NOT NULL as has_embedding
        FROM app.bobodo_knowledge
        WHERE title = '{title.replace("'", "''")}'
    """)
    if result and 'data' in result and len(result['data']) > 0:
        row = result['data'][0]
        if row['has_embedding']:
            with_embeddings.append(title)
        else:
            without_embeddings.append(title)

print(f"\n✅ Fiches LOT A avec embeddings : {len(with_embeddings)}/7")
for title in with_embeddings:
    print(f"✅ {title}")

print(f"\n❌ Fiches LOT A sans embeddings : {len(without_embeddings)}/7")
for title in without_embeddings:
    print(f"❌ {title}")

print("\n" + "=" * 80)
print("STATISTIQUES GLOBALES")
print("=" * 80)

result = manager.execute_sql_auto("""
    SELECT 
        COUNT(*) as total,
        COUNT(embedding) as with_embeddings
    FROM app.bobodo_knowledge
""")

if result and 'data' in result and len(result['data']) > 0:
    total = result['data'][0]['total']
    with_emb = result['data'][0]['with_embeddings']
    rate = (with_emb / total * 100) if total > 0 else 0
    print(f"\n✅ Nombre total de fiches : {total}")
    print(f"✅ Nombre de fiches avec embeddings : {with_emb}")
    print(f"✅ Taux de vectorisation : {rate:.1f}%")

print("=" * 80)

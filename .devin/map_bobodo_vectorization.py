#!/usr/bin/env python3
"""Cartographie complète de la vectorisation Bobodo"""

from supabase_auto_manager import SupabaseAutoManager

manager = SupabaseAutoManager()

print("=" * 80)
print("CARTOGRAPHIE COMPLÈTE - ÉTAT VECTORISATION BOBODO")
print("=" * 80)

# Récupérer toutes les fiches avec leur état d'embedding
result = manager.execute_sql_auto("""
    SELECT id, title, category, created_at, embedding IS NOT NULL as has_embedding
    FROM app.bobodo_knowledge
    ORDER BY created_at DESC
""")

if result and 'data' in result and len(result['data']) > 0:
    total = len(result['data'])
    with_embedding = sum(1 for row in result['data'] if row['has_embedding'])
    without_embedding = total - with_embedding
    rate = (with_embedding / total * 100) if total > 0 else 0
    
    print(f"\nSTATISTIQUES GLOBALES:")
    print(f"✅ Total fiches: {total}")
    print(f"✅ Fiches vectorisées: {with_embedding}")
    print(f"❌ Fiches non vectorisées: {without_embedding}")
    print(f"✅ Taux de vectorisation: {rate:.1f}%")
    
    print("\n" + "=" * 80)
    print("DÉTAIL PAR FICHE")
    print("=" * 80)
    
    # Fiches LOT A
    lot_a_titles = [
        'Comment déposer une candidature sur Academia',
        'Documents nécessaires pour une candidature',
        "Critères d'admission des universités partenaires",
        'Comprendre les statuts de candidature',
        'Effectuer un paiement sur Academia',
        'Guide complet des crédits IA',
        'Comment suivre sa candidature'
    ]
    
    print("\nFICHES LOT A:")
    lot_a_with = 0
    lot_a_without = 0
    for row in result['data']:
        if row['title'] in lot_a_titles:
            status = "✅" if row['has_embedding'] else "❌"
            print(f"{status} {row['title']}")
            if row['has_embedding']:
                lot_a_with += 1
            else:
                lot_a_without += 1
    
    print(f"\nLOT A: {lot_a_with}/{len(lot_a_titles)} vectorisées")
    
    # Fiches non vectorisées
    print("\n" + "=" * 80)
    print("FICHES NON VECTORISÉES:")
    print("=" * 80)
    
    non_vectorized = [row for row in result['data'] if not row['has_embedding']]
    for row in non_vectorized:
        print(f"❌ {row['title']}")
        print(f"   Catégorie: {row['category']}")
        print(f"   Créée: {row['created_at']}")
        print()
    
else:
    print("❌ Erreur lors de la récupération des fiches")

print("=" * 80)

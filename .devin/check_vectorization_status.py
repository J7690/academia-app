#!/usr/bin/env python3
"""Vérifier l'état de vectorisation Bobodo"""

from supabase_auto_manager import SupabaseAutoManager

manager = SupabaseAutoManager()

print("=" * 80)
print("ÉTAT VECTORISATION BOBODO")
print("=" * 80)

# Récupérer les statistiques
result = manager.execute_sql_auto("""
    SELECT 
        COUNT(*) as total,
        COUNT(CASE WHEN embedding IS NOT NULL THEN 1 END) as vectorized,
        COUNT(CASE WHEN embedding IS NULL THEN 1 END) as not_vectorized
    FROM app.bobodo_knowledge
    WHERE is_active = true
""")

if result and 'data' in result and len(result['data']) > 0:
    row = result['data'][0]
    total = row['total']
    vectorized = row['vectorized']
    not_vectorized = row['not_vectorized']
    rate = (vectorized / total * 100) if total > 0 else 0
    
    print(f"\nTotal fiches: {total}")
    print(f"Vectorisées: {vectorized}")
    print(f"Non vectorisées: {not_vectorized}")
    print(f"Taux: {rate:.1f}%")
    
    if not_vectorized > 0:
        print(f"\n⚠️ {not_vectorized} fiches ne sont toujours pas vectorisées")
        
        # Lister les fiches non vectorisées
        result2 = manager.execute_sql_auto("""
            SELECT id, title, category, created_at
            FROM app.bobodo_knowledge
            WHERE embedding IS NULL AND is_active = true
            ORDER BY created_at DESC
        """)
        
        if result2 and 'data' in result2 and len(result2['data']) > 0:
            print("\nFiches non vectorisées:")
            for row in result2['data']:
                print(f"  - {row['title']} ({row['category']})")
    else:
        print(f"\n✅ Toutes les fiches sont vectorisées")
else:
    print("❌ Erreur lors de la récupération des statistiques")

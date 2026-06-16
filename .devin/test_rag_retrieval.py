#!/usr/bin/env python3
"""Test RAG - Vérifier la récupération des fiches avec formulations variées"""

from supabase_auto_manager import SupabaseAutoManager

manager = SupabaseAutoManager()

print("=" * 80)
print("TEST RAG - RÉCUPÉRATION FICHES AVEC FORMULATIONS VARIÉES")
print("=" * 80)

# Fiches LOT A à tester
lot_a_fiches = [
    "Comment déposer une candidature sur Academia",
    "Documents nécessaires pour une candidature",
    "Critères d'admission des universités partenaires",
    "Comprendre les statuts de candidature",
    "Effectuer un paiement sur Academia",
    "Guide complet des crédits IA",
    "Comment suivre sa candidature"
]

# Formulations variées pour tester la recherche sémantique
test_queries = [
    # Candidature
    "Comment postuler ?",
    "Je veux commencer ma candidature",
    "Je veux déposer mon dossier",
    "Comment faire une demande d'admission",
    
    # Documents
    "Quels papiers fournir ?",
    "Quels documents sont nécessaires",
    "De quoi ai-je besoin pour mon dossier",
    
    # Suivi
    "Comment suivre ma candidature",
    "Où voir l'état de ma demande",
    "Comment savoir si je suis accepté",
    
    # Paiement
    "Comment acheter des crédits IA",
    "Comment payer sur Academia",
    "Je n'arrive pas à payer",
    
    # Statuts
    "Que signifie under_review",
    "Mon paiement est en attente",
    "Mon dossier est bloqué",
]

print(f"\n{len(test_queries)} requêtes de test")
print(f"{len(lot_a_fiches)} fiches LOT A à retrouver")

# Pour chaque requête, tester la recherche sémantique
print("\n" + "=" * 80)
print("RÉSULTATS PAR REQUÊTE")
print("=" * 80)

for query in test_queries:
    print(f"\nRequête: \"{query}\"")
    
    # Simuler une recherche sémantique (similaire à ce que fait bobodo-chat)
    # Pour l'instant, nous allons faire une recherche textuelle simple
    # car nous n'avons pas accès à l'API de recherche vectorielle directement
    
    # Échapper les apostrophes dans la requête
    escaped_query = query.replace("'", "''")
    
    result = manager.execute_sql_auto(f"""
        SELECT title, category, 
               CASE 
                 WHEN title ILIKE '%{escaped_query}%' THEN 'titre exact'
                 WHEN content ILIKE '%{escaped_query}%' THEN 'contenu'
                 ELSE 'non trouvé'
               END as match_type
        FROM app.bobodo_knowledge
        WHERE is_active = true
          AND (title ILIKE '%{escaped_query}%' OR content ILIKE '%{escaped_query}%')
        LIMIT 3
    """)
    
    if result and 'data' in result and len(result['data']) > 0:
        print(f"  ✅ {len(result['data'])} fiches trouvées:")
        for row in result['data']:
            match_type = row['match_type']
            title = row['title']
            is_lot_a = title in lot_a_fiches
            marker = " [LOT A]" if is_lot_a else ""
            print(f"    - {title}{marker} ({match_type})")
    else:
        print(f"  ❌ Aucune fiche trouvée")

print("\n" + "=" * 80)
print("CONCLUSION")
print("=" * 80)
print("Note: Ce test utilise une recherche textuelle ILIKE.")
print("Pour un vrai test RAG, il faudrait utiliser la recherche vectorielle pgvector.")
print("Cela nécessiterait de générer l'embedding de la requête et de faire une recherche de similarité.")

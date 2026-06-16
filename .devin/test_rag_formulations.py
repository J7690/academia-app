#!/usr/bin/env python3
"""Test RAG avec plusieurs formulations de la même question"""

from supabase_auto_manager import SupabaseAutoManager

manager = SupabaseAutoManager()

print("=" * 80)
print("TEST RAG - FORMULATIONS VARIÉES")
print("=" * 80)

# Groupe de formulations pour le même concept
test_groups = [
    {
        "concept": "Déposer candidature",
        "formulations": [
            "Comment déposer une candidature ?",
            "Comment postuler ?",
            "Je veux envoyer mon dossier",
            "Comment faire une demande d'admission ?",
        ]
    },
    {
        "concept": "Documents nécessaires",
        "formulations": [
            "Quels documents fournir ?",
            "De quoi ai-je besoin pour mon dossier ?",
            "Quels papiers sont nécessaires ?",
            "Quelle est la liste des documents ?",
        ]
    },
    {
        "concept": "Suivi candidature",
        "formulations": [
            "Comment suivre ma candidature ?",
            "Où voir l'état de ma demande ?",
            "Comment savoir si je suis accepté ?",
            "Comment vérifier le statut de mon dossier ?",
        ]
    },
    {
        "concept": "Paiement",
        "formulations": [
            "Comment payer sur Academia ?",
            "Comment acheter des crédits IA ?",
            "Je n'arrive pas à payer",
            "Comment effectuer un paiement ?",
        ]
    },
]

print(f"\n{len(test_groups)} groupes de formulations à tester")

for group in test_groups:
    concept = group["concept"]
    formulations = group["formulations"]
    
    print(f"\n{'='*80}")
    print(f"CONCEPT: {concept}")
    print(f"{'='*80}")
    
    for formulation in formulations:
        print(f"\nFormulation: \"{formulation}\"")
        
        # Recherche textuelle (simulation RAG)
        escaped_query = formulation.replace("'", "''")
        
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
                print(f"    - {title} ({match_type})")
        else:
            print(f"  ❌ Aucune fiche trouvée (recherche textuelle)")

print("\n" + "=" * 80)
print("CONCLUSION")
print("=" * 80)
print("Note: Ce test utilise une recherche textuelle ILIKE.")
print("Pour un vrai test RAG, il faudrait utiliser la recherche vectorielle pgvector.")
print("Cela nécessiterait de générer l'embedding de chaque formulation et de faire une recherche de similarité.")
print("\nPour valider le RAG réel, il faut tester manuellement dans l'application Flutter.")

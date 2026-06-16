#!/usr/bin/env python3
"""Test RAG pour les 5 fiches LOT B Phase 1"""

from supabase_auto_manager import SupabaseAutoManager

manager = SupabaseAutoManager()

print("=" * 80)
print("TEST RAG - LOT B PHASE 1 (5 FICHES CRITIQUES)")
print("=" * 80)

# Formulations pour tester chaque fiche
test_groups = [
    {
        "concept": "Création de compte",
        "target_fiche": "Comment créer un compte sur Academia ?",
        "formulations": [
            "je veux créer mon compte",
            "comment m'inscrire",
            "je veux m'inscrire sur academia",
            "comment créer un compte",
        ]
    },
    {
        "concept": "Modification profil",
        "target_fiche": "Comment modifier mon profil ?",
        "formulations": [
            "comment changer mes informations",
            "je veux modifier mon profil",
            "comment mettre à jour mes infos",
            "comment changer mon nom",
        ]
    },
    {
        "concept": "Paiement en attente",
        "target_fiche": "Mon paiement est en attente",
        "formulations": [
            "mon paiement ne passe pas",
            "paiement bloqué",
            "pourquoi mon paiement est en attente",
            "mon paiement est en attente depuis hier",
        ]
    },
    {
        "concept": "Candidature bloquée",
        "target_fiche": "Ma candidature est bloquée",
        "formulations": [
            "ma candidature n'avance plus",
            "candidature bloquée",
            "pourquoi ma candidature ne bouge pas",
            "ma candidature est bloquée depuis longtemps",
        ]
    },
    {
        "concept": "Accès cours d'appui",
        "target_fiche": "Comment accéder aux cours d''appui ?",
        "formulations": [
            "où trouver les cours d'appui",
            "comment accéder aux TD",
            "je veux faire des TD",
            "comment accéder aux travaux dirigés",
        ]
    },
]

print(f"\n{len(test_groups)} groupes de formulations à tester")

for group in test_groups:
    concept = group["concept"]
    target_fiche = group["target_fiche"]
    formulations = group["formulations"]
    
    print(f"\n{'='*80}")
    print(f"CONCEPT: {concept}")
    print(f"FICHE CIBLE: {target_fiche}")
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
                is_target = "🎯 CIBLE" if title == target_fiche else ""
                print(f"    - {title} ({match_type}) {is_target}")
        else:
            print(f"  ❌ Aucune fiche trouvée (recherche textuelle)")

print("\n" + "=" * 80)
print("CONCLUSION")
print("=" * 80)
print("Note: Ce test utilise une recherche textuelle ILIKE.")
print("Pour un vrai test RAG, il faudrait utiliser la recherche vectorielle pgvector.")
print("Cela nécessiterait de générer l'embedding de chaque formulation et de faire une recherche de similarité.")
print("\nPour valider le RAG réel, il faut tester manuellement dans l'application Flutter.")

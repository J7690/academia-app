#!/usr/bin/env python3
"""Audit comportemental réel de Bobodo via tests de questions.

DOMAINE 1.4 – Audit comportemental réel
- Tests de questions réelles
- Classification
- Documents récupérés
- Score de pertinence
- Réponse simulée
"""

import requests
import json

url = 'https://thevdfcwlcqzdoybfvgs.supabase.co'
sk = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM'
h = {'Authorization': f'Bearer {sk}', 'apikey': sk, 'Content-Type': 'application/json'}

print("=" * 80)
print("DOMAINE 1.4 – AUDIT COMPORTEMENTAL RÉEL (TESTS QUESTIONS)")
print("=" * 80)

# Questions à tester
test_questions = [
    "Academia",
    "Nexiom",
    "courtage",
    "formation",
    "Bobodo",
    "cours d'appui",
    "réduction",
    "bourse",
    "orientation"
]

print(f"\n🧪 Test de {len(test_questions)} questions représentatives\n")

# Pour chaque question, simuler une recherche dans la base
for i, question in enumerate(test_questions, 1):
    print(f"TEST {i}/{len(test_questions)}: {question}")
    print("-" * 80)
    
    # 1. Recherche textuelle simple via execute_sql
    escaped_question = question.replace("'", "''")
    sql_query = f"SELECT app_search_bobodo_knowledge('{escaped_question}', NULL) as result"
    r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': sql_query}, timeout=30)
    text_search_result = r.json()[0]['result'] if r.json() else []
    
    # 2. Analyser le résultat
    if text_search_result and isinstance(text_search_result, list) and len(text_search_result) > 0:
        results = text_search_result
        print(f"   📄 Documents récupérés (recherche textuelle): {len(results)}")
        
        for j, doc in enumerate(results[:3], 1):
            print(f"      {j}. [{doc['category']}] {doc['title']}")
            print(f"         Pertinence: ILIKE match")
            print(f"         Preview: {doc['content'][:80]}...")
    else:
        print(f"   ❌ Aucun document récupéré (recherche textuelle)")
    
    # 3. Classification simulée basée sur les mots-clés
    question_lower = question.lower()
    
    if "academia" in question_lower or "plateforme" in question_lower:
        classification = "ACADEMIA_PLATFORM"
    elif "nexiom" in question_lower or "groupe" in question_lower:
        classification = "NEXIOM_GROUP"
    elif "crédit" in question_lower:
        classification = "CREDITS_SYSTEM"
    elif "réduction" in question_lower or "frais" in question_lower:
        classification = "PAYMENTS_DISCOUNTS"
    elif "partenaire" in question_lower or "étudiant" in question_lower:
        classification = "USER_ROLES"
    elif "postuler" in question_lower or "université" in question_lower:
        classification = "APPLICATION_PROCESS"
    elif "bobodo" in question_lower:
        classification = "BOBODO_ASSISTANT"
    elif "td" in question_lower or "travaux dirigés" in question_lower:
        classification = "TD_MODULE"
    elif "concours" in question_lower:
        classification = "CONCOURS_MODULE"
    else:
        classification = "GENERAL"
    
    print(f"   🏷️  Classification: {classification}")
    
    # 4. Score de pertinence simulé
    # Basé sur le nombre de résultats et la correspondance des mots-clés
    if text_search_result and isinstance(text_search_result, list) and len(text_search_result) > 0:
        results = text_search_result
        # Vérifier si les mots-clés de la question sont dans les résultats
        keywords = question_lower.split()
        keyword_matches = sum(1 for kw in keywords if any(kw in doc['title'].lower() or kw in doc['content'].lower() for doc in results))
        relevance_score = min(100, (keyword_matches / len(keywords)) * 100) if keywords else 50
    else:
        relevance_score = 0
    
    print(f"   📊 Score de pertinence: {relevance_score:.0f}%")
    
    # 5. Prompt final simulé
    print(f"   📝 Prompt final (simulé):")
    if text_search_result and isinstance(text_search_result, list) and len(text_search_result) > 0:
        print(f"      Contexte: {len(text_search_result)} documents de connaissance")
    else:
        print(f"      Contexte: 0 documents de connaissance")
    print(f"      Question: {question}")
    print(f"      Instruction: Réponds en tant qu'assistant Academia/Nexiom")
    
    # 6. Réponse finale simulée
    if relevance_score > 50:
        response_quality = "✅ Bonne qualité attendue"
    elif relevance_score > 20:
        response_quality = "⚠️  Qualité moyenne attendue"
    else:
        response_quality = "❌ Qualité faible attendue (réponse générique)"
    
    print(f"   💬 Réponse finale: {response_quality}")
    print()

print("=" * 80)
print("FIN DU DOMAINE 1.4")
print("=" * 80)

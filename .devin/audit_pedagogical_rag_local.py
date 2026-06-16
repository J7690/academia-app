#!/usr/bin/env python3
"""Audit du fonctionnement réel du RAG pédagogique et de la pédagogie locale.

DOMAINE 2.2 – Fonctionnement réel RAG pédagogique
- Vérification des RPCs RAG pédagogiques
- Test de recherche vectorielle

DOMAINE 2.3 – Vérification pédagogie locale
- Analyse des contenus présents
- Pertinence pour enseignement supérieur BF
- Pertinence pour concours nationaux
"""

import requests
import json

url = 'https://thevdfcwlcqzdoybfvgs.supabase.co'
sk = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM'
h = {'Authorization': f'Bearer {sk}', 'apikey': sk, 'Content-Type': 'application/json'}

print("=" * 80)
print("DOMAINE 2.2 – FONCTIONNEMENT RÉEL RAG PÉDAGOGIQUE")
print("=" * 80)

# Vérifier les RPCs RAG pédagogiques
print("\n🔍 RPCs RAG pédagogiques disponibles:")
print("-" * 80)

rag_rpcs = [
    "app_prep_semantic_search",
    "app_td_semantic_search",
    "app_prep_get_rag_chunks"
]

for rpc in rag_rpcs:
    r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': f"SELECT EXISTS(SELECT 1 FROM pg_proc WHERE proname='{rpc}') as exists"}, timeout=30)
    exists = r.json()[0]['exists']
    status = "✅" if exists else "❌"
    print(f"   {status} {rpc}")

# Test de recherche sémantique Prépa (avec embedding fictif pour tester la structure)
print("\n🧪 Test structure RPC app_prep_semantic_search:")
print("-" * 80)

# Comme il n'y a pas d'embeddings, on teste juste si la RPC répond
try:
    # Utiliser un embedding fictif (vecteur nul) pour tester la structure
    r = requests.post(f'{url}/rest/v1/rpc/app_prep_semantic_search', headers=h, json={'p_query_embedding': '[0,0,0]', 'p_subject_id': None, 'p_concours_type': None, 'p_limit': 5, 'p_threshold': 0.3}, timeout=30)
    result = r.json()
    print(f"   RPC répond: ✅")
    print(f"   Structure: {json.dumps(result, indent=2)[:200]}...")
except Exception as e:
    print(f"   RPC erreur: ❌ {str(e)[:100]}")

# Test de recherche sémantique TD
print("\n🧪 Test structure RPC app_td_semantic_search:")
print("-" * 80)

try:
    r = requests.post(f'{url}/rest/v1/rpc/app_td_semantic_search', headers=h, json={'p_query_embedding': '[0,0,0]', 'p_subject': None, 'p_university': None, 'p_limit': 5, 'p_threshold': 0.3}, timeout=30)
    result = r.json()
    print(f"   RPC répond: ✅")
    print(f"   Structure: {json.dumps(result, indent=2)[:200]}...")
except Exception as e:
    print(f"   RPC erreur: ❌ {str(e)[:100]}")

print("\n" + "=" * 80)
print("DOMAINE 2.3 – VÉRIFICATION PÉDAGOGIE LOCALE")
print("=" * 80)

# Analyse des contenus Prépa
print("\n📚 Analyse contenus Prépa Concours:")
print("-" * 80)

r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT subject_name, COUNT(*) AS count FROM app.prep_doc_chunks GROUP BY subject_name ORDER BY count DESC"}, timeout=30)
prep_subjects = r.json()

print(f"   Matières présentes ({len(prep_subjects)}):")
for sub in prep_subjects:
    print(f"      - {sub['subject_name']}: {sub['count']} chunks")

# Analyse des contenus TD
print("\n📚 Analyse contenus TD:")
print("-" * 80)

r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT subject, COUNT(*) AS count FROM app.td_doc_chunks GROUP BY subject ORDER BY count DESC"}, timeout=30)
td_subjects = r.json()

print(f"   Matières présentes ({len(td_subjects)}):")
for sub in td_subjects:
    print(f"      - {sub['subject']}: {sub['count']} chunks")

# Évaluation de la pertinence pour l'enseignement supérieur BF
print("\n🎓 Pertinence pour enseignement supérieur burkinabè:")
print("-" * 80)

bf_keywords = ["burkina", "faso", "ouagadougou", "bf", "africa"]
bf_relevance_prep = 0
bf_relevance_td = 0

# Vérifier les contenus Prépa
r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT content FROM app.prep_doc_chunks LIMIT 10"}, timeout=30)
prep_samples = r.json()
for sample in prep_samples:
    content_lower = sample['content'].lower()
    if any(kw in content_lower for kw in bf_keywords):
        bf_relevance_prep += 1

# Vérifier les contenus TD
r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT content FROM app.td_doc_chunks LIMIT 10"}, timeout=30)
td_samples = r.json()
for sample in td_samples:
    content_lower = sample['content'].lower()
    if any(kw in content_lower for kw in bf_keywords):
        bf_relevance_td += 1

print(f"   Prépa Concours: {bf_relevance_prep}/10 échantillons pertinents BF")
print(f"   TD: {bf_relevance_td}/10 échantillons pertinents BF")

# Évaluation pour concours nationaux
print("\n📝 Pertinence pour concours nationaux:")
print("-" * 80)

concours_keywords = ["concours", "enaref", "fao", "douanes", "police", "gendarmerie", "magistrature"]
concours_relevance_prep = 0
concours_relevance_td = 0

for sample in prep_samples:
    content_lower = sample['content'].lower()
    if any(kw in content_lower for kw in concours_keywords):
        concours_relevance_prep += 1

for sample in td_samples:
    content_lower = sample['content'].lower()
    if any(kw in content_lower for kw in concours_keywords):
        concours_relevance_td += 1

print(f"   Prépa Concours: {concours_relevance_prep}/10 échantillons pertinents concours")
print(f"   TD: {concours_relevance_td}/10 échantillons pertinents concours")

# Évaluation pour tests psychotechniques
print("\n🧠 Pertinence pour tests psychotechniques:")
print("-" * 80)

psycho_keywords = ["psychotechnique", "logique", "raisonnement", "aptitude", "qi"]
psycho_relevance_prep = 0
psycho_relevance_td = 0

for sample in prep_samples:
    content_lower = sample['content'].lower()
    if any(kw in content_lower for kw in psycho_keywords):
        psycho_relevance_prep += 1

for sample in td_samples:
    content_lower = sample['content'].lower()
    if any(kw in content_lower for kw in psycho_keywords):
        psycho_relevance_td += 1

print(f"   Prépa Concours: {psycho_relevance_prep}/10 échantillons pertinents psychotechnique")
print(f"   TD: {psycho_relevance_td}/10 échantillons pertinents psychotechnique")

print("\n" + "=" * 80)
print("FIN DES DOMAINES 2.2 ET 2.3")
print("=" * 80)

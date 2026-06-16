#!/usr/bin/env python3
"""Audit de l'état des bases documentaires pédagogiques.

DOMAINE 2.1 – État bases documentaires
- Vérification de app.prep_doc_chunks
- Vérification de app.td_doc_chunks
- Nombre de documents, chunks, embeddings
- Taux réel de vectorisation
"""

import requests
import json

url = 'https://thevdfcwlcqzdoybfvgs.supabase.co'
sk = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM'
h = {'Authorization': f'Bearer {sk}', 'apikey': sk, 'Content-Type': 'application/json'}

print("=" * 80)
print("DOMAINE 2.1 – ÉTAT BASES DOCUMENTAIRES PÉDAGOGIQUES")
print("=" * 80)

# ===== PREP_DOC_CHUNKS =====
print("\n📚 TABLE: app.prep_doc_chunks (Prépa Concours)")
print("-" * 80)

# Nombre total de chunks
r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': 'SELECT COUNT(*) AS total FROM app.prep_doc_chunks'}, timeout=30)
total_prep_chunks = r.json()[0]['total']
print(f"   Total chunks: {total_prep_chunks}")

# Nombre de chunks avec embedding
r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': 'SELECT COUNT(*) AS with_embedding FROM app.prep_doc_chunks WHERE embedding IS NOT NULL'}, timeout=30)
with_embedding_prep = r.json()[0]['with_embedding']
print(f"   Chunks avec embedding: {with_embedding_prep}")

# Taux de vectorisation
vectorization_rate_prep = (with_embedding_prep / total_prep_chunks * 100) if total_prep_chunks > 0 else 0
print(f"   Taux de vectorisation: {vectorization_rate_prep:.1f}%")

# Nombre de documents source uniques
r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': 'SELECT COUNT(DISTINCT source_document_id) AS unique_docs FROM app.prep_doc_chunks'}, timeout=30)
unique_docs_prep = r.json()[0]['unique_docs']
print(f"   Documents source uniques: {unique_docs_prep}")

# Répartition par chunk_type
r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT chunk_type, COUNT(*) AS count FROM app.prep_doc_chunks GROUP BY chunk_type ORDER BY count DESC"}, timeout=30)
chunk_types_prep = r.json()
print(f"\n   Répartition par chunk_type:")
for ct in chunk_types_prep:
    print(f"      - {ct['chunk_type']}: {ct['count']} chunks")

# Répartition par subject_name
r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT subject_name, COUNT(*) AS count FROM app.prep_doc_chunks GROUP BY subject_name ORDER BY count DESC LIMIT 10"}, timeout=30)
subjects_prep = r.json()
print(f"\n   Top 10 matières (subject_name):")
for sub in subjects_prep:
    print(f"      - {sub['subject_name']}: {sub['count']} chunks")

# Répartition par concours_type
r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT concours_type, COUNT(*) AS count FROM app.prep_doc_chunks GROUP BY concours_type ORDER BY count DESC"}, timeout=30)
concours_types_prep = r.json()
print(f"\n   Répartition par concours_type:")
for ct in concours_types_prep:
    print(f"      - {ct['concours_type']}: {ct['count']} chunks")

# Taille moyenne des chunks
r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': 'SELECT AVG(LENGTH(content)) AS avg_length, MIN(LENGTH(content)) AS min_length, MAX(LENGTH(content)) AS max_length FROM app.prep_doc_chunks'}, timeout=30)
sizes_prep = r.json()[0]
print(f"\n   Taille des contenus:")
print(f"      - Moyenne: {int(sizes_prep['avg_length'])} caractères")
print(f"      - Minimum: {int(sizes_prep['min_length'])} caractères")
print(f"      - Maximum: {int(sizes_prep['max_length'])} caractères")

# ===== TD_DOC_CHUNKS =====
print("\n\n📚 TABLE: app.td_doc_chunks (Travaux Dirigés)")
print("-" * 80)

# Nombre total de chunks
r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': 'SELECT COUNT(*) AS total FROM app.td_doc_chunks'}, timeout=30)
total_td_chunks = r.json()[0]['total']
print(f"   Total chunks: {total_td_chunks}")

# Nombre de chunks avec embedding
r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': 'SELECT COUNT(*) AS with_embedding FROM app.td_doc_chunks WHERE embedding IS NOT NULL'}, timeout=30)
with_embedding_td = r.json()[0]['with_embedding']
print(f"   Chunks avec embedding: {with_embedding_td}")

# Taux de vectorisation
vectorization_rate_td = (with_embedding_td / total_td_chunks * 100) if total_td_chunks > 0 else 0
print(f"   Taux de vectorisation: {vectorization_rate_td:.1f}%")

# Nombre de documents source uniques
r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': 'SELECT COUNT(DISTINCT source_document_id) AS unique_docs FROM app.td_doc_chunks'}, timeout=30)
unique_docs_td = r.json()[0]['unique_docs']
print(f"   Documents source uniques: {unique_docs_td}")

# Répartition par chunk_type
r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT chunk_type, COUNT(*) AS count FROM app.td_doc_chunks GROUP BY chunk_type ORDER BY count DESC"}, timeout=30)
chunk_types_td = r.json()
print(f"\n   Répartition par chunk_type:")
for ct in chunk_types_td:
    print(f"      - {ct['chunk_type']}: {ct['count']} chunks")

# Répartition par subject
r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT subject, COUNT(*) AS count FROM app.td_doc_chunks GROUP BY subject ORDER BY count DESC LIMIT 10"}, timeout=30)
subjects_td = r.json()
print(f"\n   Top 10 matières (subject):")
for sub in subjects_td:
    print(f"      - {sub['subject']}: {sub['count']} chunks")

# Répartition par university
r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT university, COUNT(*) AS count FROM app.td_doc_chunks GROUP BY university ORDER BY count DESC LIMIT 10"}, timeout=30)
universities_td = r.json()
print(f"\n   Top 10 universités:")
for uni in universities_td:
    print(f"      - {uni['university']}: {uni['count']} chunks")

# Taille moyenne des chunks
r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': 'SELECT AVG(LENGTH(content)) AS avg_length, MIN(LENGTH(content)) AS min_length, MAX(LENGTH(content)) AS max_length FROM app.td_doc_chunks'}, timeout=30)
sizes_td = r.json()[0]
print(f"\n   Taille des contenus:")
print(f"      - Moyenne: {int(sizes_td['avg_length'])} caractères")
print(f"      - Minimum: {int(sizes_td['min_length'])} caractères")
print(f"      - Maximum: {int(sizes_td['max_length'])} caractères")

# ===== RÉSUMÉ COMPARATIF =====
print("\n\n📊 RÉSUMÉ COMPARATIF")
print("=" * 80)
print(f"{'Métrique':<40} {'Prépa Concours':<20} {'TD':<20}")
print("-" * 80)
print(f"{'Total chunks':<40} {total_prep_chunks:<20} {total_td_chunks:<20}")
print(f"{'Chunks avec embedding':<40} {with_embedding_prep:<20} {with_embedding_td:<20}")
print(f"{'Taux vectorisation':<40} {vectorization_rate_prep:.1f}%{' ':<16} {vectorization_rate_td:.1f}%{' ':<16}")
print(f"{'Documents source':<40} {unique_docs_prep:<20} {unique_docs_td:<20}")

print("\n" + "=" * 80)
print("FIN DU DOMAINE 2.1")
print("=" * 80)

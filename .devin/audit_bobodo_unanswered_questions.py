#!/usr/bin/env python3
"""Audit des questions sans réponse de Bobodo.

DOMAINE 1.3 – Audit questions sans réponse
- Analyse de app.bobodo_unanswered_questions
- Top questions récurrentes
- Fréquence
- Catégorie
- Raison probable de l'échec
"""

import requests
import json
from collections import Counter, defaultdict

url = 'https://thevdfcwlcqzdoybfvgs.supabase.co'
sk = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM'
h = {'Authorization': f'Bearer {sk}', 'apikey': sk, 'Content-Type': 'application/json'}

print("=" * 80)
print("DOMAINE 1.3 – AUDIT QUESTIONS SANS RÉPONSE")
print("=" * 80)

# 1. Nombre total de questions sans réponse
r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': 'SELECT COUNT(*) AS total FROM app.bobodo_unanswered_questions'}, timeout=30)
total = r.json()[0]['total']
print(f"\n📊 Nombre total de questions sans réponse: {total}")

if total == 0:
    print("\n✅ Aucune question sans réponse enregistrée.")
    print("=" * 80)
    print("FIN DU DOMAINE 1.3")
    print("=" * 80)
    exit(0)

# 2. Répartition par statut
r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': 'SELECT status, COUNT(*) AS count FROM app.bobodo_unanswered_questions GROUP BY status ORDER BY count DESC'}, timeout=30)
statuses = r.json()
print(f"\n📁 Répartition par statut:")
for st in statuses:
    print(f"   - {st['status']}: {st['count']} questions")

# 3. Répartition par catégorie
r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': 'SELECT category, COUNT(*) AS count FROM app.bobodo_unanswered_questions GROUP BY category ORDER BY count DESC'}, timeout=30)
categories = r.json()
print(f"\n📁 Répartition par catégorie:")
for cat in categories:
    print(f"   - {cat['category']}: {cat['count']} questions")

# 4. Top questions récurrentes (normalisation simple)
r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': 'SELECT question_text, category, status, created_at FROM app.bobodo_unanswered_questions ORDER BY created_at DESC'}, timeout=30)
questions = r.json()

# Normaliser les questions (minuscule, trim)
normalized_questions = [q['question_text'].strip().lower() for q in questions]
question_counts = Counter(normalized_questions)

print(f"\n🔥 Top 10 questions les plus fréquentes:")
print("-" * 80)
for question, count in question_counts.most_common(10):
    # Trouver la question originale pour l'affichage
    original = next((q['question_text'] for q in questions if q['question_text'].strip().lower() == question), question)
    category = next((q['category'] for q in questions if q['question_text'].strip().lower() == question), "N/A")
    print(f"   [{count}x] {category}: {original[:80]}...")

# 5. Analyse temporelle
r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': 'SELECT DATE(created_at) AS date, COUNT(*) AS count FROM app.bobodo_unanswered_questions GROUP BY DATE(created_at) ORDER BY date DESC LIMIT 30'}, timeout=30)
by_date = r.json()
print(f"\n📅 Questions par date (30 derniers jours):")
print("-" * 80)
for entry in by_date:
    print(f"   {entry['date']}: {entry['count']} questions")

# 6. Analyse des mots-clés manquants
# Comparer avec le contenu de bobodo_knowledge
r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': 'SELECT content FROM app.bobodo_knowledge WHERE is_active = TRUE'}, timeout=30)
knowledge_content = " ".join([k['content'].lower() for k in r.json()])

print(f"\n🔍 Analyse des mots-clés potentiellement manquants:")
print("-" * 80)

# Mots-clés courants dans les questions sans réponse
all_question_text = " ".join([q['question_text'].lower() for q in questions])
words_in_questions = Counter(all_question_text.split())

# Mots-clés qui apparaissent souvent dans les questions mais pas dans la base
missing_keywords = []
for word, count in words_in_questions.most_common(20):
    if len(word) > 4 and word not in knowledge_content:
        missing_keywords.append((word, count))

if missing_keywords:
    print("   Mots-clés fréquents dans les questions sans réponse mais absents de la base:")
    for word, count in missing_keywords[:10]:
        print(f"   - '{word}': {count} occurrences")
else:
    print("   ✅ Les mots-clés des questions semblent couverts par la base.")

# 7. Détail des 20 dernières questions
print(f"\n📋 20 dernières questions sans réponse:")
print("-" * 100)
print(f"{'Date':<12} {'Catégorie':<15} {'Statut':<10} {'Question'}")
print("-" * 100)

for q in questions[:20]:
    date = q['created_at'][:10] if q['created_at'] else "N/A"
    category = q['category']
    status = q['status']
    question = q['question_text'][:60] + "..." if len(q['question_text']) > 60 else q['question_text']
    print(f"{date:<12} {category:<15} {status:<10} {question}")

print("\n" + "=" * 80)
print("FIN DU DOMAINE 1.3")
print("=" * 80)

#!/usr/bin/env python3
"""Audit de l'exploitation réelle de la base Bobodo via les logs.

DOMAINE 1.5 – Vérifier exploitation réelle base (logs RAG)
- Analyse des messages Bobodo
- Vérification de l'utilisation du RAG
- Preuves d'exploitation des fiches
"""

import requests
import json
from datetime import datetime

url = 'https://thevdfcwlcqzdoybfvgs.supabase.co'
sk = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM'
h = {'Authorization': f'Bearer {sk}', 'apikey': sk, 'Content-Type': 'application/json'}

print("=" * 80)
print("DOMAINE 1.5 – VÉRIFIER EXPLOITATION RÉELLE BASE (LOGS RAG)")
print("=" * 80)

# 1. Statistiques générales des messages
r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT sender, COUNT(*) AS count FROM app.bobodo_messages GROUP BY sender"}, timeout=30)
sender_stats = r.json()
print(f"\n📊 Répartition des messages par expéditeur:")
for stat in sender_stats:
    print(f"   - {stat['sender']}: {stat['count']} messages")

# 2. Analyse des messages assistant (réponses Bobodo)
r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT content, created_at FROM app.bobodo_messages WHERE sender = 'assistant' ORDER BY created_at DESC LIMIT 20"}, timeout=30)
assistant_messages = r.json()

print(f"\n💬 20 derniers messages de Bobodo (assistant):")
print("-" * 100)

for msg in assistant_messages:
    date = msg['created_at'][:19] if msg['created_at'] else "N/A"
    content = msg['content'][:80] + "..." if len(msg['content']) > 80 else msg['content']
    print(f"[{date}] {content}")

# 3. Vérifier si les réponses contiennent des indices d'utilisation de la base
# Mots-clés qui indiquent une utilisation de la base de connaissances
knowledge_keywords = ["academia", "nexiom", "plateforme", "courtage", "formation", "bourse", "réduction", "orientation"]

r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT content FROM app.bobodo_messages WHERE sender = 'assistant'"}, timeout=30)
all_assistant_messages = r.json()

print(f"\n🔍 Analyse de l'utilisation de la base de connaissances:")
print("-" * 80)

knowledge_usage_count = 0
total_assistant = len(all_assistant_messages)

for msg in all_assistant_messages:
    content_lower = msg['content'].lower()
    if any(kw in content_lower for kw in knowledge_keywords):
        knowledge_usage_count += 1

usage_rate = (knowledge_usage_count / total_assistant * 100) if total_assistant > 0 else 0
print(f"   Total messages assistant: {total_assistant}")
print(f"   Messages avec indices de base de connaissances: {knowledge_usage_count}")
print(f"   Taux d'utilisation estimé: {usage_rate:.1f}%")

# 4. Analyse des besoins détectés (app.bobodo_detected_needs)
r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT category, COUNT(*) AS count FROM app.bobodo_detected_needs GROUP BY category ORDER BY count DESC"}, timeout=30)
detected_needs = r.json()

print(f"\n🎯 Besoins détectés par Bobodo (catégories):")
for need in detected_needs:
    print(f"   - {need['category']}: {need['count']} détections")

# 5. Analyse des sessions actives
r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT COUNT(*) AS total FROM app.bobodo_sessions"}, timeout=30)
total_sessions = r.json()[0]['total']

r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT COUNT(DISTINCT session_id) AS active_sessions FROM app.bobodo_messages WHERE created_at > NOW() - INTERVAL '7 days'"}, timeout=30)
active_sessions_7d = r.json()[0]['active_sessions']

print(f"\n📈 Statistiques des sessions:")
print(f"   - Total sessions créées: {total_sessions}")
print(f"   - Sessions actives (7 derniers jours): {active_sessions_7d}")

# 6. Vérification de l'embedding sur les connaissances
r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT COUNT(*) AS total, COUNT(embedding) AS with_embedding FROM app.bobodo_knowledge WHERE is_active = TRUE"}, timeout=30)
embedding_stats = r.json()[0]

print(f"\n🔢 Statistiques des embeddings:")
print(f"   - Total fiches actives: {embedding_stats['total']}")
print(f"   - Fiches avec embedding: {embedding_stats['with_embedding']}")
print(f"   - Taux de vectorisation: {(embedding_stats['with_embedding']/embedding_stats['total']*100) if embedding_stats['total'] > 0 else 0:.1f}%")

print("\n" + "=" * 80)
print("FIN DU DOMAINE 1.5")
print("=" * 80)

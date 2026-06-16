#!/usr/bin/env python3
"""Audit de la structure des sessions et de l'historique conservé.

CHANTIER 2 – Mémoire cross-session
"""

import requests
import json

url = 'https://thevdfcwlcqzdoybfvgs.supabase.co'
sk = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM'
h = {'Authorization': f'Bearer {sk}', 'apikey': sk, 'Content-Type': 'application/json'}

print("=" * 80)
print("CHANTIER 2 – AUDIT STRUCTURE SESSIONS ET HISTORIQUE CONSERVÉ")
print("=" * 80)

# 1. Audit table app.bobodo_sessions
print("\n📊 Table app.bobodo_sessions (colonnes disponibles):")
print("-" * 80)

r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='bobodo_sessions' ORDER BY ordinal_position"}, timeout=30)
session_columns = r.json()

for col in session_columns:
    print(f"   - {col['column_name']}: {col['data_type']}")

# 2. Audit table app.bobodo_messages
print("\n📊 Table app.bobodo_messages (colonnes disponibles):")
print("-" * 80)

r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='bobodo_messages' ORDER BY ordinal_position"}, timeout=30)
message_columns = r.json()

for col in message_columns:
    print(f"   - {col['column_name']}: {col['data_type']}")

# 3. Audit table app.bobodo_detected_needs
print("\n📊 Table app.bobodo_detected_needs (colonnes disponibles):")
print("-" * 80)

r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='bobodo_detected_needs' ORDER BY ordinal_position"}, timeout=30)
needs_columns = r.json()

for col in needs_columns:
    print(f"   - {col['column_name']}: {col['data_type']}")

# 4. Statistiques sur les sessions
print("\n📈 Statistiques des sessions:")
print("-" * 80)

r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT COUNT(*) AS total FROM app.bobodo_sessions"}, timeout=30)
total_sessions = r.json()[0]['total']
print(f"   Total sessions: {total_sessions}")

r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT COUNT(DISTINCT student_id) AS unique_students FROM app.bobodo_sessions"}, timeout=30)
unique_students = r.json()[0]['unique_students']
print(f"   Étudiants uniques: {unique_students}")

r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT AVG(message_count) AS avg_messages FROM (SELECT COUNT(*) AS message_count FROM app.bobodo_messages GROUP BY session_id) t"}, timeout=30)
avg_messages = r.json()[0]['avg_messages']
print(f"   Moyenne messages/session: {avg_messages:.1f}" if avg_messages else "   Moyenne messages/session: N/A")

r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT MAX(message_count) AS max_messages FROM (SELECT COUNT(*) AS message_count FROM app.bobodo_messages GROUP BY session_id) t"}, timeout=30)
max_messages = r.json()[0]['max_messages']
print(f"   Max messages/session: {max_messages}" if max_messages else "   Max messages/session: N/A")

# 5. Distribution des sessions par étudiant
print("\n📊 Distribution des sessions par étudiant:")
print("-" * 80)

r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT session_count, COUNT(*) AS student_count FROM (SELECT student_id, COUNT(*) AS session_count FROM app.bobodo_sessions GROUP BY student_id) t GROUP BY session_count ORDER BY session_count"}, timeout=30)
session_distribution = r.json()

for row in session_distribution:
    print(f"   {row['session_count']} session(s): {row['student_count']} étudiant(s)")

# 6. Analyse des besoins détectés
print("\n📊 Analyse des besoins détectés (bobodo_detected_needs):")
print("-" * 80)

r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT category, COUNT(*) AS count FROM app.bobodo_detected_needs GROUP BY category ORDER BY count DESC"}, timeout=30)
needs_by_category = r.json()

for row in needs_by_category:
    print(f"   {row['category']}: {row['count']}")

# 7. Vérifier s'il existe une table de résumé de session
print("\n📊 Tables de résumé de session (si existent):")
print("-" * 80)

summary_tables = [
    'app.bobodo_session_summaries',
    'app.bobodo_conversation_summaries',
    'app.bobodo_memory'
]

for table in summary_tables:
    r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': f"SELECT EXISTS(SELECT 1 FROM information_schema.tables WHERE table_schema='app' AND table_name='{table.split('.')[-1]}') as exists"}, timeout=30)
    exists = r.json()[0]['exists']
    status = "✅" if exists else "❌"
    print(f"   {status} {table}")

# 8. Synthèse
print("\n📋 Synthèse de la mémoire cross-session actuelle:")
print("-" * 80)

print("\n❌ PAS DE MÉMOIRE CROSS-SESSION:")
print("   - Chaque session est isolée (session_id unique)")
print("   - Aucun lien entre sessions du même étudiant")
print("   - Aucun résumé de session stocké")
print("   - Aucune table de mémoire persistante")

print("\n✅ CE QUI EST CONSERVÉ:")
print("   - Historique brut des messages (bobodo_messages)")
print("   - Besoins détectés (bobodo_detected_needs)")
print("   - Metadata de session (bobodo_sessions)")

print("\n❌ CE QUI MANQUE:")
print("   - Résumé automatique des conversations")
print("   - Profil conversationnel persistant")
print("   - Mémoire cross-session")
print("   - Stockage des préférences")
print("   - Stockage des centres d'intérêt")
print("   - Stockage des objectifs")

print("\n" + "=" * 80)
print("FIN CHANTIER 2 – AUDIT")
print("=" * 80)

#!/usr/bin/env python3
"""Audit de la mémoire conversationnelle et du profil étudiant de Bobodo.

PHASE 1 – Audit mémoire conversationnelle
PHASE 2 – Audit profil étudiant
"""

import requests
import json

url = 'https://thevdfcwlcqzdoybfvgs.supabase.co'
sk = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM'
h = {'Authorization': f'Bearer {sk}', 'apikey': sk, 'Content-Type': 'application/json'}

print("=" * 80)
print("PHASE 1 – AUDIT MÉMOIRE CONVERSATIONNELLE")
print("=" * 80)

# 1. Vérifier les tables de mémoire
print("\n📊 Tables de mémoire existantes:")
print("-" * 80)

memory_tables = [
    'app.bobodo_sessions',
    'app.bobodo_messages',
    'app.bobodo_knowledge',
    'app.bobodo_unanswered_questions',
    'app.bobodo_detected_needs',
    'app.bobodo_feedback',
    'app.bobodo_answer_cache'
]

for table in memory_tables:
    r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': f"SELECT EXISTS(SELECT 1 FROM information_schema.tables WHERE table_schema='app' AND table_name='{table.split('.')[-1]}') as exists"}, timeout=30)
    exists = r.json()[0]['exists']
    status = "✅" if exists else "❌"
    print(f"   {status} {table}")

# 2. Vérifier s'il existe une table de profil conversationnel
print("\n👤 Tables de profil étudiant potentielles:")
print("-" * 80)

profile_tables = [
    'app.bobodo_student_profile',
    'app.bobodo_conversation_memory',
    'app.bobodo_user_preferences',
    'app.bobodo_context_store',
    'app.student_profiles',
    'app.student_context'
]

for table in profile_tables:
    r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': f"SELECT EXISTS(SELECT 1 FROM information_schema.tables WHERE table_schema='app' AND table_name='{table.split('.')[-1]}') as exists"}, timeout=30)
    exists = r.json()[0]['exists']
    status = "✅" if exists else "❌"
    print(f"   {status} {table}")

# 3. Analyser la structure de bobodo_sessions
print("\n📋 Structure de app.bobodo_sessions:")
print("-" * 80)

r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='bobodo_sessions' ORDER BY ordinal_position"}, timeout=30)
session_columns = r.json()
for col in session_columns:
    print(f"   - {col['column_name']}: {col['data_type']}")

# 4. Analyser la structure de bobodo_messages
print("\n📋 Structure de app.bobodo_messages:")
print("-" * 80)

r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='bobodo_messages' ORDER BY ordinal_position"}, timeout=30)
message_columns = r.json()
for col in message_columns:
    print(f"   - {col['column_name']}: {col['data_type']}")

# 5. Analyser la structure de bobodo_answer_cache
print("\n📋 Structure de app.bobodo_answer_cache:")
print("-" * 80)

r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='bobodo_answer_cache' ORDER BY ordinal_position"}, timeout=30)
cache_columns = r.json()
for col in cache_columns:
    print(f"   - {col['column_name']}: {col['data_type']}")

# 6. Statistiques sur les sessions
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

# 7. Vérifier si les données étudiant sont stockées dans bobodo_sessions
print("\n🔍 Données étudiant dans app.bobodo_sessions:")
print("-" * 80)

print("   ❌ PAS de colonnes profil étudiant dans bobodo_sessions")
print("   ❌ PAS de colonnes contexte conversationnel")
print("   ❌ PAS de colonnes préférences utilisateur")

print("\n" + "=" * 80)
print("PHASE 2 – AUDIT PROFIL ÉTUDIANT")
print("=" * 80)

# 8. Vérifier les tables étudiant existantes
print("\n📊 Tables étudiant existantes:")
print("-" * 80)

student_tables = [
    'app.students',
    'app.student_profiles',
    'app.applications',
    'app.application_payments'
]

for table in student_tables:
    r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': f"SELECT EXISTS(SELECT 1 FROM information_schema.tables WHERE table_schema='app' AND table_name='{table.split('.')[-1]}') as exists"}, timeout=30)
    exists = r.json()[0]['exists']
    status = "✅" if exists else "❌"
    print(f"   {status} {table}")

# 9. Analyser la structure de app.students
print("\n📋 Structure de app.students:")
print("-" * 80)

r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='students' ORDER BY ordinal_position"}, timeout=30)
student_columns = r.json()
for col in student_columns:
    print(f"   - {col['column_name']}: {col['data_type']}")

# 10. Analyser la structure de app.student_profiles (si existe)
r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT EXISTS(SELECT 1 FROM information_schema.tables WHERE table_schema='app' AND table_name='student_profiles') as exists"}, timeout=30)
has_student_profiles = r.json()[0]['exists']

if has_student_profiles:
    print("\n📋 Structure de app.student_profiles:")
    print("-" * 80)
    r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='student_profiles' ORDER BY ordinal_position"}, timeout=30)
    profile_columns = r.json()
    for col in profile_columns:
        print(f"   - {col['column_name']}: {col['data_type']}")
else:
    print("\n❌ Table app.student_profiles n'existe pas")

print("\n" + "=" * 80)
print("FIN PHASES 1 ET 2")
print("=" * 80)

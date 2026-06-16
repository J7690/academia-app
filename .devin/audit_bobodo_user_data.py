#!/usr/bin/env python3
"""Audit des données utilisateur existantes pour Bobodo.

CHANTIER 1 – Mémoire étudiante persistante
"""

import requests
import json

url = 'https://thevdfcwlcqzdoybfvgs.supabase.co'
sk = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM'
h = {'Authorization': f'Bearer {sk}', 'apikey': sk, 'Content-Type': 'application/json'}

print("=" * 80)
print("CHANTIER 1 – AUDIT DONNÉES UTILISATEUR EXISTANTES")
print("=" * 80)

# 1. Audit table app.students
print("\n📊 Table app.students (colonnes disponibles):")
print("-" * 80)

r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='students' ORDER BY ordinal_position"}, timeout=30)
student_columns = r.json()

for col in student_columns:
    print(f"   - {col['column_name']}: {col['data_type']}")

# 2. Audit table app.applications
print("\n📊 Table app.applications (colonnes disponibles):")
print("-" * 80)

r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='applications' ORDER BY ordinal_position"}, timeout=30)
application_columns = r.json()

for col in application_columns:
    print(f"   - {col['column_name']}: {col['data_type']}")

# 3. Audit table prep_student_profiles (si existe)
print("\n📊 Table prep_student_profiles (si existe):")
print("-" * 80)

r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT EXISTS(SELECT 1 FROM information_schema.tables WHERE table_schema='app' AND table_name='prep_student_profiles') as exists"}, timeout=30)
has_prep_profiles = r.json()[0]['exists']

if has_prep_profiles:
    r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='prep_student_profiles' ORDER BY ordinal_position"}, timeout=30)
    prep_columns = r.json()
    for col in prep_columns:
        print(f"   - {col['column_name']}: {col['data_type']}")
else:
    print("   ❌ Table n'existe pas")

# 4. Audit table student_views (si existe)
print("\n📊 Table student_views (si existe):")
print("-" * 80)

r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT EXISTS(SELECT 1 FROM information_schema.tables WHERE table_schema='app' AND table_name='student_views') as exists"}, timeout=30)
has_student_views = r.json()[0]['exists']

if has_student_views:
    r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='student_views' ORDER BY ordinal_position"}, timeout=30)
    views_columns = r.json()
    for col in views_columns:
        print(f"   - {col['column_name']}: {col['data_type']}")
else:
    print("   ❌ Table n'existe pas")

# 5. Audit table student_activity_logs (si existe)
print("\n📊 Table student_activity_logs (si existe):")
print("-" * 80)

r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT EXISTS(SELECT 1 FROM information_schema.tables WHERE table_schema='app' AND table_name='student_activity_logs') as exists"}, timeout=30)
has_activity_logs = r.json()[0]['exists']

if has_activity_logs:
    r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='student_activity_logs' ORDER BY ordinal_position"}, timeout=30)
    activity_columns = r.json()
    for col in activity_columns:
        print(f"   - {col['column_name']}: {col['data_type']}")
else:
    print("   ❌ Table n'existe pas")

# 6. Synthèse des données disponibles pour Bobodo
print("\n📋 Synthèse des données disponibles pour Bobodo:")
print("-" * 80)

print("\n✅ DISPONIBLES (app.students):")
print("   - Prénom: full_name (extraction premier mot)")
print("   - Nom complet: full_name")
print("   - Série du bac: bac_series")
print("   - Année du bac: bac_year")
print("   - Mention du bac: bac_mention")
print("   - Institution du bac: bac_institution")
print("   - Pays du bac: bac_country")
print("   - Année BEPC: bepc_year")
print("   - Institution BEPC: bepc_institution")
print("   - Mention BEPC: bepc_mention")
print("   - Pays BEPC: bepc_country")
print("   - Projet d'étude: study_project_text")
print("   - Pays: country")
print("   - Ville: city")
print("   - Bio: bio")

print("\n✅ DISPONIBLES (app.applications):")
print("   - Candidatures: university_id, program_id")
print("   - Statut candidature: status")
print("   - Date candidature: created_at")

print("\n❌ NON DISPONIBLES:")
print("   - Moyenne générale")
print("   - Universités consultées (pas de tracking)")
print("   - Programmes consultés (pas de tracking)")
print("   - Activités réalisées sur Academia (pas de tracking)")
print("   - Centres d'intérêt (pas de stockage)")
print("   - Préférences exprimées (pas de stockage)")
print("   - Objectifs professionnels (seulement study_project_text)")

print("\n" + "=" * 80)
print("FIN CHANTIER 1 – AUDIT")
print("=" * 80)

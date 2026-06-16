#!/usr/bin/env python3
"""Déploiement PHASE 1 - Injection profil étudiant dans prompt Bobodo."""

import requests
import json

url = 'https://thevdfcwlcqzdoybfvgs.supabase.co'
sk = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM'
h = {'Authorization': f'Bearer {sk}', 'apikey': sk, 'Content-Type': 'application/json'}

print("=" * 80)
print("DÉPLOIEMENT PHASE 1 – INJECTION PROFIL ÉTUDIANT")
print("=" * 80)

# Lire le fichier SQL
with open('sql_changes/change_20260608_bobodo_student_profile_rpc.sql', 'r', encoding='utf-8') as f:
    sql_content = f.read()

print("\n📄 Contenu SQL à exécuter:")
print("-" * 80)
print(sql_content)

# Exécuter le SQL
print("\n🚀 Exécution du SQL sur Supabase...")
print("-" * 80)

r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': sql_content}, timeout=30)

if r.status_code == 200:
    print("✅ SQL exécuté avec succès")
else:
    print(f"❌ Erreur lors de l'exécution: {r.status_code}")
    print(r.text)
    exit(1)

# Vérifier que la RPC existe
print("\n🔍 Vérification de la RPC...")
print("-" * 80)

r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT 1 FROM pg_proc WHERE proname = 'app_get_bobodo_student_profile'"}, timeout=30)

if r.status_code == 200 and r.json():
    print("✅ RPC app_get_bobodo_student_profile créée avec succès")
else:
    print("❌ RPC non trouvée")
    exit(1)

# Tester la RPC avec une session existante
print("\n🧪 Test de la RPC...")
print("-" * 80)

r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT id FROM app.bobodo_sessions LIMIT 1"}, timeout=30)

if r.status_code == 200 and r.json():
    session_id = r.json()[0]['id']
    print(f"Session ID pour test: {session_id}")
    
    r = requests.post(f'{url}/rest/v1/rpc/app_get_bobodo_student_profile', headers=h, json={'p_session_id': session_id}, timeout=30)
    
    if r.status_code == 200:
        profile = r.json()
        print("✅ RPC testée avec succès")
        print(f"Profil retourné: {json.dumps(profile, indent=2, ensure_ascii=False)}")
    else:
        print(f"❌ Erreur lors du test RPC: {r.status_code}")
        print(r.text)
else:
    print("⚠️  Aucune session existante pour tester")

print("\n" + "=" * 80)
print("DÉPLOIEMENT PHASE 1 – TERMINÉ")
print("=" * 80)

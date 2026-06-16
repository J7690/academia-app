#!/usr/bin/env python3
"""Test de la RPC Bobodo via l'API REST."""

import requests
import json

url = 'https://thevdfcwlcqzdoybfvgs.supabase.co'
sk = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM'
h = {'Authorization': f'Bearer {sk}', 'apikey': sk, 'Content-Type': 'application/json'}

print("=" * 80)
print("TEST RPC BOBODO VIA API REST")
print("=" * 80)

# Récupérer une session ID
print("\n🔍 Récupération d'une session ID...")
print("-" * 80)

r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT id FROM app.bobodo_sessions LIMIT 1"}, timeout=30)

if r.status_code == 200 and r.json():
    session_id = r.json()[0]['id']
    print(f"Session ID: {session_id}")
    
    # Essayer d'appeler la RPC via l'API REST
    print("\n🧪 Test via API REST (app_get_bobodo_student_profile)...")
    print("-" * 80)
    
    r = requests.post(f'{url}/rest/v1/rpc/app_get_bobodo_student_profile', headers=h, json={'p_session_id': session_id}, timeout=30)
    
    if r.status_code == 200:
        profile = r.json()
        print("✅ RPC fonctionne via API REST")
        print(f"Profil: {json.dumps(profile, indent=2, ensure_ascii=False)}")
    else:
        print(f"❌ Erreur: {r.status_code}")
        print(r.text)
        
        # Essayer avec get_bobodo_student_profile
        print("\n🧪 Test via API REST (get_bobodo_student_profile)...")
        print("-" * 80)
        
        r = requests.post(f'{url}/rest/v1/rpc/get_bobodo_student_profile', headers=h, json={'p_session_id': session_id}, timeout=30)
        
        if r.status_code == 200:
            profile = r.json()
            print("✅ RPC fonctionne via API REST")
            print(f"Profil: {json.dumps(profile, indent=2, ensure_ascii=False)}")
        else:
            print(f"❌ Erreur: {r.status_code}")
            print(r.text)
else:
    print("⚠️  Aucune session pour tester")

print("\n" + "=" * 80)
print("TEST TERMINÉ")
print("=" * 80)

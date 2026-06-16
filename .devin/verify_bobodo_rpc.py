#!/usr/bin/env python3
"""Vérification de la RPC Bobodo dans la base de données."""

import requests
import json

url = 'https://thevdfcwlcqzdoybfvgs.supabase.co'
sk = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM'
h = {'Authorization': f'Bearer {sk}', 'apikey': sk, 'Content-Type': 'application/json'}

print("=" * 80)
print("VÉRIFICATION RPC BOBODO")
print("=" * 80)

# Vérifier si la RPC existe dans pg_proc
print("\n🔍 Vérification dans pg_proc...")
print("-" * 80)

r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT p.proname, n.nspname, p.proargtypes FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE p.proname LIKE '%bobodo_student_profile%'"}, timeout=30)

if r.status_code == 200:
    results = r.json()
    if results:
        print(f"✅ RPCs trouvées: {len(results)}")
        for row in results:
            print(f"  - {row['nspname']}.{row['proname']} (args: {row['proargtypes']})")
    else:
        print("❌ Aucune RPC trouvée")
else:
    print("❌ Erreur lors de la vérification")
    print(r.text)

# Vérifier les permissions
print("\n🔍 Vérification des permissions...")
print("-" * 80)

r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT grantee, privilege_type FROM information_schema.role_routines WHERE routine_name = 'get_bobodo_student_profile' AND routine_schema = 'app'"}, timeout=30)

if r.status_code == 200:
    results = r.json()
    if results:
        print(f"✅ Permissions trouvées: {len(results)}")
        for row in results:
            print(f"  - {row['grantee']}: {row['privilege_type']}")
    else:
        print("⚠️  Aucune permission trouvée")
else:
    print("⚠️  Erreur lors de la vérification des permissions")

# Tester l'appel direct via SQL
print("\n🧪 Test via SQL direct...")
print("-" * 80)

r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT id FROM app.bobodo_sessions LIMIT 1"}, timeout=30)

if r.status_code == 200 and r.json():
    session_id = r.json()[0]['id']
    print(f"Session ID: {session_id}")
    
    r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': f"SELECT app.get_bobodo_student_profile('{session_id}') as profile"}, timeout=30)
    
    if r.status_code == 200:
        results = r.json()
        if results:
            print("✅ RPC fonctionne via SQL direct")
            print(f"Profil: {json.dumps(results[0], indent=2, ensure_ascii=False)}")
        else:
            print("❌ RPC retourne vide")
    else:
        print(f"❌ Erreur: {r.status_code}")
        print(r.text)
else:
    print("⚠️  Aucune session pour tester")

print("\n" + "=" * 80)
print("VÉRIFICATION TERMINÉE")
print("=" * 80)

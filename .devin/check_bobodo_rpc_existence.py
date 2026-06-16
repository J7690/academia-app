#!/usr/bin/env python3
"""Vérification détaillée de l'existence de la RPC Bobodo."""

import requests
import json

url = 'https://thevdfcwlcqzdoybfvgs.supabase.co'
sk = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM'
h = {'Authorization': f'Bearer {sk}', 'apikey': sk, 'Content-Type': 'application/json'}

print("=" * 80)
print("VÉRIFICATION DÉTAILLÉE RPC BOBODO")
print("=" * 80)

# Vérifier dans tous les schémas
print("\n🔍 Recherche dans tous les schémas...")
print("-" * 80)

r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT p.proname, n.nspname FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE p.proname LIKE '%bobodo_student_profile%'"}, timeout=30)

if r.status_code == 200:
    results = r.json()
    if results:
        print(f"✅ {len(results)} fonction(s) trouvée(s):")
        for row in results:
            print(f"  - {row['nspname']}.{row['proname']}")
    else:
        print("❌ Aucune fonction trouvée")
else:
    print("❌ Erreur")
    print(r.text)

# Vérifier spécifiquement dans app
print("\n🔍 Recherche spécifique dans app...")
print("-" * 80)

r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT * FROM pg_proc WHERE proname = 'app_get_bobodo_student_profile'"}, timeout=30)

if r.status_code == 200:
    results = r.json()
    if results:
        print(f"✅ Fonction trouvée dans pg_proc")
        print(f"   OID: {results[0]['oid']}")
        print(f"   Schema OID: {results[0]['pronamespace']}")
    else:
        print("❌ Fonction non trouvée dans pg_proc")
else:
    print("❌ Erreur")
    print(r.text)

# Vérifier le schéma OID
print("\n🔍 Vérification du schéma app...")
print("-" * 80)

r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT oid, nspname FROM pg_namespace WHERE nspname = 'app'"}, timeout=30)

if r.status_code == 200:
    results = r.json()
    if results:
        print(f"✅ Schéma app trouvé, OID: {results[0]['oid']}")
    else:
        print("❌ Schéma app non trouvé")
else:
    print("❌ Erreur")
    print(r.text)

print("\n" + "=" * 80)
print("VÉRIFICATION TERMINÉE")
print("=" * 80)

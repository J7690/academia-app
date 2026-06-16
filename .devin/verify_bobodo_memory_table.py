#!/usr/bin/env python3
"""Vérification de la table bobodo_memory."""

import requests
import json

url = 'https://thevdfcwlcqzdoybfvgs.supabase.co'
sk = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM'
h = {'Authorization': f'Bearer {sk}', 'apikey': sk, 'Content-Type': 'application/json'}

print("=" * 80)
print("VÉRIFICATION TABLE BOBODO_MEMORY")
print("=" * 80)

# Essayer de sélectionner des données
print("\n🔍 Test SELECT sur la table...")
print("-" * 80)

r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT COUNT(*) FROM app.bobodo_memory"}, timeout=30)

if r.status_code == 200:
    result = r.json()
    print(f"✅ Table existe ! Count: {result}")
else:
    print(f"❌ Erreur SELECT: {r.status_code}")
    print(r.text)

# Vérifier dans pg_class
print("\n🔍 Vérification dans pg_class...")
print("-" * 80)

r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT relname FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE n.nspname = 'app' AND c.relname LIKE '%bobodo_memory%'"}, timeout=30)

if r.status_code == 200:
    results = r.json()
    if results:
        print(f"✅ {len(results)} table(s) trouvée(s) dans pg_class:")
        for row in results:
            print(f"  - {row['relname']}")
    else:
        print("❌ Aucune table trouvée dans pg_class")
else:
    print("❌ Erreur")
    print(r.text)

print("\n" + "=" * 80)
print("VÉRIFICATION TERMINÉE")
print("=" * 80)

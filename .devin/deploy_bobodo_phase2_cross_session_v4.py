#!/usr/bin/env python3
"""Déploiement PHASE 2 - Mémoire cross-session Bobodo."""

import requests
import json

url = 'https://thevdfcwlcqzdoybfvgs.supabase.co'
sk = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM'
h = {'Authorization': f'Bearer {sk}', 'apikey': sk, 'Content-Type': 'application/json'}

print("=" * 80)
print("DÉPLOIEMENT PHASE 2 – MÉMOIRE CROSS-SESSION")
print("=" * 80)

# Vérification finale avec information_schema
print("\n🔍 Vérification finale avec information_schema...")
print("-" * 80)

r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT table_name FROM information_schema.tables WHERE table_schema = 'app' AND table_name = 'bobodo_conversation_memory'"}, timeout=30)

if r.status_code == 200 and r.json():
    print("✅ Table bobodo_conversation_memory vérifiée")
else:
    print("❌ Table non trouvée dans information_schema")
    # Lister toutes les tables bobodo
    r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT table_name FROM information_schema.tables WHERE table_schema = 'app' AND table_name LIKE '%bobodo%' ORDER BY table_name"}, timeout=30)
    if r.status_code == 200:
        results = r.json()
        print(f"Tables bobodo trouvées: {len(results)}")
        for row in results:
            print(f"  - {row['table_name']}")
    exit(1)

# Vérifier les RPCs
print("\n🔍 Vérification des RPCs...")
print("-" * 80)

r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT proname FROM pg_proc WHERE proname LIKE '%bobodo_conversation_memory%' AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'app')"}, timeout=30)

if r.status_code == 200:
    results = r.json()
    if results:
        print(f"✅ {len(results)} RPC(s) trouvée(s):")
        for row in results:
            print(f"  - {row['proname']}")
    else:
        print("❌ Aucune RPC trouvée")
        exit(1)
else:
    print("❌ Erreur lors de la vérification")
    print(r.text)

print("\n" + "=" * 80)
print("DÉPLOIEMENT PHASE 2 – TERMINÉ")
print("=" * 80)

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

# Lire le fichier SQL
with open('sql_changes/change_20260608_bobodo_cross_session_memory.sql', 'r', encoding='utf-8') as f:
    sql_content = f.read()

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

# Vérifier que la table existe
print("\n🔍 Vérification de la table...")
print("-" * 80)

r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT 1 FROM information_schema.tables WHERE table_schema = 'app' AND table_name = 'bobodo_conversation_memory'"}, timeout=30)

if r.status_code == 200 and r.json():
    print("✅ Table bobodo_conversation_memory créée avec succès")
else:
    print("❌ Table non trouvée")
    exit(1)

# Vérifier que les RPCs existent
print("\n🔍 Vérification des RPCs...")
print("-" * 80)

r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT proname FROM pg_proc WHERE proname IN ('save_bobodo_conversation_memory', 'get_bobodo_cross_session_memory') AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'app')"}, timeout=30)

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

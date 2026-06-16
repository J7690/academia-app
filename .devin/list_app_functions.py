#!/usr/bin/env python3
"""Lister toutes les fonctions du schéma app."""

import requests
import json

url = 'https://thevdfcwlcqzdoybfvgs.supabase.co'
sk = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM'
h = {'Authorization': f'Bearer {sk}', 'apikey': sk, 'Content-Type': 'application/json'}

print("=" * 80)
print("LISTE DES FONCTIONS DU SCHÉMA APP")
print("=" * 80)

r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': "SELECT p.proname, n.nspname FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = 'app' ORDER BY p.proname"}, timeout=30)

if r.status_code == 200:
    results = r.json()
    print(f"\n✅ {len(results)} fonctions trouvées dans le schéma app:")
    print("-" * 80)
    for row in results:
        print(f"  - {row['proname']}")
else:
    print("❌ Erreur lors de la récupération")
    print(r.text)

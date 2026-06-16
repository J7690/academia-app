#!/usr/bin/env python3
"""Audit détaillé de la couverture de la base Bobodo.

DOMAINE 1.1 – Couverture réelle de la base Bobodo
- Nombre réel de fiches
- Catégories
- Taille moyenne des contenus
- Dates de création/mise à jour
- Détail par fiche (id, catégorie, titre, taille, statut)
"""

import requests
import json
from datetime import datetime
from collections import defaultdict

url = 'https://thevdfcwlcqzdoybfvgs.supabase.co'
sk = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM'
h = {'Authorization': f'Bearer {sk}', 'apikey': sk, 'Content-Type': 'application/json'}

print("=" * 80)
print("DOMAINE 1.1 – AUDIT COUVERTURE RÉELLE BASE BOBODO")
print("=" * 80)

# 1. Nombre total de fiches
r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': 'SELECT COUNT(*) AS total FROM app.bobodo_knowledge'}, timeout=30)
total = r.json()[0]['total']
print(f"\n📊 Nombre total de fiches: {total}")

# 2. Nombre de fiches actives
r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': 'SELECT COUNT(*) AS active FROM app.bobodo_knowledge WHERE is_active = TRUE'}, timeout=30)
active = r.json()[0]['active']
print(f"✅ Fiches actives: {active}")
print(f"❌ Fiches inactives: {total - active}")

# 3. Répartition par catégorie
r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': 'SELECT category, COUNT(*) AS count FROM app.bobodo_knowledge GROUP BY category ORDER BY count DESC'}, timeout=30)
categories = r.json()
print(f"\n📁 Répartition par catégorie:")
for cat in categories:
    print(f"   - {cat['category']}: {cat['count']} fiches")

# 4. Taille moyenne des contenus
r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': 'SELECT AVG(LENGTH(content)) AS avg_length, MIN(LENGTH(content)) AS min_length, MAX(LENGTH(content)) AS max_length FROM app.bobodo_knowledge WHERE is_active = TRUE'}, timeout=30)
sizes = r.json()[0]
print(f"\n📏 Taille des contenus (fiches actives):")
print(f"   - Moyenne: {int(sizes['avg_length'])} caractères")
print(f"   - Minimum: {int(sizes['min_length'])} caractères")
print(f"   - Maximum: {int(sizes['max_length'])} caractères")

# 5. Dates de création et mise à jour
r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': 'SELECT MIN(created_at) AS oldest, MAX(created_at) AS newest, MIN(updated_at) AS oldest_update, MAX(updated_at) AS newest_update FROM app.bobodo_knowledge WHERE is_active = TRUE'}, timeout=30)
dates = r.json()[0]
print(f"\n📅 Période de création:")
print(f"   - Plus ancienne: {dates['oldest']}")
print(f"   - Plus récente: {dates['newest']}")
print(f"\n📅 Période de mise à jour:")
print(f"   - Plus ancienne: {dates['oldest_update']}")
print(f"   - Plus récente: {dates['newest_update']}")

# 6. Détail par fiche
r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': 'SELECT id, category, title, LENGTH(content) AS content_length, is_active, created_at, updated_at FROM app.bobodo_knowledge ORDER BY category, title'}, timeout=30)
fiches = r.json()

print(f"\n📋 Détail par fiche ({len(fiches)} fiches):")
print(f"{'ID':<8} {'Catégorie':<12} {'Statut':<6} {'Taille':<8} {'Titre'}")
print("-" * 100)

for f in fiches:
    id_short = str(f['id'])[:8]
    category = f['category']
    status = "✅" if f['is_active'] else "❌"
    length = f['content_length']
    title = f['title'][:50] + "..." if len(f['title']) > 50 else f['title']
    print(f"{id_short:<8} {category:<12} {status:<6} {length:<8} {title}")

# 7. Statistiques par catégorie
print(f"\n📊 Statistiques détaillées par catégorie:")
r = requests.post(f'{url}/rest/v1/rpc/execute_sql', headers=h, json={'sql_query': 'SELECT category, COUNT(*) AS count, AVG(LENGTH(content)) AS avg_length, MIN(LENGTH(content)) AS min_length, MAX(LENGTH(content)) AS max_length FROM app.bobodo_knowledge WHERE is_active = TRUE GROUP BY category ORDER BY category'}, timeout=30)
cat_stats = r.json()

for stat in cat_stats:
    print(f"\n   {stat['category'].upper()}:")
    print(f"      - Nombre de fiches: {stat['count']}")
    print(f"      - Taille moyenne: {int(stat['avg_length'])} caractères")
    print(f"      - Taille min: {int(stat['min_length'])} caractères")
    print(f"      - Taille max: {int(stat['max_length'])} caractères")

print("\n" + "=" * 80)
print("FIN DU DOMAINE 1.1")
print("=" * 80)

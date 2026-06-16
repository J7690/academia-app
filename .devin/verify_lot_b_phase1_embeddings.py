#!/usr/bin/env python3
"""Vérification embeddings LOT B Phase 1"""

import json
import requests
from supabase_auto_manager import SupabaseAutoManager

manager = SupabaseAutoManager()

print("=" * 80)
print("VÉRIFICATION EMBEDDINGS LOT B PHASE 1")
print("=" * 80)

url = f"{manager.url}/rest/v1/rpc/admin_execute_sql"

# Vérifier les embeddings des 5 nouvelles fiches
print("\n--- Vérification des embeddings ---")
new_fiches = [
    "Comment créer un compte sur Academia ?",
    "Comment modifier mon profil ?",
    "Mon paiement est en attente",
    "Ma candidature est bloquée",
    "Comment accéder aux cours d''appui ?"
]

sql_embeddings = f"""
    SELECT id, title, 
           CASE WHEN embedding IS NOT NULL THEN 'OK' ELSE 'MISSING' END as embedding_status
    FROM app.bobodo_knowledge
    WHERE title IN ('{"','".join(new_fiches)}')
    ORDER BY created_at DESC;
"""

response = requests.post(url, headers=manager.headers, json={"p_sql": sql_embeddings}, timeout=30)

if response.status_code == 200:
    data = response.json()
    if isinstance(data, dict):
        if "rows" in data and len(data["rows"]) > 0:
            print(f"✅ {len(data['rows'])} fiches trouvées")
            for fiche in data["rows"]:
                print(f"\n   {fiche['title']}")
                print(f"   ID : {fiche['id']}")
                print(f"   Embedding : {fiche['embedding_status']}")
        elif "data" in data and len(data["data"]) > 0:
            print(f"✅ {len(data['data'])} fiches trouvées")
            for fiche in data["data"]:
                print(f"\n   {fiche['title']}")
                print(f"   ID : {fiche['id']}")
                print(f"   Embedding : {fiche['embedding_status']}")
        else:
            print(f"❌ Aucune fiche trouvée (réponse : {data})")
    else:
        print(f"❌ Réponse inattendue : {data}")
else:
    print(f"❌ Erreur HTTP {response.status_code} : {response.text}")

# Compter les fiches sans embeddings
print("\n--- Comptage des fiches sans embeddings ---")
sql_missing = """
    SELECT COUNT(*) as count
    FROM app.bobodo_knowledge
    WHERE embedding IS NULL;
"""

response = requests.post(url, headers=manager.headers, json={"p_sql": sql_missing}, timeout=30)

if response.status_code == 200:
    data = response.json()
    if isinstance(data, dict):
        if "rows" in data and len(data["rows"]) > 0:
            count = data["rows"][0]["count"]
            print(f"Fiches sans embeddings : {count}")
        elif "data" in data and len(data["data"]) > 0:
            count = data["data"][0]["count"]
            print(f"Fiches sans embeddings : {count}")
        else:
            print(f"❌ Réponse inattendue : {data}")
else:
    print(f"❌ Erreur HTTP {response.status_code} : {response.text}")

print("\n" + "=" * 80)
print("VÉRIFICATION TERMINÉE")
print("=" * 80)

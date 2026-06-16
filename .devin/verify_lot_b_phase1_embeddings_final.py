#!/usr/bin/env python3
"""Vérification embeddings LOT B Phase 1 via API REST (schema app)"""

import requests
from supabase_auto_manager import SupabaseAutoManager

manager = SupabaseAutoManager()

print("=" * 80)
print("VÉRIFICATION EMBEDDINGS LOT B PHASE 1 - VIA API REST (SCHEMA APP)")
print("=" * 80)

headers = manager.headers.copy()
headers["Accept-Profile"] = "app"

# Vérifier les embeddings des 5 nouvelles fiches
print("\n--- Vérification des embeddings ---")
new_fiches = [
    "Comment créer un compte sur Academia ?",
    "Comment modifier mon profil ?",
    "Mon paiement est en attente",
    "Ma candidature est bloquée",
    "Comment accéder aux cours d''appui ?"
]

# Récupérer les 5 fiches avec leurs embeddings
titles_filter = ",".join([f'"{t}"' for t in new_fiches])
url_select = f"{manager.url}/rest/v1/bobodo_knowledge?select=id,title,embedding&title=in.({titles_filter})&order=created_at.desc"
response = requests.get(url_select, headers=headers, timeout=30)

if response.status_code == 200:
    data = response.json()
    if isinstance(data, list) and len(data) > 0:
        print(f"✅ {len(data)} fiches trouvées")
        for fiche in data:
            embedding_status = "OK" if fiche.get("embedding") is not None else "MISSING"
            print(f"\n   {fiche['title']}")
            print(f"   ID : {fiche['id']}")
            print(f"   Embedding : {embedding_status}")
    else:
        print(f"❌ Aucune fiche trouvée (réponse : {data})")
else:
    print(f"❌ Erreur HTTP {response.status_code} : {response.text}")

# Compter les fiches sans embeddings
print("\n--- Comptage des fiches sans embeddings ---")
url_missing = f"{manager.url}/rest/v1/bobodo_knowledge?select=count&embedding=is.null"
response = requests.get(url_missing, headers=headers, timeout=30)

if response.status_code == 200:
    data = response.json()
    if isinstance(data, list) and len(data) > 0:
        count = data[0].get("count", 0)
        print(f"Fiches sans embeddings : {count}")
    else:
        print(f"❌ Réponse inattendue : {data}")
else:
    print(f"❌ Erreur HTTP {response.status_code} : {response.text}")

print("\n" + "=" * 80)
print("VÉRIFICATION TERMINÉE")
print("=" * 80)

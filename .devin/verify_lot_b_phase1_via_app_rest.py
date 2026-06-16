#!/usr/bin/env python3
"""Vérification injection LOT B Phase 1 via API REST sur schema app"""

import requests
from supabase_auto_manager import SupabaseAutoManager

manager = SupabaseAutoManager()

print("=" * 80)
print("VÉRIFICATION INJECTION LOT B PHASE 1 - VIA API REST (SCHEMA APP)")
print("=" * 80)

# Compter les fiches via API REST sur schema app
print("\n--- Comptage des fiches ---")
url_count = f"{manager.url}/rest/v1/bobodo_knowledge?select=count"
headers = manager.headers.copy()
headers["Accept-Profile"] = "app"

response = requests.get(url_count, headers=headers, timeout=30)

if response.status_code == 200:
    data = response.json()
    if isinstance(data, list) and len(data) > 0:
        count = data[0].get("count", 0)
        print(f"Nombre total de fiches : {count}")
    else:
        print(f"❌ Réponse inattendue : {data}")
else:
    print(f"❌ Erreur HTTP {response.status_code} : {response.text}")

# Vérifier les 5 nouvelles fiches via API REST sur schema app
print("\n--- Vérification des 5 nouvelles fiches ---")
new_fiches = [
    "Comment créer un compte sur Academia ?",
    "Comment modifier mon profil ?",
    "Mon paiement est en attente",
    "Ma candidature est bloquée",
    "Comment accéder aux cours d''appui ?"
]

# Utiliser filtre IN
titles_filter = ",".join([f'"{t}"' for t in new_fiches])
url_select = f"{manager.url}/rest/v1/bobodo_knowledge?select=id,title,category,tags,is_active,created_at&title=in.({titles_filter})&order=created_at.desc"
response = requests.get(url_select, headers=headers, timeout=30)

if response.status_code == 200:
    data = response.json()
    if isinstance(data, list) and len(data) > 0:
        print(f"✅ {len(data)} fiches trouvées")
        for fiche in data:
            print(f"\n   {fiche['title']}")
            print(f"   ID : {fiche['id']}")
            print(f"   Catégorie : {fiche['category']}")
            print(f"   Tags : {fiche['tags']}")
            print(f"   Actif : {fiche['is_active']}")
            print(f"   Créé le : {fiche['created_at']}")
    else:
        print(f"❌ Aucune fiche trouvée (réponse : {data})")
else:
    print(f"❌ Erreur HTTP {response.status_code} : {response.text}")

print("\n" + "=" * 80)
print("VÉRIFICATION TERMINÉE")
print("=" * 80)

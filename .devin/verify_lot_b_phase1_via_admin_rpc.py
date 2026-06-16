#!/usr/bin/env python3
"""Vérification injection LOT B Phase 1 via RPC admin_execute_sql (requests)"""

import json
import requests
from supabase_auto_manager import SupabaseAutoManager

manager = SupabaseAutoManager()

print("=" * 80)
print("VÉRIFICATION INJECTION LOT B PHASE 1 - VIA RPC (REQUESTS)")
print("=" * 80)

url = f"{manager.url}/rest/v1/rpc/admin_execute_sql"

# Compter les fiches
print("\n--- Comptage des fiches ---")
sql_count = "SELECT COUNT(*) as count FROM app.bobodo_knowledge"
response = requests.post(url, headers=manager.headers, json={"p_sql": sql_count}, timeout=30)

if response.status_code == 200:
    data = response.json()
    if isinstance(data, dict):
        if "rows" in data and len(data["rows"]) > 0:
            count = data["rows"][0]["count"]
            print(f"Nombre total de fiches : {count}")
        elif "data" in data and len(data["data"]) > 0:
            count = data["data"][0]["count"]
            print(f"Nombre total de fiches : {count}")
        else:
            print(f"❌ Réponse inattendue : {data}")
    else:
        print(f"❌ Réponse inattendue : {data}")
else:
    print(f"❌ Erreur HTTP {response.status_code} : {response.text}")

# Vérifier les 5 nouvelles fiches
print("\n--- Vérification des 5 nouvelles fiches ---")
new_fiches = [
    "Comment créer un compte sur Academia ?",
    "Comment modifier mon profil ?",
    "Mon paiement est en attente",
    "Ma candidature est bloquée",
    "Comment accéder aux cours d''appui ?"
]

for fiche_title in new_fiches:
    sql = f"""
        SELECT id, title, category, tags, is_active, created_at
        FROM app.bobodo_knowledge
        WHERE title = '{fiche_title}';
    """
    
    response = requests.post(url, headers=manager.headers, json={"p_sql": sql}, timeout=30)
    
    if response.status_code == 200:
        data = response.json()
        if isinstance(data, dict):
            if "rows" in data and len(data["rows"]) > 0:
                fiche = data["rows"][0]
                print(f"✅ {fiche_title}")
                print(f"   ID : {fiche['id']}")
                print(f"   Catégorie : {fiche['category']}")
                print(f"   Tags : {fiche['tags']}")
                print(f"   Actif : {fiche['is_active']}")
                print(f"   Créé le : {fiche['created_at']}")
            elif "data" in data and len(data["data"]) > 0:
                fiche = data["data"][0]
                print(f"✅ {fiche_title}")
                print(f"   ID : {fiche['id']}")
                print(f"   Catégorie : {fiche['category']}")
                print(f"   Tags : {fiche['tags']}")
                print(f"   Actif : {fiche['is_active']}")
                print(f"   Créé le : {fiche['created_at']}")
            else:
                print(f"❌ {fiche_title} - NON TROUVÉE (réponse : {data})")
        else:
            print(f"❌ {fiche_title} - NON TROUVÉE (réponse : {data})")
    else:
        print(f"❌ {fiche_title} - ERREUR HTTP {response.status_code}")

print("\n" + "=" * 80)
print("VÉRIFICATION TERMINÉE")
print("=" * 80)

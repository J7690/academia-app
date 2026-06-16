#!/usr/bin/env python3
"""Vérification fiche manquante"""

import requests
from supabase_auto_manager import SupabaseAutoManager

manager = SupabaseAutoManager()

print("=" * 80)
print("VÉRIFICATION FICHE MANQUANTE")
print("=" * 80)

# Vérifier la fiche avec différentes variantes
headers = manager.headers.copy()
headers["Accept-Profile"] = "app"

# Variante 1 : avec apostrophe simple
url1 = f"{manager.url}/rest/v1/bobodo_knowledge?select=id,title&title=eq.Comment accéder aux cours d''appui ?"
response = requests.get(url1, headers=headers, timeout=30)
print(f"\nVariante 1 (apostrophe double) : {response.status_code}")
if response.status_code == 200:
    data = response.json()
    print(f"  Résultat : {data}")

# Variante 2 : recherche partielle
url2 = f"{manager.url}/rest/v1/bobodo_knowledge?select=id,title&title=ilike.*cours d''appui*"
response = requests.get(url2, headers=headers, timeout=30)
print(f"\nVariante 2 (ilike) : {response.status_code}")
if response.status_code == 200:
    data = response.json()
    print(f"  Résultat : {data}")

# Variante 3 : toutes les fiches récentes
url3 = f"{manager.url}/rest/v1/bobodo_knowledge?select=id,title,created_at&order=created_at.desc&limit=10"
response = requests.get(url3, headers=headers, timeout=30)
print(f"\nVariante 3 (10 dernières fiches) : {response.status_code}")
if response.status_code == 200:
    data = response.json()
    print(f"  Résultat : {len(data)} fiches")
    for fiche in data:
        print(f"    - {fiche['title']} ({fiche['created_at']})")

print("\n" + "=" * 80)

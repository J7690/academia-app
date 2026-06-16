#!/usr/bin/env python3
"""Exécuter la génération d'embeddings via Edge Function"""

import requests
from pathlib import Path

# Charger la clé API depuis le fichier .env
root = Path(__file__).resolve().parents[1]
env_path = root / "academia_bobodo_backend" / ".env"

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_KEY = None

if env_path.exists():
    try:
        content = env_path.read_text(encoding="utf-8")
        for line in content.splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            key = key.strip()
            value = value.strip().strip('"').strip("'")
            
            if key == "SUPABASE_SERVICE_KEY":
                SERVICE_KEY = value
                break
    except Exception as e:
        print(f"Erreur lecture fichier .env: {e}")

if not SERVICE_KEY:
    print("❌ SUPABASE_SERVICE_KEY non trouvée")
    exit(1)

print("=" * 80)
print("GÉNÉRATION EMBEDDINGS BOBODO VIA EDGE FUNCTION")
print("=" * 80)

headers = {
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Content-Type": "application/json",
    "Accept": "application/json"
}

try:
    response = requests.post(
        f"{SUPABASE_URL}/functions/v1/bobodo-generate-embeddings",
        headers=headers,
        json={},
        timeout=600  # 10 minutes timeout pour traiter toutes les fiches
    )
    
    print(f"\nHTTP Status: {response.status_code}")
    
    if response.status_code == 200:
        data = response.json()
        print("\n" + "=" * 80)
        print("RÉSULTAT GÉNÉRATION EMBEDDINGS")
        print("=" * 80)
        
        print(f"\nSuccès: {data.get('success')}")
        print(f"Message: {data.get('message')}")
        print(f"Fiches traitées: {data.get('processed')}")
        print(f"Fiches mises à jour: {data.get('updated')}")
        print(f"Échecs: {data.get('failed')}")
        
        if data.get('failed', 0) > 0:
            print(f"\n⚠️ {data.get('failed')} fiches ont échoué")
        else:
            print(f"\n✅ Toutes les fiches ont été vectorisées avec succès")
    else:
        print(f"❌ Erreur HTTP {response.status_code}")
        print(f"   {response.text[:500]}")
        
except Exception as e:
    print(f"❌ Erreur: {e}")
